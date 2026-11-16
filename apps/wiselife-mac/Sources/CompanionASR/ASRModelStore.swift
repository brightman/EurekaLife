// Adapted from apps/wrist-notes/Sources/iPhone/WhisperModelStore.swift.
// Pins, checksum semantics and local tokenizer layout are shared with iPhone.
import CryptoKit
import Foundation

struct ASRModelFile: Codable, Sendable {
    let path: String
    let url: URL
    let bytes: Int64
    let sha256: String?
    let gitSHA1: String?
}

struct ASRModelStore: Sendable {
    typealias Download = @Sendable (URLRequest, @escaping @Sendable (Int64) async -> Void) async throws -> (URL, URLResponse)
    let root: URL
    let catalogURL: URL?
    private let downloadFile: Download?
    private let requiredPaths: [String]

    init(root: URL, catalogURL: URL? = Bundle.module.url(forResource: "ASRModels", withExtension: "json"),
         requiredPaths: [String] = ["tokenizer.json", "tokenizer_config.json", "AudioEncoder.mlmodelc/weights/weight.bin",
                                   "TextDecoder.mlmodelc/weights/weight.bin", "MelSpectrogram.mlmodelc/weights/weight.bin"],
         downloadFile: Download? = nil) {
        self.root = root; self.catalogURL = catalogURL
        self.requiredPaths = requiredPaths; self.downloadFile = downloadFile
    }

    func folder(for size: String) -> URL { root.appendingPathComponent(size, isDirectory: true) }

    func files(for size: String) throws -> [ASRModelFile] {
        guard ["tiny", "base", "small"].contains(size) else { throw MeetingASRError.unsupportedModel }
        guard let catalogURL else { throw MeetingASRError.invalidFiles }
        let catalog = try JSONDecoder().decode([String: [ASRModelFile]].self, from: Data(contentsOf: catalogURL))
        guard let files = catalog[size], !files.isEmpty, Set(files.map(\.path)).count == files.count,
              files.allSatisfy({ file in
                  let components = file.path.split(separator: "/", omittingEmptySubsequences: false)
                  let checksum = file.sha256 ?? file.gitSHA1 ?? ""
                  return file.bytes > 0 && !components.isEmpty && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
                      && file.url.scheme == "https" && file.url.host == "huggingface.co"
                      && checksum.count == (file.sha256 != nil ? 64 : 40)
                      && checksum.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
              }), requiredPaths.allSatisfy({ path in files.contains { $0.path == path } }) else { throw MeetingASRError.invalidFiles }
        return files
    }

    private func stamp(_ files: [ASRModelFile]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return Data(SHA256.hash(data: try encoder.encode(files)))
    }

    func installed(_ size: String) -> Bool {
        guard let files = try? files(for: size),
              let marker = try? Data(contentsOf: folder(for: size).appendingPathComponent("installed.manifest")),
              marker == (try? stamp(files)) else { return false }
        return files.allSatisfy { file in
            guard safeFile(folder(for: size).appendingPathComponent(file.path), within: folder(for: size)),
                  let info = try? folder(for: size).appendingPathComponent(file.path).resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { return false }
            return info.isRegularFile == true && Int64(info.fileSize ?? -1) == file.bytes
        }
    }

    func validate(_ size: String) throws {
        _ = try files(for: size)
        guard installed(size) else { throw MeetingASRError.missingModel }
        for file in try files(for: size) {
            try Task.checkCancellation()
            try verify(folder(for: size).appendingPathComponent(file.path), file: file)
        }
    }

    /// Must be called while holding ASROperationPermit. Never sweeps other staging
    /// directories or an existing installation; a replaced model is kept as backup.
    func download(_ size: String, progress: @escaping @Sendable (Double) async -> Void) async throws {
        try Task.checkCancellation()
        let files = try files(for: size)
        let total = files.reduce(Int64(0)) { $0 + $1.bytes }
        if (try? validate(size)) != nil { await progress(1); return }
        try Task.checkCancellation()
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let staging = root.appendingPathComponent(".assembly-\(size)-\(UUID())", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: staging) }
        var excluded = staging
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60; configuration.timeoutIntervalForResource = 3_600
        configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var completed: Int64 = 0
        await progress(0)
        for file in files {
            try Task.checkCancellation()
            let base = completed
            let report: @Sendable (Int64) async -> Void = { written in
                // 100% means verified and promoted, rather than merely downloaded.
                await progress(min(0.99, Double(base + min(max(0, written), file.bytes)) / Double(total)))
            }
            var request = URLRequest(url: file.url); request.cachePolicy = .reloadIgnoringLocalCacheData
            let (temporary, response): (URL, URLResponse)
            if let downloadFile { (temporary, response) = try await downloadFile(request, report) }
            else { (temporary, response) = try await Self.fetch(request, session: session, report: report) }
            defer { try? manager.removeItem(at: temporary) }
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw MeetingASRError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            try verify(temporary, file: file)
            let destination = staging.appendingPathComponent(file.path)
            try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.moveItem(at: temporary, to: destination)
            completed += file.bytes
            await progress(min(0.99, Double(completed) / Double(total)))
        }
        for file in files { try verify(staging.appendingPathComponent(file.path), file: file) }
        try Task.checkCancellation()
        try stamp(files).write(to: staging.appendingPathComponent("installed.manifest"), options: .atomic)
        let destination = folder(for: size)
        var backup: URL?
        if manager.fileExists(atPath: destination.path) {
            let previous = root.appendingPathComponent(".previous-\(size)-\(UUID())", isDirectory: true)
            try manager.moveItem(at: destination, to: previous)
            backup = previous
        }
        do { try manager.moveItem(at: staging, to: destination) }
        catch {
            if let backup { try? manager.moveItem(at: backup, to: destination) }
            throw error
        }
        guard installed(size) else { throw MeetingASRError.invalidFiles }
        await progress(1)
    }

    private static func fetch(_ request: URLRequest, session: URLSession,
                              report: @escaping @Sendable (Int64) async -> Void) async throws -> (URL, URLResponse) {
        let (stream, continuation) = AsyncStream<Int64>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let reporter = Task { for await value in stream { await report(value) } }
        let delegate = ASRDownloadObserver { continuation.yield($0) }
        do {
            let result = try await session.download(for: request, delegate: delegate)
            continuation.finish(); await reporter.value
            return result
        } catch {
            continuation.finish(); await reporter.value
            throw error
        }
    }

    // Checking the entire relative path also rejects a symlinked intermediate
    // model directory, not just a symlink at the final weight file.
    private func safeFile(_ url: URL, within folder: URL) -> Bool {
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let expected = base.appendingPathComponent(folder.lastPathComponent)
            .appendingPathComponent(String(url.path.dropFirst(folder.path.count + 1))).standardizedFileURL.path
        return url.standardizedFileURL.resolvingSymlinksInPath().path == expected
    }

    private func verify(_ url: URL, file: ASRModelFile) throws {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, Int64(info.fileSize ?? -1) == file.bytes else {
            throw MeetingASRError.invalidFiles
        }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var sha256 = SHA256(), sha1 = Insecure.SHA1()
        sha1.update(data: Data("blob \(file.bytes)\0".utf8))
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            if file.sha256 != nil { sha256.update(data: chunk) } else { sha1.update(data: chunk) }
        }
        let actual = file.sha256 != nil ? sha256.finalize().map { String(format: "%02x", $0) }.joined()
            : sha1.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == (file.sha256 ?? file.gitSHA1) else { throw MeetingASRError.invalidFiles }
    }
}

private final class ASRDownloadObserver: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let progress: @Sendable (Int64) -> Void
    init(progress: @escaping @Sendable (Int64) -> Void) { self.progress = progress }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) { progress(totalBytesWritten) }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, url.scheme == "https", let host = url.host?.lowercased(),
              host == "huggingface.co" || host.hasSuffix(".huggingface.co") || host.hasSuffix(".hf.co")
                || host.hasSuffix(".xethub.hf.co") else { completionHandler(nil); return }
        completionHandler(request)
    }
}

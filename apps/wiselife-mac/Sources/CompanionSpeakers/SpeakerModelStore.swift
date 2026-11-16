// Adapted from CompanionASR/ASRModelStore.swift; catalog pins and license resources
// are copied unchanged from the iPhone SpeakerModels and VoiceIdentityModels.
import CryptoKit
import Foundation

struct SpeakerModelFile: Codable, Sendable {
    let path: String
    let url: URL
    let bytes: Int64
    let sha256: String?
    let gitSHA1: String?
}

struct SpeakerModelStore: Sendable {
    typealias Download = @Sendable (URLRequest, @escaping @Sendable (Int64) async -> Void) async throws -> (URL, URLResponse)
    let root: URL
    let catalogURLs: [URL]
    private let downloadFile: Download?
    private let requiredPaths: [String]

    init(root: URL, catalogURLs: [URL]? = nil,
         requiredPaths: [String] = [
            "speaker_clusterer/pyannote-v4/W32A32/PldaProjector.mlmodelc/weights/weight.bin",
            "speaker_embedder/pyannote-v3/W8A16/SpeakerEmbedder.mlmodelc/weights/weight.bin",
            "speaker_embedder/pyannote-v3/W8A16/SpeakerEmbedderPreprocessor.mlmodelc/weights/weight.bin",
            "speaker_segmenter/pyannote-v3/W8A16/SpeakerSegmenter.mlmodelc/weights/weight.bin",
            "wespeaker_v2.mlmodelc/weights/weight.bin"], downloadFile: Download? = nil) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        self.catalogURLs = catalogURLs ?? ["SpeakerModels", "VoiceIdentityModels"].compactMap {
            Bundle.module.url(forResource: $0, withExtension: "json")
        }
        self.requiredPaths = requiredPaths; self.downloadFile = downloadFile
    }

    var folder: URL { root.appendingPathComponent("meeting-speakers-v1", isDirectory: true) }

    func files() throws -> [SpeakerModelFile] {
        guard !catalogURLs.isEmpty else { throw MeetingSpeakerError.invalidFiles }
        let files = try catalogURLs.flatMap { url in
            try JSONDecoder().decode([String: [SpeakerModelFile]].self, from: Data(contentsOf: url))
                .sorted { $0.key < $1.key }.flatMap(\.value)
        }
        guard !files.isEmpty, Set(files.map(\.path)).count == files.count,
              files.allSatisfy({ file in
                  let components = file.path.split(separator: "/", omittingEmptySubsequences: false)
                  let checksum = file.sha256 ?? file.gitSHA1 ?? ""
                  return file.bytes > 0 && !components.isEmpty && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
                      && !file.path.contains("\\") && file.path != "installed.manifest"
                      && file.url.scheme == "https" && file.url.host == "huggingface.co"
                      && file.url.user == nil && file.url.password == nil
                      && checksum.count == (file.sha256 != nil ? 64 : 40)
                      && checksum.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
              }), requiredPaths.allSatisfy({ path in files.contains { $0.path == path } }) else { throw MeetingSpeakerError.invalidFiles }
        return files
    }

    private func stamp(_ files: [SpeakerModelFile]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return Data(SHA256.hash(data: try encoder.encode(files)))
    }

    /// Hashes are checked even for the installed status: receipts alone are not evidence.
    func installed() throws -> Bool {
        _ = try files()
        do { try validate(); return true }
        catch is CancellationError { throw CancellationError() }
        catch { return false }
    }

    func validate() throws {
        let files = try files()
        let marker = folder.appendingPathComponent("installed.manifest")
        guard safeFile(marker, within: folder),
              let receipt = try? Data(contentsOf: marker), receipt == (try? stamp(files)) else {
            throw MeetingSpeakerError.missingModel
        }
        for file in files {
            try Task.checkCancellation()
            let url = folder.appendingPathComponent(file.path)
            guard safeFile(url, within: folder) else { throw MeetingSpeakerError.invalidFiles }
            try verify(url, file: file)
        }
        // Core ML model resolution must never find unverified alternative model files.
        let allowed = Set(files.map(\.path) + ["installed.manifest"])
        let canonicalFolder = folder.resolvingSymlinksInPath()
        guard let enumerator = FileManager.default.enumerator(at: canonicalFolder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            throw MeetingSpeakerError.invalidFiles
        }
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw MeetingSpeakerError.invalidFiles }
            if values.isDirectory != true {
                let relative = String(url.resolvingSymlinksInPath().path.dropFirst(canonicalFolder.path.count + 1))
                guard allowed.contains(relative) else { throw MeetingSpeakerError.invalidFiles }
            }
        }
    }

    /// Must be called while holding SpeakerOperationPermit. Never sweeps other staging
    /// directories or an existing installation; a replaced model is kept as backup.
    func download(progress: @escaping @Sendable (Double) async -> Void) async throws {
        try Task.checkCancellation()
        let files = try files()
        let total = files.reduce(Int64(0)) { $0 + $1.bytes }
        if (try? validate()) != nil { await progress(1); return }
        try Task.checkCancellation()
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let staging = root.appendingPathComponent(".assembly-\(UUID())", isDirectory: true)
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
                throw MeetingSpeakerError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
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
        let destination = folder
        var backup: URL?
        if manager.fileExists(atPath: destination.path) {
            let previous = root.appendingPathComponent(".previous-\(UUID())", isDirectory: true)
            try manager.moveItem(at: destination, to: previous)
            backup = previous
        }
        do { try manager.moveItem(at: staging, to: destination) }
        catch {
            if let backup { try? manager.moveItem(at: backup, to: destination) }
            throw error
        }
        try validate()
        await progress(1)
    }

    private static func fetch(_ request: URLRequest, session: URLSession,
                              report: @escaping @Sendable (Int64) async -> Void) async throws -> (URL, URLResponse) {
        let (stream, continuation) = AsyncStream<Int64>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let reporter = Task { for await value in stream { await report(value) } }
        let delegate = SpeakerDownloadObserver { continuation.yield($0) }
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

    private func verify(_ url: URL, file: SpeakerModelFile) throws {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, Int64(info.fileSize ?? -1) == file.bytes else {
            throw MeetingSpeakerError.invalidFiles
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
        guard actual == (file.sha256 ?? file.gitSHA1) else { throw MeetingSpeakerError.invalidFiles }
    }
}

private final class SpeakerDownloadObserver: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
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

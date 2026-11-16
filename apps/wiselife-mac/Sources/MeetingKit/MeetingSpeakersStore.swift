import Foundation
import CryptoKit

public actor MeetingSpeakerStore {
    private let root: URL
    private var unreadable: Set<UUID> = []
    public init(root: URL) { self.root = root.standardizedFileURL }

    public func load(id: UUID, recoverInterrupted: Bool = false) throws -> MeetingSpeakerDocument? {
        let url = try fileURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var value: MeetingSpeakerDocument
        do { value = try decode(Data(contentsOf: url)) }
        catch { unreadable.insert(id); throw error }
        if recoverInterrupted && value.state == .running {
            value.state = .interrupted
            value.failure = "上次说话人分析被中断，已有结果和检查点已保留。"
            try save(value, for: id)
        }
        return value
    }

    public func save(_ value: MeetingSpeakerDocument, for id: UUID) throws {
        guard !unreadable.contains(id) else { throw protectedFile() }
        let url = try fileURL(id)
        // A save without a prior load must not replace a damaged or future-version document.
        if FileManager.default.fileExists(atPath: url.path) {
            do { _ = try decode(Data(contentsOf: url)) }
            catch { unreadable.insert(id); throw protectedFile() }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        _ = try decode(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
    }

    /// Actor-isolated, bounded-memory hashing. No file IO runs on the MainActor.
    public func fingerprint(url: URL, segments: [MeetingTranscriptSegment], modelVersion: String) throws -> String {
        try Task.checkCancellation()
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey])
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        hash.update(data: Data("MeetingSpeakers/policy-1\n".utf8))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        // JSON provides an unambiguous boundary between model/transcript data and media bytes.
        struct Source: Encodable { let model: String; let segments: [MeetingTranscriptSegment] }
        let metadata = try encoder.encode(Source(model: modelVersion, segments: segments))
        hash.update(data: Data("\(metadata.count):".utf8)); hash.update(data: metadata)
        var readBytes = 0
        while true {
            try Task.checkCancellation()
            let chunk = try file.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            readBytes += chunk.count; hash.update(data: chunk)
        }
        try Task.checkCancellation()
        let after = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey])
        guard before.fileSize == after.fileSize, readBytes == after.fileSize,
              before.contentModificationDate == after.contentModificationDate,
              String(describing: before.fileResourceIdentifier) == String(describing: after.fileResourceIdentifier) else {
            throw MeetingFailure.message("录音在校验时发生变化，请重新分析。")
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func decode(_ data: Data) throws -> MeetingSpeakerDocument {
        let value = try JSONDecoder().decode(MeetingSpeakerDocument.self, from: data)
        guard value.schemaVersion == 1 else { throw protectedFile() }
        if let checkpoint = value.checkpoint {
            guard checkpoint.completedWindows >= 0, checkpoint.nextSpeaker > 0,
                  checkpoint.turns.allSatisfy({ $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start }),
                  checkpoint.features.values.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isFinite) }) else { throw protectedFile() }
        }
        return value
    }
    private func fileURL(_ id: UUID) throws -> URL {
        let directory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("speakers.json")
        let expectedDirectory = root.resolvingSymlinksInPath().appendingPathComponent(id.uuidString, isDirectory: true)
        let expectedFile = expectedDirectory.appendingPathComponent("speakers.json")
        // Compare the complete path: checking only parents lets one meeting alias another.
        guard directory.resolvingSymlinksInPath().path == expectedDirectory.path,
              url.resolvingSymlinksInPath().path == expectedFile.path else {
            throw MeetingFailure.message("说话人存储路径无效，已阻止写入。")
        }
        return url
    }
    private func protectedFile() -> MeetingFailure {
        .message("已有说话人结果无法读取，已阻止覆盖。原文件已保留。")
    }
}

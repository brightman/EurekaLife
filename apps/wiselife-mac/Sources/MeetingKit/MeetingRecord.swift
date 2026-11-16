import Foundation

public enum MeetingMode: String, Codable, Sendable, CaseIterable { case audio, screen }
public enum MeetingState: String, Codable, Sendable { case recording, finalizing, saved, interrupted, failed }
public struct MeetingOptions: Codable, Sendable, Equatable {
    public var mode: MeetingMode
    public var microphone: Bool
    public var systemAudio: Bool
    public init(mode: MeetingMode = .audio, microphone: Bool = true, systemAudio: Bool = true) {
        self.mode = mode; self.microphone = microphone; self.systemAudio = systemAudio
    }
}
public struct MeetingRecord: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var options: MeetingOptions
    public var state: MeetingState
    public var duration: Double
    public var bytes: Int64
    public var source: String
    public var failure: String?
    public init(id: UUID = UUID(), title: String, options: MeetingOptions) {
        self.id = id; self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名会议" : String(title.prefix(120))
        self.createdAt = Date(); self.options = options; self.state = .recording
        self.duration = 0; self.bytes = 0; self.source = options.mode == .audio ? "仅录音" : "屏幕与音频"
    }
}

public actor MeetingStore {
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    public func directory(for record: MeetingRecord) -> URL { root.appendingPathComponent(record.id.uuidString, isDirectory: true) }
    public func mediaURL(for record: MeetingRecord) -> URL { directory(for: record).appendingPathComponent(record.options.mode == .screen ? "recording.mp4" : "recording.m4a") }
    public func save(_ record: MeetingRecord) throws {
        let directory = directory(for: record)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: directory.appendingPathComponent("meeting.json"), options: .atomic)
    }
    public func load(recoverInterrupted: Bool = false) throws -> [MeetingRecord] {
        let directories = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        var records: [MeetingRecord] = []
        for directory in directories where UUID(uuidString: directory.lastPathComponent) != nil {
            guard let data = try? Data(contentsOf: directory.appendingPathComponent("meeting.json")),
                  var record = try? JSONDecoder().decode(MeetingRecord.self, from: data),
                  record.id.uuidString == directory.lastPathComponent else { continue }
            if recoverInterrupted && [.recording, .finalizing].contains(record.state) {
                record.state = .interrupted
                record.failure = "上次录制意外中断，已保留本地文件。可尝试恢复回放。"
                try save(record)
            }
            records.append(record)
        }
        return records.sorted { $0.createdAt > $1.createdAt }
    }
}

public enum CaptureGeometry {
    public static func dimensions(width: Double, height: Double) -> (width: Int, height: Int) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return (2, 2) }
        let scale = min(1, 1920 / max(width, height))
        return (max(2, Int(width * scale) / 2 * 2), max(2, Int(height * scale) / 2 * 2))
    }
}
public enum MeetingFailure: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

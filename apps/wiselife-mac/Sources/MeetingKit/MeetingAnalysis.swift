import Foundation

public struct MeetingTranscriptSegment: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var start: Double
    public var end: Double
    public var text: String
    public init(id: String, start: Double, end: Double, text: String) { self.id = id; self.start = start; self.end = end; self.text = text }
}
public enum MeetingAnalysisState: String, Codable, Sendable {
    case idle, queued, transcribing, summarizing, ready, waitingForModel, failed, interrupted
    public var title: String {
        switch self {
        case .idle: "尚未整理"; case .queued: "等待整理"; case .transcribing: "正在转写"; case .summarizing: "正在总结"
        case .ready: "已整理"; case .waitingForModel: "等待本地模型"; case .failed: "整理失败"; case .interrupted: "整理已中断"
        }
    }
}
public struct MeetingChatMessage: Codable, Sendable, Identifiable {
    public var id: UUID = UUID()
    public var role: String
    public var text: String
    public init(role: String, text: String) { self.role = role; self.text = text }
}
public struct MeetingAnalysis: Codable, Sendable {
    public var state: MeetingAnalysisState = .idle
    public var segments: [MeetingTranscriptSegment] = []
    public var summary: String?
    public var asrModel: String?
    public var llmModel: String?
    public var failure: String?
    public var updatedAt = Date()
    public var completedChunks: Int = 0
    public var mediaBytes: Int64 = 0
    public var messages: [MeetingChatMessage] = []
    public init() {}
    public var transcript: String { segments.map { "[\(Self.timestamp($0.start))] \($0.text)" }.joined(separator: "\n") }
    public static func timestamp(_ seconds: Double) -> String {
        let value = seconds.isFinite ? Int(min(315_576_000, max(0, seconds))) : 0
        return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
    }
}
public actor MeetingAnalysisStore {
    private let root: URL
    private var unreadable: Set<UUID> = []
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    public func load(id: UUID, recoverInterrupted: Bool = false) throws -> MeetingAnalysis? {
        let url = root.appendingPathComponent(id.uuidString).appendingPathComponent("analysis.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var value: MeetingAnalysis
        do { value = try JSONDecoder().decode(MeetingAnalysis.self, from: Data(contentsOf: url)) }
        catch { unreadable.insert(id); throw error }
        if recoverInterrupted && [.transcribing, .summarizing, .queued].contains(value.state) {
            value.state = .interrupted; value.failure = "上次整理被中断，原文和已有总结已保留。点击继续整理即可恢复。"
            try save(value, for: id)
        }
        return value
    }
    public func save(_ value: MeetingAnalysis, for id: UUID) throws {
        guard !unreadable.contains(id) else { throw MeetingFailure.message("已有整理结果无法读取，已阻止覆盖。原文件已保留。") }
        let directory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: directory.appendingPathComponent("analysis.json"), options: .atomic)
    }
}
public enum MeetingTextChunks {
    /// UTF-8 byte bounds are conservative for multilingual tokenizer inputs; no input is dropped.
    public static func split(_ text: String, maximumBytes: Int = 5000) -> [String] {
        let limit = max(16, maximumBytes)
        var result: [String] = [], part = "", bytes = 0
        for character in text {
            let next = String(character), count = next.utf8.count
            if bytes + count > limit && !part.isEmpty { result.append(part); part = ""; bytes = 0 }
            part += next; bytes += count
        }
        if !part.isEmpty { result.append(part) }
        return result
    }
}

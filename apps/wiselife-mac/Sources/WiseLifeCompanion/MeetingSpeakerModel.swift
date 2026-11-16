import Foundation
import Combine
import MeetingKit
import CompanionSpeakers

@MainActor final class MeetingSpeakerModel: ObservableObject {
    @Published var documents: [UUID: MeetingSpeakerDocument] = [:]
    @Published var fingerprints: [UUID: String] = [:]
    @Published var processingID: UUID?
    @Published var progress: Double = 0
    @Published var installed = false
    @Published var downloadProgress: Double?
    @Published var error: String?
    private var sources: [UUID: (URL, [MeetingTranscriptSegment])] = [:]
    @Published private(set) var renaming = false
    private let store: MeetingSpeakerStore?
    private let engine = MeetingSpeakerEngine()
    private var task: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var closing = false
    private var validationTokens: [UUID: UUID] = [:]
    private var renameTask: Task<Bool, Never>?
    var onIdle: (() -> Void)?
    var busy: Bool { processingID != nil || downloadProgress != nil || renaming }

    init(root: URL) { store = MeetingSpeakerStore(root: root) }
    func refreshModels() async {
        do { installed = try await engine.installed() }
        catch { installed = false; self.error = error.localizedDescription }
    }
    func load(_ record: MeetingRecord, url: URL, segments: [MeetingTranscriptSegment], recover: Bool) async {
        guard let store else { return }
        do {
            if documents[record.id] == nil || recover {
                documents[record.id] = try await store.load(id: record.id, recoverInterrupted: recover) ?? MeetingSpeakerDocument()
            }
            if documents[record.id]?.result != nil { try await validate(record.id, url: url, segments: segments) }
        } catch is CancellationError {
            // A newer validation owns this result.
        } catch { self.error = "说话人结果读取失败，原文件已保留：\(error.localizedDescription)" }
    }
    func validate(_ id: UUID, url: URL, segments: [MeetingTranscriptSegment]) async throws {
        guard let store else { throw MeetingFailure.message("说话人结果目录不可用。") }
        let token = UUID()
        validationTokens[id] = token
        fingerprints.removeValue(forKey: id)
        sources.removeValue(forKey: id)
        let fingerprint = try await store.fingerprint(url: url, segments: segments, modelVersion: MeetingSpeakerEngine.modelVersion)
        try Task.checkCancellation()
        guard validationTokens[id] == token else { throw CancellationError() }
        fingerprints[id] = fingerprint
        sources[id] = (url, segments)
    }
    func snapshot(for id: UUID) -> MeetingSpeakerSnapshot? {
        guard let fingerprint = fingerprints[id] else { return nil }
        return documents[id]?.currentResult(fingerprint: fingerprint)
    }
    func sourceChanged(_ id: UUID) -> Bool {
        guard let fingerprint = fingerprints[id], let old = documents[id]?.result else { return false }
        return fingerprint != old.fingerprint
    }
    func transcript(_ segments: [MeetingTranscriptSegment], id: UUID) -> String {
        guard let result = snapshot(for: id) else {
            return segments.map { "[\(MeetingAnalysis.timestamp($0.start))] \($0.text)" }.joined(separator: "\n")
        }
        return segments.map { segment in
            let name = result.assignments[segment.id].map { result.displayName($0) } ?? "未确定"
            return "[\(MeetingAnalysis.timestamp(segment.start))] \(name)：\(segment.text)"
        }.joined(separator: "\n")
    }
    private func save(_ document: MeetingSpeakerDocument, id: UUID) async throws {
        guard let store else { throw MeetingFailure.message("说话人结果目录不可用。") }
        try await store.save(document, for: id)
        documents[id] = document
    }
    func download() {
        guard !closing, !busy else { return }
        downloadProgress = 0; error = nil
        downloadTask = Task {
            defer { downloadProgress = nil; downloadTask = nil; onIdle?() }
            do { try await engine.download { await self.updateDownload($0) }; await refreshModels() }
            catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
    private func updateDownload(_ value: Double) { downloadProgress = value }
    func cancelDownload() { downloadTask?.cancel() }
    func start(_ record: MeetingRecord, url: URL, segments: [MeetingTranscriptSegment], force: Bool = false) {
        guard !closing, !busy, record.state == .saved, !segments.isEmpty else { return }
        processingID = record.id; progress = 0; error = nil
        task = Task {
            defer { processingID = nil; task = nil; onIdle?() }
            await perform(record, url: url, segments: segments, force: force)
        }
    }
    /// Awaited by the existing ASR→summary pipeline; it keeps ownership of cancellation.
    func analyzeDuringPipeline(_ record: MeetingRecord, url: URL, segments: [MeetingTranscriptSegment]) async {
        guard !closing, !busy else { return }
        await refreshModels()
        guard installed else { return }
        processingID = record.id; progress = 0
        defer { processingID = nil }
        await perform(record, url: url, segments: segments, force: false)
    }
    private func perform(_ record: MeetingRecord, url: URL, segments: [MeetingTranscriptSegment], force: Bool) async {
        do {
            guard !segments.isEmpty else { throw MeetingFailure.message("请先完成原文转写，再区分说话人。") }
            try await validate(record.id, url: url, segments: segments)
            guard let fingerprint = fingerprints[record.id] else { return }
            var document = documents[record.id] ?? MeetingSpeakerDocument()
            if !force, document.state == .ready, document.currentResult(fingerprint: fingerprint) != nil { progress = 1; return }
            await refreshModels()
            guard installed else {
                document.state = .waitingForModel; document.failure = "请在模型库下载说话人模型。现有原文与总结已保留。"
                try await save(document, id: record.id); return
            }
            if force || document.checkpoint?.fingerprint != fingerprint { document.checkpoint = MeetingSpeakerCheckpoint(fingerprint: fingerprint) }
            document.state = .running; document.failure = nil
            try await save(document, id: record.id)
            let resume = document.checkpoint?.completedWindows ?? 0
            try await engine.analyze(url: url, startWindow: resume) { output, fraction in
                try await self.received(output, fraction: fraction, id: record.id)
            }
            try Task.checkCancellation()
            // Source may have been externally changed while inference was running.
            try await validate(record.id, url: url, segments: segments)
            guard fingerprints[record.id] == fingerprint else { throw MeetingFailure.message("录制文件在分析时发生变化，未发布新的说话人结果。") }
            document = documents[record.id] ?? document
            guard let checkpoint = document.checkpoint else { throw MeetingFailure.message("说话人进度缺失，请重新分析。") }
            let oldNames = Array(Set((document.result?.names.values.map { $0 } ?? []) + (document.result?.previousNames ?? []))).sorted()
            document.result = MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: segments, previousNames: oldNames)
            document.state = .ready; document.failure = nil; document.checkpoint = nil
            try await save(document, id: record.id)
            progress = 1
        } catch {
            var document = documents[record.id] ?? MeetingSpeakerDocument()
            document.state = Task.isCancelled || error is CancellationError ? .interrupted : .failed
            document.failure = document.state == .interrupted ? "说话人分析已停止，进度和原文已保留。" : "说话人分析失败，原文已保留：\(error.localizedDescription)"
            do { try await save(document, id: record.id) } catch { self.error = "说话人结果保存失败：\(error.localizedDescription)" }
        }
    }
    private func received(_ output: SpeakerWindowOutput, fraction: Double, id: UUID) async throws {
        try Task.checkCancellation()
        guard var document = documents[id], var checkpoint = document.checkpoint else { throw MeetingFailure.message("说话人分析进度缺失。") }
        try checkpoint.append(window: output.index, turns: output.turns.map { .init(start: $0.start, end: $0.end, speakerID: $0.speakerID) }, features: output.features)
        document.checkpoint = checkpoint
        try await save(document, id: id)
        progress = fraction
    }
    func rename(id: UUID, speakerID: String, name: String, revision: UUID) async -> Bool {
        guard !closing, !busy, let source = sources[id] else { return false }
        renaming = true
        let operation = Task { () -> Bool in
            defer { renaming = false; renameTask = nil; onIdle?() }
            return await saveName(id: id, speakerID: speakerID, name: name, revision: revision, source: source)
        }
        renameTask = operation
        return await operation.value
    }
    private func saveName(id: UUID, speakerID: String, name: String, revision: UUID,
                          source: (URL, [MeetingTranscriptSegment])) async -> Bool {
        do {
            try await validate(id, url: source.0, segments: source.1)
            guard var document = documents[id], var result = snapshot(for: id), result.revision == revision else {
                throw MeetingFailure.message("原文或说话人结果已变化，请重新打开后命名。")
            }
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.count <= 60, Set(result.assignments.values).contains(speakerID) else { throw MeetingFailure.message("名称最多60个字；请重新打开当前说话人。") }
            if clean.isEmpty { result.names.removeValue(forKey: speakerID) } else { result.names[speakerID] = clean }
            document.result = result
            try await save(document, id: id)
            return true
        } catch { self.error = "名称未保存：\(error.localizedDescription)"; return false }
    }
    func cancel() { task?.cancel() }
    func shutdown() async {
        closing = true; task?.cancel(); downloadTask?.cancel()
        await task?.value; await downloadTask?.value
        _ = await renameTask?.value
    }
}

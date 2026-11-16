import Foundation
import MeetingKit
import SpeakerKit

public struct SpeakerLocalTurn: Sendable {
    public let start: Double
    public let end: Double
    public let speakerID: String
    public init(start: Double, end: Double, speakerID: String) {
        self.start = start; self.end = end; self.speakerID = speakerID
    }
}

public struct SpeakerWindowOutput: Sendable {
    public let index: Int
    public let coreStart: Double
    public let coreEnd: Double
    public let turns: [SpeakerLocalTurn]
    public let features: [String: [Float]]
    public init(index: Int, coreStart: Double, coreEnd: Double, turns: [SpeakerLocalTurn], features: [String: [Float]]) {
        self.index = index; self.coreStart = coreStart; self.coreEnd = coreEnd; self.turns = turns; self.features = features
    }
}

public enum MeetingSpeakerError: LocalizedError {
    case missingModel, invalidFiles, invalidAudio, invalidTimestamp, invalidResumePoint, invalidFeature, incompatibleModel
    case http(Int)
    public var errorDescription: String? {
        switch self {
        case .missingModel: return "请先在模型库下载说话人模型。"
        case .invalidFiles: return "说话人模型文件校验失败，请重新下载。"
        case .invalidAudio: return "会议音频无效，无法区分说话人。"
        case .invalidTimestamp: return "说话人时间戳无效，请重试。"
        case .invalidResumePoint: return "说话人进度与录音不一致，请重新分析。"
        case .invalidFeature: return "有效语音不足，无法可靠区分说话人。"
        case .incompatibleModel: return "说话人模型格式不兼容，请重新下载。"
        case .http(let status): return "说话人模型下载失败（HTTP \(status)）。"
        }
    }
}

/// Installed-only inference; model downloading is solely an explicit operation.
public actor MeetingSpeakerEngine {
    public static let modelBytes: Int64 = 19_197_050
    public static let modelVersion = "speakerkit-0.18.0-pyannote-556fc52a-wespeaker-7eab74f3-meeting-v3"
    private let store: SpeakerModelStore

    public init(root: URL? = nil) {
        store = SpeakerModelStore(root: root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WiseLifeMacCompanion/SpeakerModels", isDirectory: true))
    }

    public func installed() throws -> Bool { try store.installed() }

    public func download(progress: @escaping @Sendable (Double) async -> Void) async throws {
        try await SpeakerOperationPermit.shared.run { [store] in try await store.download(progress: progress) }
    }

    public func analyze(url: URL, startWindow: Int,
                        onWindow: @escaping @Sendable (SpeakerWindowOutput, Double) async throws -> Void) async throws {
        try await SpeakerOperationPermit.shared.run { [store] in
            try await MeetingInferenceGate.shared.run {
                try Task.checkCancellation()
                try store.validate()
                let duration = try await MeetingAudioReader.duration(url)
                let windows = try SpeakerWindowPlan.windows(duration: duration, startWindow: startWindow)
                guard !windows.isEmpty else { return }
                let backend = LocalSpeakerBackend(folder: store.folder)
                try await SpeakerAnalysisRunner.run(windows: windows, duration: duration, backend: backend,
                    read: { start, duration in try await MeetingAudioReader.samples(url, start: start, duration: duration) },
                    onWindow: onWindow)
            }
        }
    }
}

protocol SpeakerInferenceBackend: Sendable {
    func load() async throws
    func diarize(_ samples: [Float]) async throws -> [SpeakerLocalTurn]
    func extract(_ samples: [Float]) async throws -> [Float]
    func unload() async
}

enum SpeakerAnalysisRunner {
    static func run(windows: [SpeakerWindowPlan], duration: Double, backend: any SpeakerInferenceBackend,
                    read: @escaping @Sendable (Double, Double) async throws -> [Float],
                    onWindow: @escaping @Sendable (SpeakerWindowOutput, Double) async throws -> Void) async throws {
        do {
            try Task.checkCancellation()
            try await backend.load()
            for window in windows {
                try Task.checkCancellation()
                // Both context and core are retained only for the current <=304s window.
                var samples: [Float] = []
                let expectedCount = Int(ceil((window.inputEnd - window.inputStart) * 16_000))
                guard expectedCount > 0, expectedCount <= 304 * 16_000 else { throw MeetingSpeakerError.invalidAudio }
                samples.reserveCapacity(expectedCount)
                var position = window.inputStart
                while position < window.inputEnd {
                    try Task.checkCancellation()
                    let length = min(60, window.inputEnd - position)
                    let chunk = try await read(position, length)
                    let expected = Int(ceil(length * 16_000))
                    // Missing samples cannot be concatenated: doing so shifts all later timestamps.
                    guard (expected - 1...expected).contains(chunk.count), chunk.allSatisfy(\.isFinite), samples.count + expected <= expectedCount else {
                        throw MeetingSpeakerError.invalidAudio
                    }
                    samples.append(contentsOf: chunk)
                    // Fractional media duration may round up by one 16kHz sample.
                    // Preserve absolute positions; never close a gap by shifting audio.
                    if chunk.count < expected { samples.append(0) }
                    position += length
                }
                try Task.checkCancellation()
                let local = try await backend.diarize(samples)
                try Task.checkCancellation()
                let turns = try window.project(local)
                var features: [String: [Float]] = [:]
                for id in Set(turns.map(\.speakerID)).sorted() {
                    let ranges = SpeakerFeaturePolicy.soloRanges(turns: local, speakerID: id, sampleCount: samples.count)
                    let coreStart = Int(ceil((window.coreStart - window.inputStart) * 16_000))
                    let coreEnd = Int(floor((window.coreEnd - window.inputStart) * 16_000))
                    let coreSpeech = ranges.reduce(0) { count, range in
                        count + max(0, min(coreEnd, range.upperBound) - max(coreStart, range.lowerBound))
                    }
                    // Context improves evidence for core speech, but a tiny
                    // core fragment cannot establish a separate identity.
                    guard coreSpeech >= 32_000 else { continue }
                    var vectors: [[Float]] = []
                    for clean in SpeakerFeaturePolicy.samples(samples, ranges: ranges) {
                        try Task.checkCancellation()
                        do { vectors.append(try await backend.extract(clean)) }
                        catch MeetingSpeakerError.invalidFeature {
                            // Degenerate evidence leaves this cluster unknown; it does
                            // not erase its turns or fail otherwise valid speakers.
                            vectors = []; break
                        }
                    }
                    if let feature = SpeakerFeaturePolicy.consensus(vectors) { features[id] = feature }
                }
                try Task.checkCancellation()
                try await onWindow(.init(index: window.index, coreStart: window.coreStart, coreEnd: window.coreEnd,
                                         turns: turns, features: features), min(1, window.coreEnd / duration))
            }
        } catch {
            // Keep the permit until all in-flight model work and cleanup finish.
            await backend.unload()
            throw error
        }
        await backend.unload()
        try Task.checkCancellation()
    }
}

private actor LocalSpeakerBackend: SpeakerInferenceBackend {
    private let folder: URL
    private var speakerKit: SpeakerKit?
    private let embedding: SpeakerEmbeddingEngine
    init(folder: URL) { self.folder = folder; embedding = SpeakerEmbeddingEngine(folder: folder) }
    func load() async throws {
        // Lazy loading keeps a reference available for cleanup if model loading fails.
        speakerKit = try await SpeakerKit(PyannoteConfig(modelFolder: folder.path, download: false, load: false,
            verbose: false, concurrentSegmenterWorkers: 1, concurrentEmbedderWorkers: 1))
        try Task.checkCancellation()
    }
    func diarize(_ samples: [Float]) async throws -> [SpeakerLocalTurn] {
        guard let speakerKit else { throw MeetingSpeakerError.missingModel }
        // Upstream internally awaits its segmenter task. Cancellation waits for that
        // bounded window to finish; never unload concurrently with Core ML inference.
        let result = try await speakerKit.diarize(audioArray: samples)
        try Task.checkCancellation()
        return result.segments.compactMap { segment in
            guard let id = segment.speaker.speakerId, id >= 0 else { return nil }
            return .init(start: Double(segment.startTime), end: Double(segment.endTime), speakerID: String(id))
        }
    }
    func extract(_ samples: [Float]) async throws -> [Float] { try await embedding.extract(samples: samples) }
    func unload() async {
        await speakerKit?.unloadModels()
        speakerKit = nil
        await embedding.unload()
    }
}

/// Global permit survives actor reentrancy and also covers independent engine
/// instances. Cancelled waiters never release a permit they did not acquire.
actor SpeakerOperationPermit {
    static let shared = SpeakerOperationPermit()
    private struct Waiter { let id: UUID; let continuation: CheckedContinuation<Void, Error> }
    private var occupied = false
    private var waiters: [Waiter] = []
    func run(operation: @Sendable () async throws -> Void) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await acquire(id)
        } onCancel: { Task { await self.cancel(id) } }
        defer { release() }
        try Task.checkCancellation()
        try await operation()
    }
    private func acquire(_ id: UUID) async throws {
        try Task.checkCancellation()
        if !occupied { occupied = true; return }
        try await withCheckedThrowingContinuation { waiters.append(.init(id: id, continuation: $0)) }
    }
    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
    private func release() {
        if waiters.isEmpty { occupied = false }
        else { waiters.removeFirst().continuation.resume() }
    }
}

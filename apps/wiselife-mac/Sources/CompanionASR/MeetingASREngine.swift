import Foundation
import MeetingKit
import Tokenizers
import WhisperKit

public struct MeetingASRModel: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let bytes: Int64
}

public enum MeetingASRError: LocalizedError {
    case unsupportedModel, unsupportedLanguage, missingModel, invalidFiles, invalidAudio, invalidTimestamp, invalidResumePoint
    case http(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedModel: return "不支持此转写模型。请选择 Tiny、Base 或 Small。"
        case .unsupportedLanguage: return "此转写模型不支持所选语言，请选择自动检测。"
        case .missingModel: return "请先在模型库下载所选语音转写模型。"
        case .invalidFiles: return "转写模型文件校验失败，请重新下载模型。"
        case .invalidAudio: return "录音时长或音频样本无效，无法转写。"
        case .invalidTimestamp: return "转写结果时间戳无效，请重试。"
        case .invalidResumePoint: return "转写进度与当前录音不一致，请重新开始。"
        case .http(let status): return "语音模型下载失败（HTTP \(status)）。"
        }
    }
}

/// Local-only transcription. Downloading is an explicit, separate operation.
/// The shared permit remains held through all awaits and model unloading, so actor
/// reentrancy (including multiple engine instances) cannot overlap inference/install.
public actor MeetingASREngine {
    public static let models: [MeetingASRModel] = [
        .init(id: "tiny", name: "Whisper Tiny", bytes: 79_400_740),
        .init(id: "base", name: "Whisper Base", bytes: 149_484_796),
        .init(id: "small", name: "Whisper Small", bytes: 489_252_808),
    ]
    private let store: ASRModelStore

    public init(root: URL? = nil) {
        store = ASRModelStore(root: root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WiseLifeMacCompanion/ASRModels", isDirectory: true))
    }

    public func installed(size: String) throws -> Bool {
        _ = try store.files(for: size)
        return store.installed(size)
    }

    public func download(size: String, progress: @escaping @Sendable (Double) async -> Void) async throws {
        try await ASROperationPermit.shared.run { [store] in
            try await store.download(size, progress: progress)
        }
    }

    public func transcribe(url: URL, size: String, language: String, startChunk: Int,
                           onChunk: @escaping @Sendable (Int, [MeetingTranscriptSegment], Double) async throws -> Void) async throws {
        try await ASROperationPermit.shared.run { [store] in
            try await MeetingInferenceGate.shared.run {
                try Task.checkCancellation()
                guard language == "auto" || Self.languages.contains(language) else { throw MeetingASRError.unsupportedLanguage }
                try store.validate(size)
                let duration = try await MeetingAudioReader.duration(url)
                guard duration.isFinite, duration > 0, duration < Double(Int.max / 60) else { throw MeetingASRError.invalidAudio }
                let count = Int(ceil(duration / 60))
                guard startChunk >= 0, startChunk <= count else { throw MeetingASRError.invalidResumePoint }
                if startChunk == count { return }
                let folder = store.folder(for: size)
                try await ASRTokenizerPreflight.validate(folder: folder)
                // Matches iPhone LocalTranscriptionService: allow model dimensions to
                // choose the multilingual tokenizer, and forbid all model downloads.
                let engine = try await WhisperKit(WhisperKitConfig(modelFolder: folder.path,
                    tokenizerFolder: folder, verbose: false, prewarm: false, load: false, download: false))
                do {
                    try Task.checkCancellation()
                    try await engine.loadModels()
                    let automatic = language == "auto"
                    let options = DecodingOptions(language: automatic ? nil : language,
                        detectLanguage: automatic, skipSpecialTokens: true, withoutTimestamps: false,
                        wordTimestamps: false, concurrentWorkerCount: 1)
                    for index in startChunk..<count {
                        try Task.checkCancellation()
                        let start = Double(index) * 60
                        let length = min(60, duration - start)
                        let samples = try await MeetingAudioReader.samples(url, start: start, duration: length)
                        guard !samples.isEmpty, samples.count <= 960_000, samples.allSatisfy(\.isFinite) else {
                            throw MeetingASRError.invalidAudio
                        }
                        try Task.checkCancellation()
                        let results: [TranscriptionResult] = try await engine.transcribe(audioArray: samples, decodeOptions: options)
                        try Task.checkCancellation()
                        let segments = try ASRSegmentProjection.project(results.flatMap(\.segments), chunk: index, duration: length)
                        try await onChunk(index, segments, min(1, (start + length) / duration))
                    }
                    await engine.unloadModels()
                } catch {
                    // Do not release the global permit until Core ML work has stopped.
                    await engine.unloadModels()
                    throw error
                }
                try Task.checkCancellation()
            }
        }
    }

    // Original Whisper multilingual vocabulary; no unsupported later yue token.
    private static let languages = Set("zh en de es ru ko fr ja pt tr pl ca nl ar sv it id hi fi vi he uk el ms cs ro da hu ta no th ur hr bg lt la mi ml cy sk te fa lv bn sr az sl kn et mk br eu is hy ne mn bs kk sq sw gl mr pa si km sn yo so af oc ka be tg sd gu am yi lo uz fo ht ps tk nn mt sa lb my bo tl mg as tt haw ln ha ba jw su".split(separator: " ").map(String.init))
}

/// WhisperKit 0.18.0 catches local tokenizer parse errors and falls back to Hub.
/// Exercise its exact local PreTrainedTokenizer parser first, which has no remote
/// fallback. Never inject this tokenizer before Core ML dimensions are detected:
/// doing so would skip WhisperKit's multilingual/model-variant initialization.
enum ASRTokenizerPreflight {
    static func validate(folder: URL) async throws {
        try Task.checkCancellation()
        // Upstream searches a Hub cache under models/ before the supplied folder.
        // Such unpinned extra files must not shadow our verified local tokenizer.
        guard !FileManager.default.fileExists(atPath: folder.appendingPathComponent("models").path) else {
            throw MeetingASRError.invalidFiles
        }
        do {
            _ = try await AutoTokenizer.from(modelFolder: folder)
        } catch {
            try Task.checkCancellation()
            throw MeetingASRError.invalidFiles
        }
        try Task.checkCancellation()
    }
}

/// Pure projection kept testable without weights. IDs remain stable across resume.
enum ASRSegmentProjection {
    static func project(_ input: [TranscriptionSegment], chunk: Int, duration: Double) throws -> [MeetingTranscriptSegment] {
        var output: [MeetingTranscriptSegment] = []
        for (index, segment) in input.enumerated() {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains),
                  !(segment.noSpeechProb > 0.6 && segment.avgLogprob < -1) else { continue }
            let start = Double(segment.start), end = Double(segment.end)
            // Whisper decodes padded 30s model windows. Its estimated final
            // timestamp can extend beyond real samples (e.g. 60.32 for 60s).
            // Keep speech overlapping real audio, clipping only the end; discard
            // segments entirely in padding. Do not fail a whole valid chunk.
            guard start.isFinite, end.isFinite, start >= 0, end >= start,
                  end <= duration + 30.02 else { throw MeetingASRError.invalidTimestamp }
            guard start < duration, end > start else { continue }
            output.append(.init(id: "chunk-\(chunk)-segment-\(index)", start: Double(chunk) * 60 + start,
                                end: Double(chunk) * 60 + min(end, duration), text: text))
        }
        return output
    }
}

/// Adapted from iPhone WhisperModelStore.ModelInstallCoordinator. Cancellation of
/// a queued operation removes only its waiter; active operations retain the permit.
actor ASROperationPermit {
    static let shared = ASROperationPermit()
    private struct Waiter { let id: UUID; let continuation: CheckedContinuation<Void, Error> }
    private var occupied = false
    private var waiters: [Waiter] = []

    func run(operation: @Sendable () async throws -> Void) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await acquire(id)
        } onCancel: {
            Task { await self.cancel(id) }
        }
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

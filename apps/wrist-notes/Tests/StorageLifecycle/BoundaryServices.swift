// Focused host only: external inference/configuration services are outside these storage tests.
// Production NotesModel, connectivity, repositories, photo model and reminder store are compiled unchanged.
import Foundation
import Combine
struct AIConfiguration: Equatable {
    enum Mode { case local, custom, chatgpt, nearbyMac }
    var mode = Mode.local
    var model = "fixture"
    var chatGPTModel = "test"
    var chatGPTAccountID: String? = nil
    var isRemote: Bool { mode != .local }
    var label: String { "inference disabled in lifecycle tests" }
}
@MainActor final class AppSettings {
    @Published var transcription = TranscriptionConfiguration()
    var ai = AIConfiguration()
    @Published var aiRevision = 0
    @Published var requiresRemoteAIConfirmation = true
    var chatGPT = LifecycleChatGPT()
    func authorizeRemoteAISend(confirmationIsCurrent: Bool?, rememberChoice: Bool) -> Bool { false }
    func apiKey() throws -> String { throw URLError(.unsupportedURL) }
}
struct VoiceProfile { let id = UUID() }
struct VoiceDiarizationOutput {
    var segments: [TranscriptSegment]
    var profileID: UUID? = nil
    var ownerSpeakerIDs: Set<String> = []
    var identityMessage: String? = nil
}
@MainActor final class MyVoiceProfileModel {
    var profile: VoiceProfile?
    init(enroll: ((URL) async throws -> VoiceProfile)? = nil) {}
}
struct LocalTranscriptionService {
    static let shared = LocalTranscriptionService()
    static var durableCalls = 0
    func process(window: AudioProcessingWindow, configuration: TranscriptionConfiguration, stages: AudioInferenceStages,
                 sourceDuration: Double?, priorSpans: [AudioTranscriptSpan], maximumCoreDuration: Double) async throws -> AudioInferenceDelta {
        Self.durableCalls += 1
        throw URLError(.unsupportedURL)
    }
    func enrollVoice(fileURL: URL) async throws -> VoiceProfile { throw URLError(.unsupportedURL) }
    func transcribeWithSegments(fileURL: URL, configuration: TranscriptionConfiguration) async throws -> TranscriptionOutput { throw URLError(.unsupportedURL) }
    func diarizeWithIdentity(fileURL: URL, segments: [TranscriptSegment], profile: VoiceProfile?) async throws -> VoiceDiarizationOutput { throw URLError(.unsupportedURL) }
}
enum TranscriptionFailure: Error { case unavailable }
enum SummaryFailure: Error { case unavailable }
enum SpeakerDiarizationError: Error { case missingTimestamps }
struct OnDeviceSummarizer {
    func summarize(_ text: String, kind: RecordingKind) async throws -> String { throw SummaryFailure.unavailable }
}
struct OnDeviceRecordingTitleGenerator {
    func generate(from transcript: String) async -> String? { nil }
}
struct LifecycleChatGPT {
    func complete(instruction: String, content: String, modelID: String, accountID: String?, isCurrent: @MainActor () -> Bool,
                  sourceIsCurrent: (@MainActor () async throws -> Bool)? = nil) async throws -> String { throw SummaryFailure.unavailable }
}
struct CustomAISummarizer {
    static let recordingTitleInstruction = "disabled"
    static func recordingTitleExcerpts(_ text: String) -> String { text }
    func recordingTitle(_ text: String, configuration: AIConfiguration, apiKey: String, isCurrent: @MainActor () -> Bool) async throws -> String? { throw SummaryFailure.unavailable }
    func summarize(_ text: String, configuration: AIConfiguration, apiKey: String, isCurrent: @MainActor () -> Bool) async throws -> String { throw SummaryFailure.unavailable }
}
struct ChatGPTSummarizer {
    init(account: LifecycleChatGPT) {}
    func summarize(_ text: String, configuration: AIConfiguration, isCurrent: @MainActor () -> Bool) async throws -> String { throw SummaryFailure.unavailable }
}

@MainActor enum AudioCaptureActivity { static var activeIDs = Set<UUID>() }

enum ActionStore { static let itemsDidChange = Notification.Name("WiseLife.ActionItemsDidChange") }
@MainActor struct ConfiguredContentTextModel {
    let configuration: AIConfiguration
    let authorized: @MainActor () async throws -> Bool
    let apiKey: @MainActor () throws -> String
    let local: @MainActor (ContentLocalRequest) async throws -> ContentLocalReply
    let chat: @MainActor (String, String, AIConfiguration) async throws -> String
    static func configurationKey(_ configuration: AIConfiguration) -> String { "lifecycle-fixture" }
    func respond(_ request: ContentLocalRequest) async throws -> ContentLocalReply { throw SummaryFailure.unavailable }
    func respond(instruction: String, content: String) async throws -> String { throw SummaryFailure.unavailable }
    func summaryBudget(context: String) -> ContentModelBudget { .unknown(context: context) }
}

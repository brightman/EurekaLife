import Foundation
import XCTest
@testable import WiseLife

@MainActor final class NotesDiarizationTests: XCTestCase {
    private func fixture(kind: RecordingKind = .long, duration: Double = 3) throws -> (NoteRepository, VoiceNote, AppSettings) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = try NoteRepository(root: root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("input.m4a")
        try Data([1, 2]).write(to: audio)
        var note = try repository.importRecording(id: UUID(), from: audio, kind: kind, capturedAt: .now, duration: duration)
        note.transcript = "previous"; note.transcriptionState = .ready
        try repository.update(id: note.id) { $0 = note }
        let suite = "SpeakerTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return (repository, note, AppSettings(defaults: defaults))
    }
    private var output: TranscriptionOutput {
        .init(text: "Hello. Hi.", segments: [.init(start: 0, end: 1, text: "Hello."), .init(start: 2, end: 3, text: " Hi.")])
    }
    private func database(_ repository: NoteRepository, note: VoiceNote) throws -> DaybookDatabase {
        let root = repository.audioURL(for: note).deletingLastPathComponent().deletingLastPathComponent()
        return try DaybookDatabase(url: DaybookDatabase.metadataURL(forRoot: root))
    }
    private func failWrites(_ database: DaybookDatabase) throws {
        try database.execute("CREATE TRIGGER block_note_updates BEFORE UPDATE ON voice_notes BEGIN SELECT RAISE(ABORT,'synthetic write failure'); END")
    }

    func testThoughtTranscriptionAndManualRetryNeverAnalyzeSpeakers() async throws {
        for duration in [3.0, 3_600.0] {
            let (repository, note, settings) = try fixture(kind: .thought, duration: duration)
            let output = output
            var calls = 0
            let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
                generateTitleLocally: { _ in nil }, transcribeWithSegments: { _, _ in output },
                diarizeWithIdentity: { _, pieces, _ in calls += 1; return .init(segments: pieces) })
            await model.transcribe(note.id)
            await model.identifySpeakers(note.id)
            XCTAssertEqual(calls, 0, "Thoughts must skip both diarization and voice identity inference")
            XCTAssertEqual(repository.notes[0].transcriptSegments, output.segments)
            XCTAssertEqual(repository.notes[0].transcriptionState, .ready)
            XCTAssertNil(repository.notes[0].diarizationState)
            XCTAssertEqual(model.note(note.id)?.speakerName(nil), "我")
        }
    }

    func testHistoricalThoughtRetryClearsObsoleteSpeakerStatusWithoutChangingTranscript() async throws {
        for state in [ProcessingState.running, .failed, .unavailable, .ready] {
            let (repository, note, settings) = try fixture(kind: .thought)
            let output = output
            try repository.update(id: note.id) {
                $0.applyTranscription(output)
                $0.diarizationState = state
                $0.diarizationMessage = "Old failure"
                $0.voiceIdentityMessage = "Old identity failure"
            }
            var calls = 0
            let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
                generateTitleLocally: { _ in nil },
                diarizeWithIdentity: { _, pieces, _ in calls += 1; return .init(segments: pieces) })
            await model.identifySpeakers(note.id)
            await Task.yield() // Also let the persisted .running recovery task execute.
            XCTAssertEqual(calls, 0)
            XCTAssertEqual(repository.notes[0].transcriptSegments, output.segments)
            XCTAssertNil(repository.notes[0].diarizationState)
            XCTAssertNil(repository.notes[0].diarizationMessage)
            XCTAssertNil(repository.notes[0].voiceIdentityMessage)
        }
    }

    func testTranscriptionPersistsBeforeDiarizationAndFailureCanRetry() async throws {
        let (repository, note, settings) = try fixture()
        let output = output
        var fail = true
        let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
            transcribeWithSegments: { _, _ in output }, diarize: { _, pieces in
                XCTAssertEqual(repository.notes[0].transcript, "Hello. Hi.")
                XCTAssertEqual(repository.notes[0].transcriptionState, .ready)
                if fail { throw URLError(.cannotLoadFromNetwork) }
                return SpeakerAlignment.align(pieces, turns: [.init(start: 0, end: 1, speaker: 7), .init(start: 2, end: 3, speaker: 2)])
            })
        await model.transcribe(note.id)
        XCTAssertEqual(model.note(note.id)?.transcriptionState, .ready)
        XCTAssertEqual(model.note(note.id)?.diarizationState, .failed)
        XCTAssertEqual(model.note(note.id)?.transcript, "Hello. Hi.")
        fail = false
        await model.identifySpeakers(note.id)
        XCTAssertEqual(model.note(note.id)?.diarizationState, .ready)
        XCTAssertEqual(model.note(note.id)?.transcriptSegments?.map(\.speakerID), ["speaker-1", "speaker-2"])
        model.renameSpeaker(noteID: note.id, speakerID: "speaker-2", name: "Bob")
        XCTAssertEqual(repository.notes[0].speakerName("speaker-2"), "Bob")
    }

    func testManualEditDuringDiarizationWins() async throws {
        let (repository, note, settings) = try fixture()
        let output = output
        let gate = InferenceGate()
        let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
            transcribeWithSegments: { _, _ in output }, diarize: { _, pieces in
                await gate.pause()
                return SpeakerAlignment.align(pieces, turns: [.init(start: 0, end: 3, speaker: 0)])
            })
        let task = Task { await model.transcribe(note.id) }
        await gate.waitUntilPaused()
        model.save(id: note.id, title: "edited", transcript: "My words")
        await gate.resume()
        await task.value
        XCTAssertEqual(model.note(note.id)?.transcript, "My words")
        XCTAssertNil(model.note(note.id)?.transcriptSegments)
        XCTAssertNotEqual(model.note(note.id)?.diarizationState, .running)
    }

    func testEditAndRestoreDuringASRStillWins() async throws {
        let (repository, note, settings) = try fixture()
        let output = output
        let gate = InferenceGate()
        let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
            transcribeWithSegments: { _, _ in await gate.pause(); return output },
            diarize: { _, _ in XCTFail("Edited ASR result must not trigger diarization"); return [] })
        let task = Task { await model.transcribe(note.id) }
        await gate.waitUntilPaused()
        model.save(id: note.id, title: note.title, transcript: "edited")
        model.save(id: note.id, title: note.title, transcript: "previous")
        await gate.resume()
        await task.value
        XCTAssertEqual(model.note(note.id)?.transcript, "previous")
    }

    func testASRPersistenceFailureDoesNotStartDiarization() async throws {
        let (repository, note, settings) = try fixture()
        let output = output
        let database = try database(repository, note: note)
        var diarizationCalls = 0
        let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
            transcribeWithSegments: { _, _ in
                try self.failWrites(database)
                return output
            }, diarize: { _, pieces in diarizationCalls += 1; return pieces })
        await model.transcribe(note.id)
        XCTAssertEqual(diarizationCalls, 0)
        XCTAssertEqual(model.note(note.id)?.transcript, "previous")
        XCTAssertNotEqual(model.note(note.id)?.transcriptionState, .running)
        XCTAssertNotNil(model.errorMessage)
    }

    func testFinalDiarizationWriteFailureAllowsRetry() async throws {
        let (repository, note, settings) = try fixture()
        let output = output
        let database = try database(repository, note: note)
        var fail = true
        let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
            transcribeWithSegments: { _, _ in output }, diarize: { _, pieces in
                if fail {
                    try self.failWrites(database)
                }
                return SpeakerAlignment.align(pieces, turns: [.init(start: 0, end: 3, speaker: 0)])
            })
        await model.transcribe(note.id)
        XCTAssertEqual(model.note(note.id)?.transcript, "Hello. Hi.")
        XCTAssertNotEqual(model.note(note.id)?.diarizationState, .running)
        try database.execute("DROP TRIGGER block_note_updates")
        fail = false
        await model.identifySpeakers(note.id)
        XCTAssertEqual(model.note(note.id)?.diarizationState, .ready)
    }

    func testDeletionDuringInferenceDoesNotResurrectNote() async throws {
        let (repository, note, settings) = try fixture()
        let output = output
        let gate = InferenceGate()
        let model = NotesModel(repository: repository, settings: settings, connectWatch: false,
            transcribeWithSegments: { _, _ in output }, diarize: { _, pieces in await gate.pause(); return pieces })
        let task = Task { await model.transcribe(note.id) }
        await gate.waitUntilPaused()
        model.delete(note.id)
        await gate.resume()
        await task.value
        XCTAssertNil(model.note(note.id))
        XCTAssertTrue(repository.notes.isEmpty)
    }
}

private actor InferenceGate {
    var paused = false
    var observers: [CheckedContinuation<Void, Never>] = []
    var continuation: CheckedContinuation<Void, Never>?
    func pause() async {
        paused = true
        observers.forEach { $0.resume() }; observers.removeAll()
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilPaused() async {
        if paused { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func resume() { continuation?.resume(); continuation = nil }
}

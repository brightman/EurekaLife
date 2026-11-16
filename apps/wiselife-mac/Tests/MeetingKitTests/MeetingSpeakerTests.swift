import XCTest
@testable import MeetingKit

final class MeetingSpeakerTests: XCTestCase {
    private func turn(_ start: Double, _ end: Double, _ id: String) -> MeetingSpeakerTurn {
        .init(start: start, end: end, speakerID: id)
    }
    private func row(_ id: String, _ start: Double, _ end: Double) -> MeetingTranscriptSegment {
        .init(id: id, start: start, end: end, text: "原始文字")
    }
    func testLocalPermutationUsesFeaturesAndFirstAppearanceOrder() throws {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        try checkpoint.append(window: 0, turns: [turn(5, 8, "a"), turn(0, 4, "z")], features: ["a": [0, 1], "z": [1, 0]])
        try checkpoint.append(window: 1, turns: [turn(300, 304, "a"), turn(305, 308, "z")], features: ["a": [1, 0], "z": [0, 1]])
        XCTAssertEqual(checkpoint.turns.map(\.speakerID), ["speaker-1", "speaker-2", "speaker-1", "speaker-2"])
        XCTAssertEqual(checkpoint.nextSpeaker, 3)
    }
    func testGrayZoneDoesNotSilentlyCreateAnotherIdentity() throws {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        try checkpoint.append(window: 0, turns: [turn(0, 5, "a")], features: ["a": [1, 0]])
        try checkpoint.append(window: 1, turns: [turn(300, 305, "x")], features: ["x": [0.85, 0.5267827]])
        XCTAssertEqual(checkpoint.turns.last?.speakerID, "")
        XCTAssertEqual(checkpoint.nextSpeaker, 2)
        try checkpoint.append(window: 2, turns: [turn(600, 605, "new")], features: ["new": [0, 1]])
        XCTAssertEqual(checkpoint.turns.last?.speakerID, "speaker-2")
    }
    func testSameWindowCannotCollapseTwoLocalIdentities() throws {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        try checkpoint.append(window: 0, turns: [turn(0, 5, "a")], features: ["a": [1, 0]])
        try checkpoint.append(window: 1, turns: [turn(300, 304, "x"), turn(301, 305, "y")], features: ["x": [1, 0], "y": [1, 0]])
        let ids = checkpoint.turns.suffix(2).map(\.speakerID).filter { !$0.isEmpty }
        XCTAssertEqual(Set(ids).count, ids.count)
    }
    func testAmbiguousAndMissingFeaturesRemainUnknown() throws {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        try checkpoint.append(window: 0, turns: [turn(0, 2, "a"), turn(3, 5, "b")], features: ["a": [1, 0], "b": [0.98, 0.2]])
        try checkpoint.append(window: 1, turns: [turn(300, 302, "x"), turn(303, 305, "missing")], features: ["x": [1, 0]])
        XCTAssertEqual(checkpoint.turns.suffix(2).map(\.speakerID), ["", ""])
    }
    func testCheckpointReplayIsExactlyOnceAndGapRejectedWithoutMutation() throws {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        try checkpoint.append(window: 0, turns: [turn(0, 4, "a")], features: ["a": [1, 0]])
        let encoded = try JSONEncoder().encode(checkpoint)
        var resumed = try JSONDecoder().decode(MeetingSpeakerCheckpoint.self, from: encoded)
        try resumed.append(window: 0, turns: [turn(1, 9, "other")], features: ["other": [0, 1]])
        XCTAssertEqual(resumed.turns, checkpoint.turns)
        XCTAssertThrowsError(try resumed.append(window: 2, turns: [], features: [:]))
        XCTAssertEqual(resumed.completedWindows, 1)
        XCTAssertEqual(resumed.nextSpeaker, 2)
        XCTAssertThrowsError(try resumed.append(window: 1, turns: [turn(2, .nan, "a")], features: [:]))
        XCTAssertEqual(resumed.completedWindows, 1)
    }
    func testAlignmentRejectsOverlapTiesUnknownAndInsufficientCoverage() {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        checkpoint.turns = [turn(0, 6, "speaker-1"), turn(10, 15, "speaker-1"), turn(15, 20, "speaker-2"), turn(30, 40, "speaker-1"), turn(39, 41, "speaker-2"), turn(50, 55, "speaker-1"), turn(60, 65, "speaker-1"), turn(65, 70, "")]
        let segments = [row("covered", 0, 10), row("tie", 10, 20), row("overlap", 30, 40), row("short", 50, 60), row("unknown", 60, 70)]
        let before = segments
        let snapshot = MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: segments)
        XCTAssertEqual(snapshot.assignments, ["covered": "speaker-1"])
        XCTAssertEqual(segments, before)
    }
    func testDuplicateSameSpeakerIntervalsDoNotInflateCoverage() {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        checkpoint.turns = [turn(0, 4, "speaker-1"), turn(0, 4, "speaker-1")]
        XCTAssertTrue(MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: [row("a", 0, 10)]).assignments.isEmpty)
    }
    func testNewSnapshotNeverAppliesPriorNamesToNewIDs() {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "new")
        checkpoint.turns = [turn(0, 5, "speaker-1")]
        let snapshot = MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: [row("a", 0, 5)], previousNames: ["主持人"])
        XCTAssertTrue(snapshot.names.isEmpty)
        XCTAssertEqual(snapshot.previousNames, ["主持人"])
        XCTAssertEqual(snapshot.displayName("speaker-1"), "说话人1")
        var document = MeetingSpeakerDocument(); document.result = snapshot
        XCTAssertNil(document.currentResult(fingerprint: "old"))
        XCTAssertEqual(document.currentResult(fingerprint: "new")?.revision, snapshot.revision)
    }
    func testStoreRecoversCheckpointAndPreservesPublishedNamesAndResult() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSpeakerStore(root: root), id = UUID()
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        try checkpoint.append(window: 0, turns: [turn(0, 4, "a")], features: ["a": [1, 0]])
        var value = MeetingSpeakerDocument()
        value.result = MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: [row("a", 0, 4)])
        value.result?.names["speaker-1"] = "主持人"
        value.state = .running; value.checkpoint = checkpoint
        try await store.save(value, for: id)
        let reopened = MeetingSpeakerStore(root: root)
        let reopenedValue = try await reopened.load(id: id, recoverInterrupted: true)
        var loaded = try XCTUnwrap(reopenedValue)
        XCTAssertEqual(loaded.state, .interrupted)
        XCTAssertEqual(loaded.checkpoint?.completedWindows, 1)
        XCTAssertEqual(loaded.result?.revision, value.result?.revision)
        XCTAssertEqual(loaded.result?.displayName("speaker-1"), "主持人")
        loaded.state = .failed; loaded.failure = "synthetic failure"
        try await reopened.save(loaded, for: id)
        let final = try await store.load(id: id)
        XCTAssertEqual(final?.result?.revision, value.result?.revision)
    }
    func testCorruptFileCannotBeOverwrittenEvenWithoutPriorLoad() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), id = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent(id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("speakers.json"), bytes = Data("{broken".utf8)
        try bytes.write(to: file)
        let store = MeetingSpeakerStore(root: root)
        do { try await store.save(MeetingSpeakerDocument(), for: id); XCTFail("Corruption overwritten") } catch {}
        do { _ = try await store.load(id: id); XCTFail("Corruption accepted") } catch {}
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }
    func testUnknownOverlapRejectsEvenNinetyNinePercentDominantSpeech() {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        checkpoint.turns = [turn(0, 100, "speaker-1"), turn(99, 100, "")]
        let snapshot = MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: [row("a", 0, 100)])
        XCTAssertNil(snapshot.assignments["a"])
    }
    func testInvalidFeaturesNeverCreateIdentities() throws {
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "v1")
        try checkpoint.append(window: 0, turns: [turn(0, 1, "zero"), turn(1, 2, "nan")], features: ["zero": [0, 0], "nan": [.nan, 1]])
        XCTAssertEqual(checkpoint.nextSpeaker, 1)
        XCTAssertTrue(checkpoint.features.isEmpty)
        XCTAssertEqual(checkpoint.turns.map(\.speakerID), ["", ""])
    }
    func testFutureSchemaAndSymlinkDestinationCannotBeOverwritten() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID(), store = MeetingSpeakerStore(root: root)
        let directory = root.appendingPathComponent(id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var future = MeetingSpeakerDocument(); future.schemaVersion = 99
        let bytes = try JSONEncoder().encode(future), url = directory.appendingPathComponent("speakers.json")
        try bytes.write(to: url)
        do { try await store.save(MeetingSpeakerDocument(), for: id); XCTFail("Future schema overwritten") } catch {}
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        let alias = UUID()
        let emptySibling = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: emptySibling, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(alias.uuidString), withDestinationURL: emptySibling)
        do { try await store.save(MeetingSpeakerDocument(), for: alias); XCTFail("Meeting symlink accepted") } catch {}
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testSiblingMeetingSymlinkCannotReadOrOverwritePublishedResult() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let meetingA = UUID(), meetingB = UUID(), store = MeetingSpeakerStore(root: root)
        var original = MeetingSpeakerDocument(); original.state = .ready
        original.result = MeetingSpeakerSnapshot(checkpoint: .init(fingerprint: "meeting-B"), segments: [])
        try await store.save(original, for: meetingB)
        let destination = root.appendingPathComponent(meetingB.uuidString)
        let file = destination.appendingPathComponent("speakers.json")
        let bytes = try Data(contentsOf: file)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(meetingA.uuidString), withDestinationURL: destination)
        do { _ = try await store.load(id: meetingA); XCTFail("Read another meeting through sibling symlink") } catch {}
        do { try await store.save(MeetingSpeakerDocument(), for: meetingA); XCTFail("Wrote another meeting through sibling symlink") } catch {}
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }
    func testCancelledFingerprintDoesNotReadSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = MeetingSpeakerStore(root: root)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await store.fingerprint(url: root.appendingPathComponent("missing"), segments: [], modelVersion: "v1")
        }
        do { _ = try await task.value; XCTFail("Cancelled hash succeeded") }
        catch is CancellationError { }
        catch { XCTFail("Read missing source before checking cancellation: \(error)") }
    }
    func testFingerprintChangesForSameLengthMediaTranscriptAndModel() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let media = root.appendingPathComponent("synthetic.raw"), store = MeetingSpeakerStore(root: root)
        try Data(repeating: 1, count: 2_100_000).write(to: media)
        let segments = [row("a", 0, 5)]
        let original = try await store.fingerprint(url: media, segments: segments, modelVersion: "v1")
        let repeated = try await store.fingerprint(url: media, segments: segments, modelVersion: "v1")
        XCTAssertEqual(original, repeated)
        let handle = try FileHandle(forWritingTo: media); try handle.seek(toOffset: 1_100_000); try handle.write(contentsOf: Data([2])); try handle.close()
        let changedMedia = try await store.fingerprint(url: media, segments: segments, modelVersion: "v1")
        XCTAssertNotEqual(original, changedMedia)
        var edited = segments; edited[0].text = "修改文字"
        let changedText = try await store.fingerprint(url: media, segments: edited, modelVersion: "v1")
        let changedModel = try await store.fingerprint(url: media, segments: segments, modelVersion: "v2")
        XCTAssertNotEqual(changedMedia, changedText)
        XCTAssertNotEqual(changedMedia, changedModel)
    }
}

import CryptoKit
import Foundation
import XCTest
import WhisperKit
@testable import CompanionASR

final class CompanionASRTests: XCTestCase {
    func testTokenizerPreflightFailsClosedForMissingOrMalformedLocalFiles() async throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        do {
            try await ASRTokenizerPreflight.validate(folder: fixture.root)
            XCTFail("Missing tokenizer must fail locally")
        } catch { XCTAssertTrue(error is MeetingASRError) }
        try Data("not JSON".utf8).write(to: fixture.root.appendingPathComponent("tokenizer.json"))
        try Data("{}".utf8).write(to: fixture.root.appendingPathComponent("tokenizer_config.json"))
        do {
            try await ASRTokenizerPreflight.validate(folder: fixture.root)
            XCTFail("Malformed tokenizer must fail locally")
        } catch { XCTAssertTrue(error is MeetingASRError) }
    }

    func testTokenizerPreflightRejectsUnpinnedHubCacheShadowing() async throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent("models/openai/whisper-tiny"), withIntermediateDirectories: true)
        do {
            try await ASRTokenizerPreflight.validate(folder: fixture.root)
            XCTFail("An unverified Hub cache must not shadow the pinned tokenizer")
        } catch { XCTAssertTrue(error is MeetingASRError) }
    }

    func testCatalogPinsAndSizesMatchDescriptors() throws {
        let store = ASRModelStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        for model in MeetingASREngine.models {
            let files = try store.files(for: model.id)
            XCTAssertEqual(files.reduce(Int64(0)) { $0 + $1.bytes }, model.bytes)
            XCTAssertTrue(files.allSatisfy { $0.url.path.contains("/resolve/") })
            XCTAssertFalse(store.installed(model.id))
        }
        XCTAssertThrowsError(try store.files(for: "../base"))
    }

    func testProjectionUsesAbsoluteTimeStableIDsAndNoInventedSpeech() throws {
        let input = [
            TranscriptionSegment(start: 0.5, end: 1.5, text: " hello "),
            TranscriptionSegment(start: 2, end: 3, text: "..."),
            TranscriptionSegment(start: 4, end: 5, text: "hallucination", avgLogprob: -2, noSpeechProb: 0.9),
            TranscriptionSegment(start: 6, end: 7, text: "你好"),
        ]
        let segments = try ASRSegmentProjection.project(input, chunk: 2, duration: 60)
        XCTAssertEqual(segments.map(\.text), ["hello", "你好"])
        XCTAssertEqual(segments.map(\.id), ["chunk-2-segment-0", "chunk-2-segment-3"])
        XCTAssertEqual(segments[0].start, 120.5)
        XCTAssertEqual(segments[1].end, 127)
        XCTAssertThrowsError(try ASRSegmentProjection.project([.init(start: .nan, end: 1, text: "bad")], chunk: 0, duration: 2))
        XCTAssertThrowsError(try ASRSegmentProjection.project([.init(start: 0, end: 100, text: "bad")], chunk: 0, duration: 60))
    }

    func testProjectionClipsWhisperPaddedWindowEndsWithoutLosingSpeech() throws {
        // Observed on the real 75-minute MP4: a 60s input returned end=60.3199997.
        let segments = try ASRSegmentProjection.project([
            .init(start: 56.32, end: 60.32, text: "句子跨越模型窗口边界"),
            .init(start: 60.32, end: 61, text: "仅在补零区的文本")
        ], chunk: 2, duration: 60)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.text, "句子跨越模型窗口边界")
        XCTAssertEqual(segments.first?.end, 180)
        let tail = try ASRSegmentProjection.project([.init(start: 27.9, end: 31.22, text: "最后一句")], chunk: 75, duration: 30.73)
        XCTAssertEqual(tail.first!.end, 4530.73, accuracy: 0.0001)
    }

    func testProjectionStillRejectsMalformedTimesAndWindows() throws {
        for input in [TranscriptionSegment(start: .infinity, end: 1, text: "bad"), .init(start: 5, end: 4, text: "bad"), .init(start: -3, end: 2, text: "bad")] {
            XCTAssertThrowsError(try ASRSegmentProjection.project([input], chunk: 0, duration: 60))
        }
    }

    func testInstallerVerifiesAndPreservesExistingFiles() async throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let store = try fixture.store()
        let untouched = fixture.root.appendingPathComponent(".assembly-other-task")
        try Data("keep".utf8).write(to: untouched)
        try await store.download("tiny") { _ in }
        XCTAssertTrue(store.installed("tiny"))
        try store.validate("tiny")
        XCTAssertEqual(try Data(contentsOf: untouched), Data("keep".utf8))
        // Same-size damage is detected by full pre-inference validation.
        try Data("wrong".utf8).write(to: store.folder(for: "tiny").appendingPathComponent("weights.bin"))
        XCTAssertThrowsError(try store.validate("tiny"))
        try await store.download("tiny") { _ in }
        try store.validate("tiny")
        let backups = try FileManager.default.contentsOfDirectory(at: fixture.root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(".previous-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: backups[0].appendingPathComponent("weights.bin")), Data("wrong".utf8))
    }

    func testFailedDownloadNeverPublishesOrSweepsOtherStaging() async throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let store = try fixture.store(corrupt: true)
        let unrelated = fixture.root.appendingPathComponent(".assembly-other")
        try Data("keep".utf8).write(to: unrelated)
        do { try await store.download("tiny") { _ in }; XCTFail("Expected integrity failure") }
        catch { XCTAssertTrue(error is MeetingASRError) }
        XCTAssertFalse(store.installed("tiny"))
        let names = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
        XCTAssertEqual(names, [".assembly-other"])
    }

    func testInstalledRejectsIntermediateSymlinks() async throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let store = try fixture.store()
        try await store.download("tiny") { _ in }
        let relocated = fixture.base.appendingPathComponent("relocated")
        try FileManager.default.moveItem(at: store.folder(for: "tiny"), to: relocated)
        try FileManager.default.createSymbolicLink(at: store.folder(for: "tiny"), withDestinationURL: relocated)
        XCTAssertFalse(store.installed("tiny"))
    }

    func testPermitSerializesAcrossAwaitAndQueuedCancellation() async throws {
        let permit = ASROperationPermit()
        let gate = Gate()
        let first = Task {
            try await permit.run { await gate.enter(); await gate.wait() }
        }
        await gate.waitUntilEntered()
        let second = Task { try await permit.run { XCTFail("Cancelled waiter must never run") } }
        second.cancel()
        do { try await second.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        let third = Task { try await permit.run { await gate.markThird() } }
        for _ in 0..<20 { await Task.yield() }
        let enteredEarly = await gate.third
        XCTAssertFalse(enteredEarly)
        await gate.release()
        try await first.value; try await third.value
        let enteredFinally = await gate.third
        XCTAssertTrue(enteredFinally)
    }
}

private struct Fixture {
    let base: URL
    let root: URL
    init() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("companion-asr-test-\(UUID())", isDirectory: true)
        root = base.appendingPathComponent("models", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: base) }
    func store(corrupt: Bool = false) throws -> ASRModelStore {
        let data = Data("hello".utf8)
        let file = ASRModelFile(path: "weights.bin", url: URL(string: "https://huggingface.co/test/resolve/pin/weights.bin")!, bytes: 5,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), gitSHA1: nil)
        let catalog = base.appendingPathComponent("catalog.json")
        try JSONEncoder().encode(["tiny": [file]]).write(to: catalog)
        return ASRModelStore(root: root, catalogURL: catalog, requiredPaths: ["weights.bin"]) { request, progress in
            let temp = base.appendingPathComponent(UUID().uuidString)
            try (corrupt ? Data("wrong".utf8) : data).write(to: temp)
            await progress(5)
            return (temp, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }
}

private actor Gate {
    private var entered = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var released = false
    var third = false
    func enter() { entered = true }
    func waitUntilEntered() async { while !entered { await Task.yield() } }
    func wait() async { if !released { await withCheckedContinuation { waiter = $0 } } }
    func release() { released = true; waiter?.resume(); waiter = nil }
    func markThird() { third = true }
}

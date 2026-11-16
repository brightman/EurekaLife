import XCTest
@testable import CompanionSpeakers

private actor FixtureBackend: SpeakerInferenceBackend {
    var loads = 0, unloads = 0, lengths: [Int] = [], extractionLengths: [Int] = []
    let invalidFeatures: Bool
    let turns: [SpeakerLocalTurn]
    init(invalidFeatures: Bool = false, turns: [SpeakerLocalTurn] = [.init(start: 0, end: 8, speakerID: "a"), .init(start: 3, end: 6, speakerID: "b")]) {
        self.invalidFeatures = invalidFeatures; self.turns = turns
    }
    func load() { loads += 1 }
    func unload() { unloads += 1 }
    func diarize(_ samples: [Float]) -> [SpeakerLocalTurn] {
        lengths.append(samples.count)
        return turns
    }
    func extract(_ samples: [Float]) throws -> [Float] {
        extractionLengths.append(samples.count)
        if invalidFeatures { throw MeetingSpeakerError.invalidFeature }
        var vector = [Float](repeating: 0, count: 256); vector[0] = 1
        return vector
    }
    func counts() -> (Int, Int, [Int], [Int]) { (loads, unloads, lengths, extractionLengths) }
}

private actor FixtureEvents {
    var events: [String] = []
    var outputs: [SpeakerWindowOutput] = []
    var reads: [(Double, Double)] = []
    func add(_ value: String) { events.append(value) }
    func save(_ value: SpeakerWindowOutput) { outputs.append(value) }
    func read(_ start: Double, _ length: Double) { reads.append((start, length)) }
    func snapshot() -> ([String], [SpeakerWindowOutput], [(Double, Double)]) { (events, outputs, reads) }
}

private actor FixtureLatch {
    private var open = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() { open = true; let pending = waiters; waiters = []; for waiter in pending { waiter.resume() } }
}

final class SpeakerRunnerTests: XCTestCase {
    func testContextOnlyVoiceCannotCreateFeatureWithoutEnoughCoreSpeech() async throws {
        let backend = FixtureBackend(turns: [.init(start: 0, end: 2.03, speakerID: "context-only")])
        let events = FixtureEvents()
        try await SpeakerAnalysisRunner.run(windows: SpeakerWindowPlan.windows(duration: 305, startWindow: 1), duration: 305,
            backend: backend, read: { _, length in [Float](repeating: 0.1, count: Int(length * 16_000)) },
            onWindow: { value, _ in await events.save(value) })
        let state = await events.snapshot(), model = await backend.counts()
        XCTAssertEqual(state.1.first?.turns.count, 1)
        XCTAssertEqual(state.1.first?.features.count, 0)
        XCTAssertTrue(model.3.isEmpty)
    }

    func testInvalidFeatureKeepsTurnsAsUnknownWithoutFailingWindow() async throws {
        let backend = FixtureBackend(invalidFeatures: true), events = FixtureEvents()
        try await SpeakerAnalysisRunner.run(windows: SpeakerWindowPlan.windows(duration: 10, startWindow: 0), duration: 10,
            backend: backend, read: { _, length in [Float](repeating: 0.1, count: Int(length * 16_000)) },
            onWindow: { value, _ in await events.save(value) })
        let state = await events.snapshot()
        XCTAssertEqual(state.1.count, 1)
        XCTAssertEqual(state.1.first?.turns.count, 2)
        XCTAssertEqual(state.1.first?.features.count, 0)
    }

    func testBoundedReadsResumeAndOnlySoloFeatures() async throws {
        let backend = FixtureBackend(), events = FixtureEvents()
        let windows = try SpeakerWindowPlan.windows(duration: 605, startWindow: 1)
        try await SpeakerAnalysisRunner.run(windows: windows, duration: 605, backend: backend,
            read: { start, length in
                await events.read(start, length)
                return [Float](repeating: 0.1, count: Int(ceil(length * 16_000)))
            }, onWindow: { value, _ in await events.save(value) })
        let state = await backend.counts(), snapshot = await events.snapshot()
        XCTAssertEqual(state.0, 1); XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, [304 * 16_000, 7 * 16_000])
        XCTAssertTrue(state.3.allSatisfy { $0 <= 160_000 })
        XCTAssertTrue(snapshot.2.allSatisfy { $0.1 <= 60 })
        XCTAssertEqual(snapshot.2.first?.0, 298)
        XCTAssertEqual(snapshot.1.map(\.index), [1, 2])
        XCTAssertNotNil(snapshot.1[0].features["a"])
        XCTAssertNil(snapshot.1[0].features["b"])
        XCTAssertTrue(snapshot.1[0].turns.contains { $0.speakerID == "b" })
    }

    func testCallbackFailureUnloadsAndShortDecodeDoesNotShiftTimeline() async throws {
        let backend = FixtureBackend()
        let windows = try SpeakerWindowPlan.windows(duration: 10, startWindow: 0)
        do {
            try await SpeakerAnalysisRunner.run(windows: windows, duration: 10, backend: backend,
                read: { _, length in [Float](repeating: 0.1, count: Int(length * 16_000)) },
                onWindow: { _, _ in throw CancellationError() })
            XCTFail("Callback cancellation must propagate")
        } catch is CancellationError {} catch { XCTFail("Unexpected \(error)") }
        let first = await backend.counts(); XCTAssertEqual(first.1, 1)
        do {
            try await SpeakerAnalysisRunner.run(windows: windows, duration: 10, backend: backend,
                read: { _, _ in [Float](repeating: 0.1, count: 1) }, onWindow: { _, _ in XCTFail("No incomplete window") })
            XCTFail("Short audio must fail")
        } catch MeetingSpeakerError.invalidAudio {} catch { XCTFail("Unexpected \(error)") }
        let second = await backend.counts(); XCTAssertEqual(second.1, 2)
    }

    func testCancelledQueuedOperationCannotReleaseActivePermit() async throws {
        let permit = SpeakerOperationPermit(), events = FixtureEvents(), started = FixtureLatch(), hold = FixtureLatch()
        let first = Task {
            try await permit.run {
                await events.add("first-start")
                await started.release()
                await hold.wait()
                await events.add("first-end")
            }
        }
        await started.wait()
        let cancelled = Task { try await permit.run { await events.add("cancelled-ran") } }
        cancelled.cancel()
        let third = Task { try await permit.run { await events.add("third") } }
        do { try await cancelled.value; XCTFail("Queued cancellation must throw") } catch is CancellationError {}
        let before = await events.snapshot(); XCTAssertEqual(before.0, ["first-start"])
        await hold.release()
        try await first.value; try await third.value
        let after = await events.snapshot(); XCTAssertEqual(after.0, ["first-start", "first-end", "third"])
    }

    func testMissingModelAnalysisDoesNotReadAudioOrDownload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let engine = MeetingSpeakerEngine(root: root)
        let installed = try await engine.installed(); XCTAssertFalse(installed)
        do {
            try await engine.analyze(url: root.appendingPathComponent("absent.wav"), startWindow: 0) { _, _ in XCTFail("No result") }
            XCTFail("Missing model must fail")
        } catch MeetingSpeakerError.missingModel {} catch { XCTFail("Unexpected \(error)") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testActiveCancellationWaitsForReadAndUnloadsBeforePermitTransfers() async throws {
        let permit = SpeakerOperationPermit(), backend = FixtureBackend(), events = FixtureEvents()
        let reading = FixtureLatch(), finishRead = FixtureLatch()
        let windows = try SpeakerWindowPlan.windows(duration: 10, startWindow: 0)
        let first = Task {
            try await permit.run {
                try await SpeakerAnalysisRunner.run(windows: windows, duration: 10, backend: backend,
                    read: { _, length in
                        await reading.release()
                        await finishRead.wait()
                        return [Float](repeating: 0.1, count: Int(length * 16_000))
                    }, onWindow: { _, _ in await events.add("unexpected-window") })
            }
        }
        await reading.wait()
        first.cancel()
        let second = Task {
            try await permit.run {
                let counts = await backend.counts()
                XCTAssertEqual(counts.1, 1)
                await events.add("next")
            }
        }
        let before = await backend.counts(); XCTAssertEqual(before.1, 0)
        await finishRead.release()
        do { try await first.value; XCTFail("Cancellation must propagate") } catch is CancellationError {}
        try await second.value
        let after = await events.snapshot(); XCTAssertEqual(after.0, ["next"])
    }
}

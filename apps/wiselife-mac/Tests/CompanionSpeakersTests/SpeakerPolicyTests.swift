import XCTest
@testable import CompanionSpeakers

final class SpeakerPolicyTests: XCTestCase {
    func testLongRecordingWindowsAreBoundedAndResumeUsesAbsoluteTime() throws {
        let windows = try SpeakerWindowPlan.windows(duration: 4_501, startWindow: 1)
        XCTAssertEqual(windows.count, 15)
        XCTAssertEqual(windows[0].index, 1)
        XCTAssertEqual(windows[0].coreStart, 300)
        XCTAssertEqual(windows[0].inputStart, 298)
        XCTAssertEqual(windows[0].inputEnd, 602)
        XCTAssertEqual(windows.last?.coreEnd, 4_501)
        XCTAssertTrue(windows.allSatisfy { $0.inputEnd - $0.inputStart <= 304 })
        XCTAssertThrowsError(try SpeakerWindowPlan.windows(duration: 300, startWindow: 2))
    }

    func testSoloRangesExcludeOverlapAndDuplicateSameSpeakerIsUnioned() {
        let turns: [SpeakerLocalTurn] = [.init(start: 0, end: 8, speakerID: "a"),
            .init(start: 1, end: 5, speakerID: "a"), .init(start: 3, end: 6, speakerID: "b")]
        XCTAssertEqual(SpeakerFeaturePolicy.soloRanges(turns: turns, speakerID: "a", sampleCount: 160_000),
                       [0..<48_000, 96_000..<128_000])
        XCTAssertEqual(SpeakerFeaturePolicy.soloRanges(turns: turns, speakerID: "b", sampleCount: 160_000), [])
    }

    func testFeaturesRejectSilenceShortNonfiniteAndUnstableEvidence() throws {
        XCTAssertFalse(SpeakerFeaturePolicy.usable([Float](repeating: 0, count: 32_000)))
        XCTAssertFalse(SpeakerFeaturePolicy.usable([Float](repeating: 0.1, count: 31_999)))
        XCTAssertFalse(SpeakerFeaturePolicy.usable([Float](repeating: .nan, count: 32_000)))
        XCTAssertThrowsError(try SpeakerFeaturePolicy.normalized([Float](repeating: 0, count: 256)))
        var a = [Float](repeating: 0, count: 256); a[0] = 3; a[1] = 4
        let vector = try SpeakerFeaturePolicy.normalized(a)
        XCTAssertEqual(vector[0], 0.6, accuracy: 0.00001)
        XCTAssertEqual(vector[1], 0.8, accuracy: 0.00001)
        XCTAssertNil(SpeakerFeaturePolicy.consensus([vector, vector.map { -$0 }]))
    }

    func testFeatureWindowsKeepFullContextAndDiscardOnlyShortResidual() {
        let samples = [Float](repeating: 0.1, count: 321_600) // 20.1s with a tiny segmenter tail
        XCTAssertEqual(SpeakerFeaturePolicy.samples(samples, ranges: [0..<samples.count]).map(\.count), [160_000, 160_000])
        XCTAssertEqual(SpeakerFeaturePolicy.samples(Array(samples.prefix(192_000)), ranges: [0..<192_000]).map(\.count), [160_000, 32_000])
        XCTAssertEqual(SpeakerFeaturePolicy.samples(Array(samples.prefix(191_999)), ranges: [0..<191_999]).map(\.count), [160_000])
        let long = [Float](repeating: 0.1, count: 640_000)
        XCTAssertEqual(SpeakerFeaturePolicy.samples(long, ranges: [0..<long.count]).map(\.count), [160_000, 160_000, 160_000])
    }

    func testProjectionClipsCoreButPreservesOverlappingUncertainTurns() throws {
        let window = try XCTUnwrap(SpeakerWindowPlan.windows(duration: 650, startWindow: 1).first)
        let turns: [SpeakerLocalTurn] = [.init(start: 0, end: 5, speakerID: "a"),
            .init(start: 4, end: 8, speakerID: "b"), .init(start: 301, end: 304, speakerID: "a")]
        let result = try window.project(turns)
        XCTAssertEqual(result.map(\.start), [300, 302, 599])
        XCTAssertEqual(result.map(\.end), [303, 306, 600])
    }
}

import XCTest
@testable import MeetingKit

final class MeetingAnalysisTests: XCTestCase {
    func testTimestampToleratesInvalidAndExtremeStoredValues() {
        XCTAssertEqual(MeetingAnalysis.timestamp(-1), "00:00:00")
        XCTAssertEqual(MeetingAnalysis.timestamp(.infinity), "00:00:00")
        XCTAssertEqual(MeetingAnalysis.timestamp(3661), "01:01:01")
        XCTAssertFalse(MeetingAnalysis.timestamp(Double.greatestFiniteMagnitude).isEmpty)
    }
    func testUnreadableAnalysisCannotBeOverwrittenByRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), id = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent(id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("analysis.json"), original = Data("{unreadable prior result".utf8)
        try original.write(to: url)
        let store = try MeetingAnalysisStore(root: root)
        do { _ = try await store.load(id: id); XCTFail("Corruption accepted") } catch { }
        do { try await store.save(MeetingAnalysis(), for: id); XCTFail("Corrupt file overwritten") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testAnalysisPersistsAndRecoversWithoutLosingCompletedWork() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try MeetingAnalysisStore(root: root), id = UUID()
        var value = MeetingAnalysis()
        value.state = .summarizing
        value.segments = [.init(id: "0-0", start: 1, end: 4, text: "确定下周开会。")]
        value.summary = "上次已确认的总结"
        value.completedChunks = 1
        try await store.save(value, for: id)
        let loaded = try await store.load(id: id, recoverInterrupted: true)
        XCTAssertEqual(loaded?.state, .interrupted)
        XCTAssertEqual(loaded?.segments, value.segments)
        XCTAssertEqual(loaded?.summary, value.summary)
        XCTAssertEqual(loaded?.completedChunks, 1)
        let missing = try await store.load(id: UUID())
        XCTAssertNil(missing)
    }
    func testSummaryChunksRetainAllTextAndRespectByteBudget() throws {
        let text = String(repeating: "会议记录🙂中文\n", count: 1600)
        let chunks = MeetingTextChunks.split(text, maximumBytes: 5000)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.joined(), text)
        XCTAssertTrue(chunks.allSatisfy { $0.utf8.count <= 5000 })
    }
    func testReaderRejectsUnboundedWindowsBeforeReadingFile() async throws {
        let url = URL(fileURLWithPath: "/does-not-exist")
        for duration in [0.0, 61.0, Double.infinity] {
            do { _ = try await MeetingAudioReader.samples(url, start: 0, duration: duration); XCTFail("Unbounded window accepted") }
            catch let error as MeetingFailure { XCTAssertTrue(error.localizedDescription.contains("60")) }
        }
    }
}

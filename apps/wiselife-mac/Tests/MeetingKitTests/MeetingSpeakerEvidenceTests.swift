import XCTest
@testable import MeetingKit

final class MeetingSpeakerEvidenceTests: XCTestCase {
    func testNamedQuestionUsesCurrentNamesAndMatchingOriginalRows() {
        let rows = [MeetingTranscriptSegment(id: "a", start: 1, end: 4, text: "确定周五交付"), .init(id: "b", start: 5, end: 8, text: "讨论天气")]
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "test")
        checkpoint.turns = [.init(start: 1, end: 4, speakerID: "speaker-1"), .init(start: 5, end: 8, speakerID: "speaker-2")]
        var result = MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: rows, previousNames: ["旧名字"])
        result.names = ["speaker-1": "主持人", "speaker-2": "嘉宾"]
        let value = MeetingSpeakerEvidence.make(segments: rows, result: result, question: "主持人说了什么？", maximumBytes: 4200)
        XCTAssertTrue(value.text.contains("主持人：确定周五交付"))
        XCTAssertFalse(value.text.contains("讨论天气"))
        XCTAssertFalse(value.text.contains("旧名字"))
        XCTAssertTrue(value.scope.contains("选段"))
    }
    func testBoundedEvidenceDoesNotPretendToBeTheFullMeeting() {
        let rows = (0..<100).map { MeetingTranscriptSegment(id: "\($0)", start: Double($0 * 10), end: Double($0 * 10 + 5), text: String(repeating: "中文会议资料", count: 70)) }
        let result = MeetingSpeakerSnapshot(checkpoint: .init(fingerprint: "test"), segments: rows)
        let value = MeetingSpeakerEvidence.make(segments: rows, result: result, question: "讨论了哪些事情", maximumBytes: 1600)
        XCTAssertLessThanOrEqual(value.text.utf8.count, 1600)
        XCTAssertTrue(value.text.contains("未确定"))
        XCTAssertTrue(value.scope.contains("不能代表全部发言"))
    }
    func testSpeakerTenDoesNotMatchSpeakerOnePrefix() {
        let rows = [MeetingTranscriptSegment(id: "a", start: 1, end: 4, text: "第一个人的内容"), .init(id: "b", start: 5, end: 8, text: "第十个人的内容")]
        var checkpoint = MeetingSpeakerCheckpoint(fingerprint: "test")
        checkpoint.turns = [.init(start: 1, end: 4, speakerID: "speaker-1"), .init(start: 5, end: 8, speakerID: "speaker-10")]
        let result = MeetingSpeakerSnapshot(checkpoint: checkpoint, segments: rows)
        let value = MeetingSpeakerEvidence.make(segments: rows, result: result, question: "说话人10说了什么？")
        XCTAssertTrue(value.text.contains("第十个人的内容"))
        XCTAssertFalse(value.text.contains("第一个人的内容"))
    }

}

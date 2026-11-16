import XCTest
@testable import MeetingKit

final class MeetingStoreTests: XCTestCase {
    func testDurabilityAndInterruptedRecoveryPreserveMedia() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try MeetingStore(root: root)
        let original = MeetingRecord(title: "Synthetic meeting", options: .init(mode: .screen, microphone: false, systemAudio: true))
        try await store.save(original)
        let media = await store.mediaURL(for: original)
        try Data([1, 2, 3]).write(to: media)
        let reloaded = try MeetingStore(root: root)
        let records = try await reloaded.load(recoverInterrupted: true)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].state, .interrupted)
        XCTAssertEqual(try Data(contentsOf: media), Data([1, 2, 3]))
        var saved = records[0]; saved.state = .saved; saved.duration = 12
        try await reloaded.save(saved)
        let final = try await store.load(recoverInterrupted: true)
        XCTAssertEqual(final[0].state, .saved)
        XCTAssertEqual(final[0].duration, 12)
    }
    func testCorruptMetadataDoesNotHideOtherMeetings() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try MeetingStore(root: root)
        let first = MeetingRecord(title: "Good", options: .init())
        try await store.save(first)
        let bad = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: bad, withIntermediateDirectories: true)
        try Data("not JSON".utf8).write(to: bad.appendingPathComponent("meeting.json"))
        let records = try await store.load(recoverInterrupted: true)
        XCTAssertEqual(records.map(\.id), [first.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: bad.path))
    }
    func testDimensionsAreEvenBoundedAndPreserveAspect() {
        let result = CaptureGeometry.dimensions(width: 6016, height: 3384)
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
        XCTAssertEqual(CaptureGeometry.dimensions(width: 0, height: 0).width, 2)
        XCTAssertEqual(CaptureGeometry.dimensions(width: 901, height: 1501).width % 2, 0)
    }
    func testInvalidMediaIsNotSaved() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([1,2,3]).write(to: url)
        do { _ = try await MeetingMedia.inspect(url, requireVideo: true); XCTFail("Invalid media accepted") }
        catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
}

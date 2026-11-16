import CryptoKit
import XCTest
@testable import CompanionSpeakers

final class SpeakerStoreTests: XCTestCase {
    private func fixture(_ data: Data, root: URL) throws -> (SpeakerModelStore, URL) {
        let catalog = root.appendingPathComponent("catalog.json")
        let file = SpeakerModelFile(path: "nested/weight.bin", url: URL(string: "https://huggingface.co/test/resolve/pin/weight.bin")!, bytes: Int64(data.count),
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), gitSHA1: nil)
        try JSONEncoder().encode(["fixture": [file]]).write(to: catalog)
        let store = SpeakerModelStore(root: root.appendingPathComponent("models"), catalogURLs: [catalog], requiredPaths: [file.path], downloadFile: { request, report in
            let temporary = root.appendingPathComponent(UUID().uuidString)
            try data.write(to: temporary)
            await report(Int64(data.count))
            return (temporary, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        return (store, catalog)
    }

    func testInstalledVerificationDetectsSameSizeMutationAndIntermediateSymlink() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, _) = try fixture(Data("clean".utf8), root: root)
        XCTAssertFalse(try store.installed())
        try await store.download { _ in }
        XCTAssertTrue(try store.installed())
        let file = store.folder.appendingPathComponent("nested/weight.bin")
        try Data("dirty".utf8).write(to: file)
        XCTAssertFalse(try store.installed())
        try Data("clean".utf8).write(to: file)
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.moveItem(at: file.deletingLastPathComponent(), to: outside)
        try FileManager.default.createSymbolicLink(at: file.deletingLastPathComponent(), withDestinationURL: outside)
        XCTAssertFalse(try store.installed())
    }

    func testFailedReplacementKeepsOldInstallation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, catalog) = try fixture(Data("clean".utf8), root: root)
        try await store.download { _ in }
        let before = try Data(contentsOf: store.folder.appendingPathComponent("nested/weight.bin"))
        var records = try JSONDecoder().decode([String: [SpeakerModelFile]].self, from: Data(contentsOf: catalog))
        let previous = records["fixture"]![0]
        records["fixture"] = [.init(path: previous.path, url: previous.url, bytes: previous.bytes, sha256: String(repeating: "0", count: 64), gitSHA1: nil)]
        try JSONEncoder().encode(records).write(to: catalog)
        do { try await store.download { _ in }; XCTFail("Bad hash must fail") } catch {}
        XCTAssertEqual(try Data(contentsOf: store.folder.appendingPathComponent("nested/weight.bin")), before)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: store.root.path).contains { $0.hasPrefix(".assembly") })
    }

    func testCatalogRejectsTraversalAndPinnedResourcesHaveExpectedSize() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, catalog) = try fixture(Data("clean".utf8), root: root)
        let text = try String(contentsOf: catalog, encoding: .utf8).replacingOccurrences(of: "nested", with: "..")
        try text.write(to: catalog, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try store.files())
        XCTAssertEqual(try SpeakerModelStore(root: root).files().reduce(Int64(0)) { $0 + $1.bytes }, MeetingSpeakerEngine.modelBytes)
    }

    func testSuccessfulReplacementRetainsOldBundleAndCancelledReplacementDoesNotPromote() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let (first, _) = try fixture(Data("first".utf8), root: root)
        try await first.download { _ in }
        let (second, catalog) = try fixture(Data("later".utf8), root: root)
        try await second.download { _ in }
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: second.root, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix(".previous-") })
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("nested/weight.bin")), Data("first".utf8))
        _ = try fixture(Data("third".utf8), root: root)
        let cancelled = SpeakerModelStore(root: second.root, catalogURLs: [catalog], requiredPaths: ["nested/weight.bin"], downloadFile: { _, _ in throw CancellationError() })
        do { try await cancelled.download { _ in }; XCTFail("Must cancel") } catch is CancellationError {}
        XCTAssertEqual(try Data(contentsOf: second.folder.appendingPathComponent("nested/weight.bin")), Data("later".utf8))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: second.root.path).contains { $0.hasPrefix(".assembly-") })
    }

    func testGitBlobChecksumAndUnexpectedModelFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("clean".utf8)
        let (store, catalog) = try fixture(data, root: root)
        let prior = try store.files()[0]
        let checksum = Insecure.SHA1.hash(data: Data("blob 5\0".utf8) + data).map { String(format: "%02x", $0) }.joined()
        try JSONEncoder().encode(["fixture": [SpeakerModelFile(path: prior.path, url: prior.url, bytes: 5, sha256: nil, gitSHA1: checksum)]]).write(to: catalog)
        try await store.download { _ in }
        XCTAssertTrue(try store.installed())
        try data.write(to: store.folder.appendingPathComponent("unexpected.mlmodel"))
        XCTAssertFalse(try store.installed())
    }
}

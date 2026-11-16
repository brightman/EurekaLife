import XCTest
@testable import CompanionCore
final class LocalMeetingRuntimeTests: XCTestCase {
    func testLocalWorkWorksWithLANPausedAndSurvivesRemotePause() async throws {
        let engine = StubEngine(delay: .milliseconds(60)), runtime = try await readyRuntime(engine: engine)
        let request = TextRequest(model: "test-model", system: "s", user: "local")
        await runtime.suspend()
        do { _ = try await runtime.generate(request, device: UUID()); XCTFail("Remote admission while paused") } catch { }
        let local = Task { try await runtime.generateLocal(request) }
        try await waitUntil { await runtime.snapshot().active }
        await runtime.suspend()
        let result = try await local.value
        XCTAssertFalse(result.text.isEmpty)
        await runtime.shutdown()
    }
    func testLocalAndRemoteShareOneEngineAndShutdownCancelsBoth() async throws {
        let engine = StubEngine(delay: .seconds(2)), runtime = try await readyRuntime(engine: engine)
        let request = TextRequest(model: "test-model", system: "s", user: "u")
        let remote = Task { try await runtime.generate(request, device: UUID()) }
        try await waitUntil { await runtime.snapshot().active }
        let local = Task { try await runtime.generateLocal(request) }
        try await waitUntil { await runtime.snapshot().queued == 1 }
        await runtime.suspend()
        do { _ = try await remote.value; XCTFail("Remote was not cancelled") } catch { }
        try await waitUntil { await engine.calls.count == 2 }
        await runtime.shutdown()
        do { _ = try await local.value; XCTFail("Shutdown did not cancel local") } catch { }
        let maximum = await engine.maximumActive
        XCTAssertEqual(maximum, 1)
    }
}

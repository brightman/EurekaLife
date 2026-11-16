import XCTest
@testable import CompanionCore
@testable import MeetingKit

private actor AdmissionLatch {
    private var opened = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { waiting.append($0) }
    }
    func open() { opened = true; let pending = waiting; waiting.removeAll(); pending.forEach { $0.resume() } }
}
private actor AdmissionEngine: TextEngine {
    var calls: [String] = []
    var unloadLatch: AdmissionLatch?
    func blockUnload(_ latch: AdmissionLatch) { unloadLatch = latch }
    func load(directory: URL) async throws { calls.append("load") }
    func unload() async {
        calls.append("unload-start")
        if let unloadLatch { await unloadLatch.wait() }
        calls.append("unload-end")
    }
    func generate(_ request: TextRequest, contextLimit: Int) async throws -> GenerationResult {
        calls.append("generate")
        return .init(text: "synthetic", promptTokens: 1, generatedTokens: 1, firstTokenSeconds: 0, totalSeconds: 0, finishReason: "stop")
    }
}
private actor AdmissionMarker {
    var entered = false
    func enter() { entered = true }
}
final class SharedInferenceAdmissionTests: XCTestCase {
    private func blockSharedGate() async throws -> (AdmissionLatch, Task<Void, Error>) {
        let latch = AdmissionLatch(), marker = AdmissionMarker()
        let holder = Task { try await MeetingInferenceGate.shared.run { await marker.enter(); await latch.wait() } }
        try await waitUntil { await marker.entered }
        return (latch, holder)
    }
    func testModelLoadAndItsPrecedingUnloadWaitForOtherInference() async throws {
        let engine = AdmissionEngine(), runtime = ModelRuntime(engine: engine)
        let (latch, holder) = try await blockSharedGate()
        let loading = Task { try await runtime.load("test-model", directory: URL(fileURLWithPath: "/synthetic")) }
        try await waitUntil {
            let queued = await MeetingInferenceGate.shared.waiters.count, calls = await engine.calls
            return queued > 0 || !calls.isEmpty
        }
        let beforeRelease = await engine.calls
        XCTAssertTrue(beforeRelease.isEmpty, "Neither unloading nor loading may overlap another inference engine")
        await latch.open(); try await holder.value; try await loading.value
        let calls = await engine.calls
        XCTAssertEqual(calls, ["unload-start", "unload-end", "load"])
        await runtime.shutdown()
    }
    func testGenerationQueuedBehindOtherInferenceCancelsWithoutCallingEngine() async throws {
        let engine = AdmissionEngine(), runtime = ModelRuntime(engine: engine)
        try await runtime.load("test-model", directory: URL(fileURLWithPath: "/synthetic"))
        let (latch, holder) = try await blockSharedGate()
        let generation = Task { try await runtime.generateLocal(.init(model: "test-model", system: "s", user: "u")) }
        try await waitUntil {
            let queued = await MeetingInferenceGate.shared.waiters.count, calls = await engine.calls
            return queued > 0 || calls.contains("generate")
        }
        let beforeCancel = await engine.calls
        XCTAssertFalse(beforeCancel.contains("generate"))
        generation.cancel()
        do { _ = try await generation.value; XCTFail("Generation escaped cancellation") }
        catch { XCTAssertEqual(error as? ServiceError, .cancelled) }
        let afterCancel = await engine.calls
        XCTAssertFalse(afterCancel.contains("generate"))
        await latch.open(); try await holder.value
        await runtime.shutdown()
    }
    func testUnloadWaitsForAdmissionAndRetainsPermitThroughNativeCleanup() async throws {
        let engine = AdmissionEngine(), runtime = ModelRuntime(engine: engine)
        try await runtime.load("test-model", directory: URL(fileURLWithPath: "/synthetic"))
        let nativeCleanup = AdmissionLatch()
        await engine.blockUnload(nativeCleanup)
        let (latch, holder) = try await blockSharedGate()
        let unloading = Task { await runtime.unload() }
        try await waitUntil {
            let queued = await MeetingInferenceGate.shared.waiters.count, calls = await engine.calls
            return queued > 0 || calls.count > 3
        }
        let beforeRelease = await engine.calls
        XCTAssertEqual(beforeRelease, ["unload-start", "unload-end", "load"])
        await latch.open(); try await holder.value
        try await waitUntil { await engine.calls.count == 4 }
        let marker = AdmissionMarker()
        let next = Task { try await MeetingInferenceGate.shared.run { await marker.enter() } }
        try await waitUntil {
            let queued = await MeetingInferenceGate.shared.waiters.count, entered = await marker.entered
            return queued > 0 || entered
        }
        let beforeCleanup = await marker.entered
        XCTAssertFalse(beforeCleanup, "Native unload must finish before the next model begins")
        await nativeCleanup.open(); await unloading.value; try await next.value
        let calls = await engine.calls, state = await runtime.snapshot().state
        XCTAssertEqual(calls, ["unload-start", "unload-end", "load", "unload-start", "unload-end"])
        XCTAssertEqual(state, .unloaded)
    }
}

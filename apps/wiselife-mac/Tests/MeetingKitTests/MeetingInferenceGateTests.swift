import XCTest
@testable import MeetingKit

private actor InferenceGateLatch {
    private var open = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { continuations.append($0) }
    }
    func release() {
        open = true
        let pending = continuations; continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
private actor InferenceGateTrace {
    var calls: [Int] = []
    var active = 0
    var maximumActive = 0
    func begin(_ id: Int) { calls.append(id); active += 1; maximumActive = max(maximumActive, active) }
    func end() { active -= 1 }
}
final class MeetingInferenceGateTests: XCTestCase {
    private func waitUntil(_ predicate: @escaping () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !(await predicate()) {
            if ContinuousClock.now >= deadline { throw NSError(domain: "MeetingInferenceGateTests.timeout", code: 1) }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    func testOperationsHoldPermitAcrossSuspensionAndRunFIFO() async throws {
        let gate = MeetingInferenceGate(), latch = InferenceGateLatch(), trace = InferenceGateTrace()
        let first = Task { try await gate.run { await trace.begin(1); await latch.wait(); await trace.end(); return 1 } }
        try await waitUntil { await trace.calls == [1] }
        let second = Task { try await gate.run { await trace.begin(2); await Task.yield(); await trace.end(); return 2 } }
        try await waitUntil { await gate.waiters.count == 1 }
        let third = Task { try await gate.run { await trace.begin(3); await Task.yield(); await trace.end(); return 3 } }
        try await waitUntil { await gate.waiters.count == 2 }
        let duringFirst = await trace.calls
        XCTAssertEqual(duringFirst, [1])
        await latch.release()
        let results = try await [first.value, second.value, third.value]
        XCTAssertEqual(results, [1, 2, 3])
        let calls = await trace.calls, maximum = await trace.maximumActive
        XCTAssertEqual(calls, [1, 2, 3]); XCTAssertEqual(maximum, 1)
    }
    func testCancelledQueuedWaiterExitsBeforeActiveWorkAndNeverExecutes() async throws {
        let gate = MeetingInferenceGate(), latch = InferenceGateLatch(), trace = InferenceGateTrace()
        let first = Task { try await gate.run { await trace.begin(1); await latch.wait(); await trace.end() } }
        try await waitUntil { await trace.calls == [1] }
        let cancelled = Task { try await gate.run { await trace.begin(2); await trace.end() } }
        try await waitUntil { await gate.waiters.count == 1 }
        let next = Task { try await gate.run { await trace.begin(3); await trace.end() } }
        try await waitUntil { await gate.waiters.count == 2 }
        cancelled.cancel()
        do { try await cancelled.value; XCTFail("Queued operation was not cancelled") } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        let remaining = await gate.waiters.count, callsBeforeRelease = await trace.calls
        XCTAssertEqual(remaining, 1); XCTAssertEqual(callsBeforeRelease, [1])
        await latch.release(); try await first.value; try await next.value
        let calls = await trace.calls
        XCTAssertEqual(calls, [1, 3])
    }
    func testActiveCancellationDoesNotReleaseUntilOperationExits() async throws {
        let gate = MeetingInferenceGate(), latch = InferenceGateLatch(), trace = InferenceGateTrace()
        let first = Task { try await gate.run {
            await trace.begin(1)
            await latch.wait() // Simulates native work that cannot finish immediately on cancellation.
            await trace.end()
            try Task.checkCancellation()
        } }
        try await waitUntil { await trace.calls == [1] }
        let next = Task { try await gate.run { await trace.begin(2); await trace.end() } }
        try await waitUntil { await gate.waiters.count == 1 }
        first.cancel()
        for _ in 0..<20 { await Task.yield() }
        let beforeExit = await trace.calls, queued = await gate.waiters.count
        XCTAssertEqual(beforeExit, [1]); XCTAssertEqual(queued, 1)
        await latch.release()
        do { try await first.value; XCTFail("Active cancellation lost") } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        try await next.value
        let calls = await trace.calls, maximum = await trace.maximumActive
        XCTAssertEqual(calls, [1, 2]); XCTAssertEqual(maximum, 1)
    }
}

import Foundation

/// Shared admission for heavyweight local inference. This gate is deliberately non-reentrant:
/// an operation must not call another operation that acquires the same gate.
public actor MeetingInferenceGate {
    public static let shared = MeetingInferenceGate()

    struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }
    private var active: UUID?
    private(set) var waiters: [Waiter] = []

    public init() {}

    /// Holds its permit across every suspension until the supplied operation actually exits.
    /// Cancelling active native work never permits a second model to start prematurely.
    public func run<T: Sendable>(operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await acquire(id)
            defer { release(id) }
            // Handles cancellation racing with a queued waiter receiving the permit.
            try Task.checkCancellation()
            let result = try await operation()
            try Task.checkCancellation()
            return result
        } onCancel: {
            Task { await self.cancelWaiting(id) }
        }
    }

    private func acquire(_ id: UUID) async throws {
        try Task.checkCancellation()
        if active == nil {
            active = id
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            waiters.append(Waiter(id: id, continuation: continuation))
        }
    }

    private func cancelWaiting(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func release(_ id: UUID) {
        guard active == id else { return }
        if waiters.isEmpty {
            active = nil
        } else {
            let next = waiters.removeFirst()
            active = next.id
            next.continuation.resume()
        }
    }
}

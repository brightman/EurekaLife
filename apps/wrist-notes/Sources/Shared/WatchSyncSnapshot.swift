import Foundation

/// Live view of WatchConnectivity's outstanding file jobs.
/// `isTransferring` is distinct from a job merely waiting in the system queue.
struct WatchFileTransferStatus: Equatable {
    let outstandingCount: Int
    let transferringCount: Int
    var queuedCount: Int { max(0, outstandingCount - transferringCount) }
    var isTransferring: Bool { transferringCount > 0 }

    init(outstandingCount: Int, transferringCount: Int) {
        self.outstandingCount = max(0, outstandingCount)
        self.transferringCount = min(self.outstandingCount, max(0, transferringCount))
    }
}

/// Latest known queue, delivered through background application context (not reachability).
struct WatchSyncSnapshot: Codable, Equatable {
    static let contextKey = "wiseLifeWatchSyncV1"
    let updatedAt: Date
    let pendingIDs: [UUID]
    var failures: [WatchSyncFailure]? = nil
    var lastHandledRetryID: UUID? = nil
    var retention: WatchRetentionReport? = nil
    var retentionReceiptIDs: [UUID]? = nil

    static func decode(_ context: [String: Any]) -> WatchSyncSnapshot? {
        guard let data = context[contextKey] as? Data,
              let snapshot = try? JSONDecoder().decode(Self.self, from: data),
              snapshot.updatedAt.timeIntervalSinceReferenceDate.isFinite else { return nil }
        return snapshot
    }
}

struct WatchSyncFailure: Codable, Equatable {
    enum Reason: String, Codable { case transferFailed, fileMissing }
    let id: UUID
    let reason: Reason
}

/// Background context is retained by the OS; consume each request once and expire old intent.
struct WatchSyncRetryRequest: Codable, Equatable {
    static let contextKey = "wiseLifeWatchRetryV1"
    static let handledKey = "wiseLifeWatchRetryHandledV1"
    let id: UUID
    let requestedAt: Date

    func shouldHandle(lastHandledID: UUID?, now: Date = .now) -> Bool {
        let age = now.timeIntervalSince(requestedAt)
        return id != lastHandledID && age.isFinite && age >= -300 && age <= 86_400
    }

    static func preparingContext(
        _ context: [String: Any], lastHandledID: UUID?, now: Date = .now
    ) throws -> [String: Any] {
        let request: Self
        if let previous = decode(context), previous.shouldHandle(lastHandledID: lastHandledID, now: now) {
            request = previous
        } else {
            request = Self(id: UUID(), requestedAt: now)
        }
        var updated = context
        updated[contextKey] = try JSONEncoder().encode(request)
        return updated
    }

    static func decode(_ context: [String: Any]) -> Self? {
        guard let data = context[contextKey] as? Data else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

/// Additive protocol: old Watch versions ignore the policy and never claim it applied.
struct WatchRetentionPolicy: Codable, Equatable {
    static let contextKey = "wiseLifeWatchRetentionV1"
    let id: UUID
    let deviceID: UUID
    let revision: Int
    let days: Int
    var isValid: Bool { revision > 0 && [7, 14].contains(days) }
    static func decode(_ context: [String: Any]) -> Self? {
        guard let data = context[contextKey] as? Data,
              let policy = try? JSONDecoder().decode(Self.self, from: data), policy.isValid else { return nil }
        return policy
    }
}

struct WatchRetentionEstimate: Codable, Equatable {
    var count = 0
    var bytes: Int64 = 0
}

struct WatchRetentionReport: Codable, Equatable {
    let deviceID: UUID
    let policy: WatchRetentionPolicy?
    let sevenDays: WatchRetentionEstimate
    let fourteenDays: WatchRetentionEstimate
    let awaitingReceiptCount: Int
    var cleanupFailed = false
    func estimate(days: Int) -> WatchRetentionEstimate { days == 14 ? fourteenDays : sevenDays }
}

/// Desired settings are scoped to both the system pairing and this installation of Watch.
final class WatchRetentionSettingsStore {
    private let url: URL
    init(url: URL) { self.url = url }
    private func read() throws -> [String: WatchRetentionPolicy] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: WatchRetentionPolicy].self, from: Data(contentsOf: url))
    }
    func policy(pairingID: String, deviceID: UUID) throws -> WatchRetentionPolicy? {
        let policy = try read()[pairingID]
        return policy?.deviceID == deviceID && policy?.isValid == true ? policy : nil
    }
    func save(days: Int, pairingID: String, report: WatchRetentionReport) throws -> WatchRetentionPolicy {
        guard [7, 14].contains(days) else { throw CocoaError(.fileReadCorruptFile) }
        var values = try read()
        let previous = values[pairingID].flatMap { $0.deviceID == report.deviceID ? $0 : nil }
        let revision = max(previous?.revision ?? 0, report.policy?.revision ?? 0)
        guard revision < Int.max else { throw CocoaError(.fileReadCorruptFile) }
        let policy = WatchRetentionPolicy(id: UUID(), deviceID: report.deviceID, revision: revision + 1, days: days)
        values[pairingID] = policy
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: url, options: .atomic)
        return policy
    }
}

import Foundation

/// Watch-only lifecycle. A durable retirement ledger prevents recovery from reimporting deleted audio.
/// Call on the recorder's serial/main executor; savePending must atomically commit its list.
final class WatchRecordingRetentionStore {
    private struct State: Codable {
        var deviceID = UUID()
        var policy: WatchRetentionPolicy?
        var retired: [String: String] = [:]
        var completed: Set<String> = []
        var lastSyncedAt: Date?
    }
    private let directory: URL
    private let stateURL: URL
    private var state: State
    private(set) var cleanupFailed = false
    var policy: WatchRetentionPolicy? { state.policy }
    var lastSyncedAt: Date? { state.lastSyncedAt }

    init(directory: URL) throws {
        self.directory = directory
        stateURL = directory.appendingPathComponent("retention-state.json")
        if FileManager.default.fileExists(atPath: stateURL.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: stateURL))
        } else {
            state = State()
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
        }
    }

    @discardableResult func apply(_ policy: WatchRetentionPolicy) throws -> Bool {
        guard policy.isValid, policy.deviceID == state.deviceID else { return false }
        if state.policy == policy { return true }
        guard policy.revision > (state.policy?.revision ?? 0) else { return false }
        var updated = state; updated.policy = policy
        try commit(updated)
        return true
    }

    func isRetired(_ id: UUID) -> Bool { state.retired[id.uuidString] != nil }

    static func filename(_ item: PendingRecording) -> String {
        if let groupID = item.recordingGroupID, let ordinal = item.recordingGroupOrdinal {
            return RecordingChunkFileIdentity.filename(groupID: groupID, ordinal: ordinal, capturedAt: item.capturedAt)
        }
        return "\(item.id.uuidString).m4a"
    }

    private func expired(_ item: PendingRecording, days: Int, protectedIDs: Set<UUID>, now: Date) -> Bool {
        guard item.uploaded, let saved = item.uploadedAt, saved.timeIntervalSinceReferenceDate.isFinite,
              !protectedIDs.contains(item.id), !item.awaitingPhoneSaveConfirmation,
              !item.transferFailed, item.duration.isFinite, item.duration > 0 else { return false }
        return now.timeIntervalSince(saved) >= Double(days) * 86_400
    }

    func report(pending: [PendingRecording], protectedIDs: Set<UUID>, now: Date = .now) -> WatchRetentionReport {
        func estimate(_ days: Int) -> WatchRetentionEstimate {
            var result = WatchRetentionEstimate()
            for item in pending where expired(item, days: days, protectedIDs: protectedIDs, now: now) && !isRetired(item.id) {
                let url = directory.appendingPathComponent(Self.filename(item))
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
                      values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                result.count += 1; result.bytes += Int64(values.fileSize ?? 0)
            }
            return result
        }
        return WatchRetentionReport(deviceID: state.deviceID, policy: state.policy,
            sevenDays: estimate(7), fourteenDays: estimate(14),
            awaitingReceiptCount: pending.filter { !$0.uploaded || $0.uploadedAt == nil }.count,
            cleanupFailed: cleanupFailed)
    }

    func clean(pending: [PendingRecording], protectedIDs: Set<UUID>, now: Date = .now,
               savePending: ([PendingRecording]) throws -> Void) throws {
        do {
            var updated = state
            if let latest = pending.compactMap({ $0.uploaded ? $0.uploadedAt : nil }).max(),
               latest > (updated.lastSyncedAt ?? .distantPast) { updated.lastSyncedAt = latest }
            if let policy = state.policy, policy.isValid {
                for item in pending where expired(item, days: policy.days, protectedIDs: protectedIDs, now: now) {
                    updated.retired[item.id.uuidString] = Self.filename(item)
                }
            }
            // Commit intent BEFORE touching audio. A failed write leaves all files untouched.
            if updated.retired != state.retired || updated.lastSyncedAt != state.lastSyncedAt { try commit(updated) }
            let removable = state.retired.filter { key, filename in
                guard !state.completed.contains(key), let id = UUID(uuidString: key), !protectedIDs.contains(id) else { return false }
                return filename == URL(fileURLWithPath: filename).lastPathComponent && filename.hasSuffix(".m4a")
            }
            guard !removable.isEmpty else { cleanupFailed = false; return }
            for (id, filename) in removable {
                let source = directory.appendingPathComponent(filename)
                let staged = directory.appendingPathComponent(".retention-delete-\(id).tmp")
                if FileManager.default.fileExists(atPath: source.path), !FileManager.default.fileExists(atPath: staged.path) {
                    try FileManager.default.moveItem(at: source, to: staged)
                }
            }
            let remaining = pending.filter { removable[$0.id.uuidString] == nil }
            if remaining.count != pending.count { try savePending(remaining) }
            // Only remove staged bytes after the pending list is durably updated.
            for (id, filename) in removable {
                for url in [directory.appendingPathComponent(".retention-delete-\(id).tmp"),
                            directory.appendingPathComponent(filename),
                            directory.appendingPathComponent("\(id).capture.plist")] {
                    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                }
            }
            var finished = state
            finished.completed.formUnion(removable.keys)
            try commit(finished)
            cleanupFailed = false
        } catch {
            cleanupFailed = true
            throw error
        }
    }

    private func commit(_ updated: State) throws {
        try JSONEncoder().encode(updated).write(to: stateURL, options: .atomic)
        state = updated
    }
}

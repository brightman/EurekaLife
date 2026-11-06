import Foundation

@main struct WatchRetentionSmoke {
    static func main() throws {
        func expect(_ value: Bool, _ message: String) { if !value { fatalError(message) } }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSinceReferenceDate: 2_000_000)
        let store = try WatchRecordingRetentionStore(directory: root)
        func item(daysAgo: Double, confirmed: Bool = true, kind: RecordingKind = .long) throws -> PendingRecording {
            var result = PendingRecording(id: UUID(), kind: kind, capturedAt: now.addingTimeInterval(-40 * 86400), duration: 30, uploaded: confirmed)
            result.uploadedAt = confirmed ? now.addingTimeInterval(-daysAgo * 86400) : nil
            try Data(repeating: 1, count: 200).write(to: root.appendingPathComponent("\(result.id.uuidString).m4a"))
            return result
        }
        let old = try item(daysAgo: 8), boundary = try item(daysAgo: 7, kind: .thought)
        let fresh = try item(daysAgo: 6.99), unsent = try item(daysAgo: 99, confirmed: false)
        var legacy = try item(daysAgo: 40); legacy.uploadedAt = nil
        let busy = try item(daysAgo: 20)
        var pending = [old, boundary, fresh, unsent, legacy, busy]
        let protected: Set<UUID> = [busy.id]
        let before = store.report(pending: pending, protectedIDs: protected, now: now)
        expect(before.sevenDays.count == 2 && before.sevenDays.bytes == 400, "preview must include only confirmed expired unoccupied audio")
        expect(before.fourteenDays.count == 0, "14 days must protect the same 8-day recording")
        try store.clean(pending: pending, protectedIDs: protected, now: now) { pending = $0 }
        expect(pending.count == 6, "upgrade without explicit enablement must never delete audio")
        let policy = WatchRetentionPolicy(id: UUID(), deviceID: before.deviceID, revision: 1, days: 7)
        expect(try store.apply(policy), "first approved policy must be persisted")
        expect(!(try store.apply(.init(id: UUID(), deviceID: UUID(), revision: 2, days: 7))), "wrong watch policy must be rejected")
        expect(!(try store.apply(.init(id: UUID(), deviceID: before.deviceID, revision: 2, days: 1))), "unsupported duration must fail closed")
        // Failure of the pending index commit must leave a recoverable cleanup intent.
        enum Failure: Error { case disk }
        do {
            try store.clean(pending: pending, protectedIDs: protected, now: now) { _ in throw Failure.disk }
            fatalError("failed index persistence must surface")
        } catch Failure.disk {}
        let reopened = try WatchRecordingRetentionStore(directory: root)
        try reopened.clean(pending: pending, protectedIDs: protected, now: now) { pending = $0 }
        expect(Set(pending.map(\.id)) == Set([fresh.id, unsent.id, legacy.id, busy.id]), "relaunch must complete only previously authorized expirations")
        expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("\(old.id.uuidString).m4a").path), "expired audio must actually leave disk")
        expect(reopened.isRetired(old.id), "recovery must never resurrect an expired file")
        expect(reopened.lastSyncedAt != nil, "cleanup must preserve last sync after list removal")
        expect(!(try reopened.apply(.init(id: UUID(), deviceID: before.deviceID, revision: 1, days: 14))), "stale or conflicting config must not overwrite current policy")
        try reopened.clean(pending: pending, protectedIDs: protected, now: now) { pending = $0 }
        expect(pending.count == 4, "repeated cleanup must be idempotent")
        expect(try reopened.apply(.init(id: UUID(), deviceID: before.deviceID, revision: 2, days: 14)), "new policy must replace previous revision")
        try reopened.clean(pending: pending, protectedIDs: [], now: now) { pending = $0 }
        expect(!pending.contains { $0.id == busy.id }, "acknowledged file may expire after transfer releases it")
        expect(pending.contains { $0.id == legacy.id } && pending.contains { $0.id == unsent.id }, "unknown receipt time and unuploaded audio must survive every cleanup")
        let legacyData = Data("{\"updatedAt\":1000,\"pendingIDs\":[]}".utf8)
        expect(WatchSyncSnapshot.decode([WatchSyncSnapshot.contextKey: legacyData])?.retention == nil, "legacy sync snapshot must remain readable")
        let preferences = WatchRetentionSettingsStore(url: root.appendingPathComponent("phone/settings.json"))
        let report = reopened.report(pending: pending, protectedIDs: [], now: now)
        let requested = try preferences.save(days: 7, pairingID: "A", report: report)
        expect(requested.revision == 3 && requested != report.policy, "a requested setting must remain distinct from Watch-applied state")
        expect(try preferences.policy(pairingID: "B", deviceID: report.deviceID) == nil, "replacement pairing cannot inherit cleanup permission")
        expect(try preferences.policy(pairingID: "A", deviceID: UUID()) == nil, "reinstalled Watch cannot inherit cleanup permission")
        let savedPreferences = WatchRetentionSettingsStore(url: root.appendingPathComponent("phone/settings.json"))
        expect(try savedPreferences.policy(pairingID: "A", deviceID: report.deviceID) == requested, "pending request must survive phone restart")
        let context: [String: Any] = [WatchRetentionPolicy.contextKey: try JSONEncoder().encode(requested), "location": true]
        expect(WatchRetentionPolicy.decode(context) == requested, "background request roundtrip")
        // A future / rolled-back clock must never age a recording early.
        let future = try item(daysAgo: -1)
        var futurePending = [future]
        try reopened.clean(pending: futurePending, protectedIDs: [], now: now) { futurePending = $0 }
        expect(futurePending.count == 1, "negative elapsed time must preserve audio")
        let groupID = UUID()
        var grouped = PendingRecording(id: RecordingChunkFileIdentity.stableID(groupID: groupID, ordinal: 2), kind: .long,
            capturedAt: now.addingTimeInterval(-20 * 86400), duration: 3600, uploaded: true,
            recordingGroupID: groupID, recordingGroupOrdinal: 2, recordingGroupOffset: 7200)
        grouped.uploadedAt = now.addingTimeInterval(-15 * 86400)
        let groupFile = root.appendingPathComponent(WatchRecordingRetentionStore.filename(grouped))
        try Data(repeating: 2, count: 500).write(to: groupFile)
        var groupedPending = [grouped]
        let indexURL = root.appendingPathComponent("pending.json")
        try JSONEncoder().encode(groupedPending).write(to: indexURL, options: .atomic)
        try reopened.clean(pending: groupedPending, protectedIDs: [], now: now) {
            try JSONEncoder().encode($0).write(to: indexURL, options: .atomic)
            groupedPending = $0
        }
        expect(!FileManager.default.fileExists(atPath: groupFile.path), "grouped long-recording path must be cleaned, not a guessed UUID path")
        let diskIndex = try JSONDecoder().decode([PendingRecording].self, from: Data(contentsOf: indexURL))
        expect(diskIndex.isEmpty, "list removal must be durable")
        // If even the intent cannot be persisted, leave the original bytes untouched.
        let blockedRoot = root.appendingPathComponent("blocked")
        try FileManager.default.createDirectory(at: blockedRoot, withIntermediateDirectories: true)
        let blockedStore = try WatchRecordingRetentionStore(directory: blockedRoot)
        let blockedReport = blockedStore.report(pending: [], protectedIDs: [], now: now)
        try blockedStore.apply(.init(id: UUID(), deviceID: blockedReport.deviceID, revision: 1, days: 7))
        let blockedState = blockedRoot.appendingPathComponent("retention-state.json")
        try FileManager.default.removeItem(at: blockedState)
        try FileManager.default.createDirectory(at: blockedState, withIntermediateDirectories: true)
        let blockedAudio = blockedRoot.appendingPathComponent("\(old.id.uuidString).m4a")
        try Data([1, 2, 3]).write(to: blockedAudio)
        do { try blockedStore.clean(pending: [old], protectedIDs: [], now: now) { _ in fatalError("must not write index without durable intent") }; fatalError("intent persistence must fail") } catch {}
        expect(FileManager.default.fileExists(atPath: blockedAudio.path), "failed intent must preserve original audio")
        // Corrupt retention metadata must disable cleaning, not silently reset policy.
        try Data("broken".utf8).write(to: root.appendingPathComponent("retention-state.json"))
        do { _ = try WatchRecordingRetentionStore(directory: root); fatalError("corrupt ledger must fail closed") } catch {}
        print("Watch retention: boundaries, upgrade, protected files, receipt requirements, crash recovery, policy versions and compatibility passed")
    }
}

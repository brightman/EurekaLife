import Combine
import Foundation

@MainActor final class DaybookRecapModel: ObservableObject {
    struct RemoteRequest: Identifiable {
        let id = UUID()
        let input: DaybookRecapInput
        let configuration: AIConfiguration
        let revision: Int
        let language: String
    }
    private struct Context: Equatable {
        let day: Date
        let recordFingerprint: String
        let configuration: AIConfiguration
        let revision: Int
        let language: String
        var requiresConfirmation: Bool
        let allowedKinds: Set<DayRecord.Kind>
        let foreground: Bool
        let capturing: Bool
        let storageAvailable: Bool
    }
    @Published private(set) var entries: [DaybookRecapEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isGenerating = false
    @Published private(set) var storageError: String?
    @Published private(set) var message: String?
    @Published private(set) var generationProgress: String?
    var scopeLoader: (@MainActor (DateInterval) async throws -> [DayRecord])?
    private let store: DaybookRecapStore
    private let service: any DaybookRecapGenerating
    private let generationTimeout: Duration
    private var context: Context?
    private var settings: AppSettings?
    private var inputs: [String: DaybookRecapInput] = [:]
    private var sourceRecords: [String: [UUID: DayRecord]] = [:]
    private var task: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var epoch = UUID()
    private var generation = UUID()
    private var activeAttempt: DaybookRecapEntry?
    private var archiveRevision = 0
    private var visibleRecords: [DayRecord] = []
    private var fingerprintRecords: [DayRecord] = []

    init(store: DaybookRecapStore = DaybookRecapStore(), service: (any DaybookRecapGenerating)? = nil, generationTimeout: Duration = .seconds(300)) {
        self.store = store; self.service = service ?? DaybookRecapService()
        self.generationTimeout = generationTimeout
    }
    var current: DaybookRecapEntry? { entries.first { $0.dayKey == dayKey } }
    var dayKey: String { context.map { DaybookRecapInput.key($0.day) } ?? "" }
    var input: DaybookRecapInput? { inputs[dayKey] }
    var isStale: Bool { current.map { entry in input.map { entry.relationship(to: $0) != .current } ?? true } ?? false }
    var canGenerate: Bool { storageError == nil && !isLoading && !isGenerating && context?.foreground == true && context?.capturing == false && input?.sources.isEmpty == false }
    func isStale(_ entry: DaybookRecapEntry) -> Bool { inputs[entry.dayKey].map { entry.relationship(to: $0) != .current } ?? true }
    func record(_ id: UUID) -> DayRecord? { sourceRecords[dayKey]?[id] }

    func synchronize(day: Date, records: [DayRecord], revisions: [Int], settings: AppSettings, allowedKinds: Set<DayRecord.Kind>, foreground: Bool, capturing: Bool, storageAvailable: Bool = true) {
        self.settings = settings
        let scope = Calendar.current.dateInterval(of:.day,for:day)!
        let sameVisibleEvidence = records.count == visibleRecords.count && zip(records, visibleRecords).allSatisfy {
            $0.intervals == $1.intervals && $0.recordingSessionID == $1.recordingSessionID
                && $0.contentScope == $1.contentScope && DaybookRecapInput.sameFacts($0, $1)
        }
        let reuseProjection = context?.day == scope.start && context?.allowedKinds == allowedKinds && sameVisibleEvidence
        let relevant = reuseProjection ? fingerprintRecords : DayRecord.evidenceRecords(records,scope:scope).filter { allowedKinds.contains($0.kind) }
        // Global worker revisions include leases, progress and generated titles.
        // Only factual changes may require another dated evidence read. Reuse the
        // fingerprint when its exact input is unchanged; never hash all old and new
        // transcripts merely because a progress notification reached the screen.
        let unchanged = context != nil && relevant.count == fingerprintRecords.count
            && zip(relevant, fingerprintRecords).allSatisfy { DaybookRecapInput.sameFacts($0, $1) }
        let recordFingerprint = unchanged ? context!.recordFingerprint : DaybookRecapInput.digest(relevant.map(DaybookRecapInput.factDigest).sorted())
        fingerprintRecords = relevant
        let next = Context(day: Calendar.current.startOfDay(for: day), recordFingerprint: recordFingerprint,
            configuration: settings.ai, revision: settings.aiRevision, language: settings.interfaceLanguage.rawValue,
            requiresConfirmation: settings.requiresRemoteAIConfirmation, allowedKinds: allowedKinds, foreground: foreground, capturing: capturing,
            storageAvailable: storageAvailable)
        if !storageAvailable {
            cancel(); task?.cancel(); epoch = UUID(); context = next
            entries = []; inputs = [:]; sourceRecords = [:]
            isLoading = false; isRefreshing = false
            storageError = DaybookRecapFailure.storage.localizedDescription
            return
        }
        let previous = context
        let dayChanged = previous?.day != next.day
        // The selected day's UI projection disappears when navigating to another
        // date. That is not a source deletion and must not invalidate its archive.
        let changedIDs = dayChanged ? [] : changedVisibleRecords(from:visibleRecords,to:records,scope:scope)
        visibleRecords = records
        let affected = Set(entries.filter { entry in entry.references.contains { changedIDs.contains($0.id) } }.map(\.dayKey))
        if !affected.isEmpty {
            if let activeAttempt, affected.contains(activeAttempt.dayKey) { cancelGeneration(persistAttempt:false) }
            entries.removeAll { affected.contains($0.dayKey) }
            for key in affected { inputs.removeValue(forKey:key); sourceRecords.removeValue(forKey:key) }
            archiveRevision += 1
        }
        guard context != next || !affected.isEmpty else { return }
        let reset = previous == nil || previous?.day != next.day || previous?.allowedKinds != next.allowedKinds
            || previous?.foreground != next.foreground || previous?.capturing != next.capturing
            || previous?.configuration != next.configuration || previous?.revision != next.revision
            || previous?.language != next.language || previous?.requiresConfirmation != next.requiresConfirmation
        context = next
        if reset { cancel() }
        let resetEvidence = previous == nil || previous?.allowedKinds != next.allowedKinds
        if !dayChanged && previous?.recordFingerprint != next.recordFingerprint {
            inputs.removeValue(forKey:dayKey); sourceRecords.removeValue(forKey:dayKey)
        }
        // Cached civil dates must be reinterpreted after a time-zone change.
        if let cached = input, cached.scope != scope {
            entries.removeAll { $0.dayKey == dayKey }
            inputs.removeValue(forKey:dayKey); sourceRecords.removeValue(forKey:dayKey)
        }
        refresh(preservingExisting: !resetEvidence)
    }
    private func changedVisibleRecords(from old: [DayRecord], to new: [DayRecord], scope: DateInterval) -> Set<UUID> {
        let current = Dictionary(new.map { ($0.id,$0) },uniquingKeysWith:{ _,last in last })
        let rawParents = Set(new.filter { $0.kind == .voice && $0.contentProvenance == nil }.map { $0.recordingSessionID ?? $0.id })
        let derivedParents = Set(new.compactMap { $0.contentProvenance?.sourceID })
        let replacedGroups = Set(old.filter {
            $0.contentProvenance == nil && derivedParents.contains($0.recordingSessionID ?? $0.id)
        }.compactMap(\.recordingGroupID))
        return Set(old.compactMap { record in
            if let next = current[record.id] { return DaybookRecapInput.sameFacts(record, next) ? nil : record.id }
            // A selected-day UI cache can temporarily project the original parent;
            // that is not evidence that one of its persisted children was deleted.
            if let source = record.contentProvenance?.sourceID, rawParents.contains(source) { return nil }
            // Loading this date's segments also hides the original parent and
            // its capture-group siblings in the timeline. Pending siblings are
            // still present in the complete-date evidence loader; validate there
            // without blanking the saved recap merely for this UI replacement.
            if record.kind == .voice, record.contentProvenance == nil,
               derivedParents.contains(record.recordingSessionID ?? record.id)
                || record.recordingGroupID.map(replacedGroups.contains) == true { return nil }
            // A late UI publication can replace the previous date's rows after
            // the selected date has changed. Only compare absence in this date.
            if record.contentProvenance != nil,
               record.recordingProjection(from:scope.start,to:scope.end) == nil { return nil }
            return record.id
        })
    }
    func reload() {
        refresh(preservingExisting:false)
    }
    private func refresh(preservingExisting: Bool) {
        if !preservingExisting { cancel() }
        task?.cancel(); epoch = UUID()
        if !preservingExisting { entries = []; inputs = [:]; sourceRecords = [:]; message = nil }
        storageError = nil
        if let old = context, let settings {
            context = Context(day: old.day, recordFingerprint: old.recordFingerprint,
                configuration: settings.ai, revision: settings.aiRevision, language: settings.interfaceLanguage.rawValue,
                requiresConfirmation: settings.requiresRemoteAIConfirmation, allowedKinds: old.allowedKinds,
                foreground: old.foreground, capturing: old.capturing, storageAvailable: old.storageAvailable)
        }
        guard let context, context.foreground, context.storageAvailable, scopeLoader != nil else { isLoading = false; isRefreshing = false; return }
        message = current?.message
        let token = epoch
        isLoading = input == nil && current?.text == nil; isRefreshing = true
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let savedRevision = archiveRevision
                let saved = try store.load()
                let key = DaybookRecapInput.key(context.day)
                let savedByDay = Dictionary(uniqueKeysWithValues:saved.map { ($0.dayKey,$0) })
                // Publish the selected date first. Unrelated history must neither
                // block it nor erase it when a different date's source read fails.
                let keys = [key] + saved.map(\.dayKey).filter { $0 != key }
                for dateKey in keys {
                    guard let date = DaybookRecapInput.date(for:dateKey),
                          let scope = Calendar.current.dateInterval(of:.day,for:date) else { throw DaybookRecapFailure.storage }
                    if inputs[dateKey]?.scope == scope { continue }
                    do {
                        let records = try await readRecords(scope)
                        try Task.checkCancellation(); guard epoch == token else { return }
                        guard archiveRevision == savedRevision else { refresh(preservingExisting:true); return }
                        let next = DaybookRecapInput.prepare(records:records,day:date,allowedKinds:context.allowedKinds)
                        if var entry = savedByDay[dateKey] {
                            if next.references.isEmpty || entry.relationship(to:next) == .invalid {
                                if activeAttempt?.dayKey == dateKey { cancelGeneration(persistAttempt:false) }
                                let marker = DaybookRecapEntry(input:next)
                                if entry != marker { try store.save(marker) }
                                entry = marker
                            } else {
                                let upgraded = entry.upgradingDigests(to:next)
                                if upgraded != entry { try store.save(upgraded); entry = upgraded }
                            }
                            entries.removeAll { $0.dayKey == dateKey }; entries.append(entry)
                            entries.sort { $0.dayKey > $1.dayKey }
                        }
                        if dateKey == key, isGenerating, let old = input, next.fingerprint != old.fingerprint {
                            cancelGeneration(persistAttempt:false)
                        }
                        inputs[dateKey] = next
                        sourceRecords[dateKey] = Dictionary(records.map { ($0.id,$0) },uniquingKeysWith:{ _,last in last })
                        if dateKey == key { isLoading = false; message = current?.message }
                    } catch {
                        try Task.checkCancellation(); guard epoch == token else { return }
                        entries.removeAll { $0.dayKey == dateKey }
                        inputs.removeValue(forKey:dateKey); sourceRecords.removeValue(forKey:dateKey)
                        if dateKey == key {
                            isLoading = false
                            storageError = (error as? DaybookRecapFailure == .changed ? DaybookRecapFailure.changed : .storage).localizedDescription
                        }
                    }
                }
                isLoading = false; isRefreshing = false; task = nil
                message = current?.message
                if let input, !input.sources.isEmpty, !context.capturing,
                   (!context.configuration.isRemote || !context.requiresConfirmation),
                   current == nil {
                    startGeneration(automatic: true)
                }
            } catch {
                guard epoch == token else { return }
                isLoading = false; isRefreshing = false; task = nil
                if !(error is CancellationError) {
                    entries = []; inputs = [:]; sourceRecords = [:]
                    storageError = (error as? DaybookRecapFailure == .changed ? DaybookRecapFailure.changed : .storage).localizedDescription
                }
            }
        }
    }
    func remoteRequest() -> RemoteRequest? {
        guard canGenerate, let input, let context, context.configuration.isRemote else { return nil }
        return RemoteRequest(input: input, configuration: context.configuration, revision: context.revision, language: context.language)
    }
    func cancel() {
        cancelGeneration(persistAttempt:true)
    }
    private func cancelGeneration(persistAttempt: Bool) {
        generation = UUID(); generationTask?.cancel(); generationTask = nil; isGenerating = false
        deadlineTask?.cancel(); deadlineTask = nil; generationProgress = nil
        if persistAttempt, var entry = activeAttempt {
            entry.message = "生成已取消，可手动重试。"
            message = entry.message
            do { try store.save(entry); publish(entry) }
            catch { storageError = DaybookRecapFailure.storage.localizedDescription; entries = [] }
        }
        activeAttempt = nil
    }
    func generate(confirmation: RemoteRequest? = nil, rememberChoice: Bool = false) {
        startGeneration(confirmation: confirmation, rememberChoice: rememberChoice, automatic: false)
    }
    private func startGeneration(confirmation: RemoteRequest? = nil, rememberChoice: Bool = false, automatic: Bool) {
#if WISELIFE_CONTENT_LAB && targetEnvironment(simulator)
        if automatic { return }
#endif
        guard canGenerate, let input, let context, let settings else { return }
        guard !automatic || !context.configuration.isRemote || !settings.requiresRemoteAIConfirmation else { return }
        let token = UUID(); generation = token; isGenerating = true; message = nil
        generationProgress = "正在核对当天资料…"
        var initialAttempt = current ?? DaybookRecapEntry(input: input)
        initialAttempt.attemptKey = attemptKey(input, context: context)
        initialAttempt.message = "上次生成未完成，可手动重试。"
        do {
            // Persist before any suspension. A records/configuration update during generation
            // must see that this date has already had its automatic attempt.
            guard try store.beginAttempt(initialAttempt, automatic: automatic) else {
                isGenerating = false; generationTask = nil; generationProgress = nil
                message = "该日期已自动尝试过，可手动生成或更新回顾。"
                return
            }
            activeAttempt = initialAttempt; publish(initialAttempt)
        } catch {
            isGenerating = false; generationTask = nil; generationProgress = nil
            storageError = DaybookRecapFailure.storage.localizedDescription
            return
        }
        deadlineTask?.cancel()
        deadlineTask = Task { [weak self, generationTimeout] in
            do { try await Task.sleep(for: generationTimeout) } catch { return }
            guard let self, self.generation == token, self.isGenerating else { return }
            let pending = self.activeAttempt
            self.cancelGeneration(persistAttempt: false)
            self.message = DaybookRecapFailure.timedOut.localizedDescription
            if var entry = pending {
                entry.message = self.message
                do { try self.store.save(entry); self.publish(entry) }
                catch { self.storageError = DaybookRecapFailure.storage.localizedDescription; self.entries = [] }
            }
        }
        generationTask = Task { [weak self, settings] in
            guard let self else { return }
            defer {
                if generation == token {
                    deadlineTask?.cancel(); deadlineTask = nil; generationProgress = nil
                }
            }
            let attempt: DaybookRecapEntry? = initialAttempt
            do {
                let latest = try await readRecords(input.scope)
                try Task.checkCancellation()
                guard generation == token,
                      settings.ai == context.configuration, settings.aiRevision == context.revision,
                      settings.interfaceLanguage.rawValue == context.language,
                      DaybookRecapInput.prepare(records: latest, day: context.day, allowedKinds: context.allowedKinds).fingerprint == input.fingerprint else { throw DaybookRecapFailure.changed }
                if context.configuration.isRemote {
                    let confirmed = confirmation.map { $0.input.fingerprint == input.fingerprint && $0.configuration == context.configuration && $0.revision == context.revision && $0.language == context.language }
                    guard settings.authorizeRemoteAISend(confirmationIsCurrent: confirmed, rememberChoice: rememberChoice) else { throw DaybookRecapFailure.changed }
                }
                self.context?.requiresConfirmation = settings.requiresRemoteAIConfirmation
                let consentAtSend = settings.requiresRemoteAIConfirmation
                let current: @MainActor () -> Bool = { [weak self, weak settings] in
                    guard let self, let settings else { return false }
                    return self.generation == token && self.context?.day == context.day
                        && self.context?.allowedKinds == context.allowedKinds
                        && self.context?.foreground == true && self.context?.capturing == false
                        && settings.ai == context.configuration && settings.aiRevision == context.revision
                        && settings.interfaceLanguage.rawValue == context.language && settings.requiresRemoteAIConfirmation == consentAtSend
                }
                let apiKey = context.configuration.mode == .custom ? try settings.apiKey() : nil
                let text = try await service.generate(input, configuration: context.configuration, apiKey: apiKey, language: context.language, isCurrent: current) { [weak self] progress in
                    guard let self, self.generation == token else { return }
                    self.generationProgress = progress
                }
                try Task.checkCancellation(); guard current() else { throw CancellationError() }
                generationProgress = "正在核对来源并保存回顾…"
                let fresh = try await readRecords(input.scope)
                try Task.checkCancellation(); guard current(), DaybookRecapInput.prepare(records: fresh, day: context.day, allowedKinds: context.allowedKinds).fingerprint == input.fingerprint else { throw DaybookRecapFailure.changed }
                try DaybookRecapInput.validate(text, sourceNumbers: Set(input.sources.map(\.number)))
                var result = DaybookRecapEntry(input: input)
                result.text = text; result.generatedAt = .now; result.provider = context.configuration.label; result.language = context.language
                result.coverage = input.coverage; result.attemptKey = initialAttempt.attemptKey
                try store.save(result); publish(result); message = nil
            } catch {
                guard generation == token else { return }
                if let failure = error as? DaybookRecapFailure, case .changed = failure {
                    // A repository may change before its UI notification arrives. Revalidate the
                    // archive immediately instead of leaving old private claims visible.
                    activeAttempt = nil; generationTask = nil; isGenerating = false; reload(); return
                }
                if error is DaybookDatabase.Failure || error as? DaybookRecapFailure == .storage {
                    // Failed evidence reads cannot establish deletion or validate the earlier prose.
                    // Keep the durable archive for recovery, but hide it until a successful reread.
                    entries = []; inputs = [:]; sourceRecords = [:]
                    storageError = DaybookRecapFailure.storage.localizedDescription
                    activeAttempt = nil; generationTask = nil; isGenerating = false; return
                }
                do {
                    let safe = error is CancellationError ? "生成已中断，可手动重试。" :
                        (error as? DaybookRecapFailure)?.localizedDescription ?? (error as? AIServiceError)?.localizedDescription ?? DaybookRecapFailure.generation.localizedDescription
                    message = safe
                    if var entry = attempt {
                        entry.message = safe
                        do { try store.save(entry); publish(entry) }
                        catch { storageError = DaybookRecapFailure.storage.localizedDescription; entries = [] }
                    } else if error is DaybookDatabase.Failure { storageError = DaybookRecapFailure.storage.localizedDescription; entries = [] }
                }
            }
            guard generation == token else { return }
            isGenerating = false; generationTask = nil; activeAttempt = nil
        }
    }
    private func attemptKey(_ input: DaybookRecapInput, context: Context) -> String {
        DaybookRecapInput.digest([input.fingerprint, DaybookRecapInput.digest(context.configuration), context.language, "daily-recap-v1"])
    }
    private func readRecords(_ scope: DateInterval) async throws -> [DayRecord] {
        guard let scopeLoader else { throw DaybookRecapFailure.storage }
        // Registration/segmentation may publish while a complete date is loading.
        // Retry only that stale read, never inference or an actual storage failure.
        for attempt in 0..<3 {
            try Task.checkCancellation()
            do { return try await scopeLoader(scope) }
            catch is CancellationError { throw CancellationError() }
            catch DaybookRecapFailure.changed {
                guard attempt < 2 else { throw DaybookRecapFailure.changed }
                await Task.yield()
            }
            catch { throw DaybookRecapFailure.storage }
        }
        throw DaybookRecapFailure.changed
    }
    private func publish(_ entry: DaybookRecapEntry) {
        archiveRevision += 1
        entries.removeAll { $0.dayKey == entry.dayKey }; entries.append(entry); entries.sort { $0.dayKey > $1.dayKey }
    }
}

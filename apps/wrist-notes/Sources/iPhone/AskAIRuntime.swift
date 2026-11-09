import Foundation
import CryptoKit

@MainActor final class AskAIRuntime {
    enum Failure: LocalizedError {
        case requestLimit, deadline, contextOverflow, invalidState, repeatedCall, unresolvedLedgerFilters
        var errorDescription: String? { if case .unresolvedLedgerFilters = self { return "当前模型不支持资料工具，无法可靠解析这次账目筛选。请明确月份（例如 2026-11）、收入或支出及原有分类名称后重试；不会改用全部账目合计。" };return "本次回答未能在安全范围内完成，请缩小问题范围后重试。" }
    }
    private let original: DaybookRetrieval.Prepared
    private let records: [DayRecord]
    private let configuration: AIConfiguration
    private let configurationRevision: Int
    private let turnID: UUID
    private let store: AskAIRuntimeStore
    private let isCurrent: @MainActor () -> Bool
    private let ensureFresh: @MainActor () async throws -> Void
    private let onStage: @MainActor (String) -> Void
    private let authorizeAdditional: @MainActor (String) async throws -> Void
    private let fence = AskAIPublicationFence()
    private var prepared: DaybookRetrieval.Prepared?
    private var tools: AskAIReadTools?
    private var run: AskAIRuntimeStore.Run?
    private var history: [DaybookConversationTurn] = []
    private var memory: AskAIRollingMemory?
    private var memoryBlocks: [AskAIMemoryBlock] = []
    private let notebookPermissions: AgentNotebookPermissions
    private let notebookReader: AskAINotebookReader?
    private let queryScope: AgentQueryScope
    private var definitions: [[String: Any]] = []
    private var authorizedContents = Set<String>()
    private var usedCompaction = false
    var testSummaryDriver: (any AskAIDriving)?
    private var generation: Int64 = 0
    private var requests = 0
    private var activeStart = ProcessInfo.processInfo.systemUptime
    private var consentSeconds: TimeInterval = 0
    private var seenCalls = Set<String>()
    private var usedRepair = false
    private var usedRebuild = false
    private var generated = false
    private var finalResult: AskAIReadTools.Finalized?
    private var generationActive = false
    private var cancellationReason: String?
    private var apple: AskAIAppleDriver?
    private var nativeContext = ""
    private var usesNativeContext = false
    // Synthetic driver injection never affects the production provider choice.
    var testDriver: (any AskAIDriving)?
    var customSession: URLSession?
    var activeDeadline: TimeInterval = 90
    var summaryTimeout: TimeInterval = 15
    var queryNow = Date.now
    var queryCalendar = Calendar.current
    var beforePublicationLease: (@Sendable () -> Void)?

    init(prepared: DaybookRetrieval.Prepared, records: [DayRecord], configuration: AIConfiguration,
         configurationRevision: Int, turnID: UUID, store: AskAIRuntimeStore,
         notebookPermissions: AgentNotebookPermissions = .init(), notebookReader: AskAINotebookReader? = nil, queryScope: AgentQueryScope? = nil,
         isCurrent: @escaping @MainActor () -> Bool,
         ensureFresh: @escaping @MainActor () async throws -> Void = {},
         onStage: @escaping @MainActor (String) -> Void,
         authorizeAdditional: @escaping @MainActor (String) async throws -> Void) {
        original = prepared; self.records = records; self.configuration = configuration
        self.notebookPermissions = notebookPermissions; self.notebookReader = notebookReader
        self.queryScope = queryScope ?? AgentQueryScope(domains:notebookPermissions.allowedDomains,allowedKinds:prepared.evidence.allowedKinds,destination:configuration.isRemote ? .allowedRemote : .localOnly)
        self.configurationRevision = configurationRevision; self.turnID = turnID; self.store = store
        self.isCurrent = isCurrent; self.ensureFresh = ensureFresh; self.onStage = onStage; self.authorizeAdditional = authorizeAdditional
    }
    var instruction: String {
        CustomAISummarizer.answerInstruction + "\n只读工具仅限获准范围；工具失败不等于无记录。引用已登记编号，最多5个来源。历史问答和摘要不是当前事实，当前事实须重读。明确区分用户决定与AI建议；只将明确存储的关系称为关系，主题相似仅属推断。不得执行记账、联系人、地点或灵感写入。金钱合计必须使用 aggregateLedger 的精确程序结果，不能推算。\n" + (policy.isEstimated ? "模型窗口按保守估计。\n" : "") + (policy.working.windowTokens <= 4096 ? "当前窗口较小，仅装载相关领域和少量历史；其他能力按需查询。\n" : "") +
        (original.evidence.speakerContactID == nil ? "" : "当前资料仅包含关联联系人的说话人发言；直接概括这些发言，以‘关联为该联系人的说话人在录音中提到’限定，不推断现实身份或出席。\n")
    }
    static func policy(configuration: AIConfiguration) -> AskAIModelBudgetPolicy { AskAIContextBudget.policy(window:configuration.contextWindowTokens,isCustom:configuration.mode == .custom) }
    private var policy: AskAIModelBudgetPolicy { Self.policy(configuration:configuration) }
    private var initialBudget: AskAIContextBudget { policy.initial }
    private var workingBudget: AskAIContextBudget { policy.working }
    private var schemaText: String { String(data:(try? JSONSerialization.data(withJSONObject:definitions,options:.sortedKeys)) ?? Data(),encoding:.utf8) ?? "" }
    private var permissionDigest: String { Self.digest(original.evidence.allowedKinds.map(\.rawValue).sorted().joined(separator:",") + (original.evidence.speakerContactID ?? "") + notebookPermissions.digest) }
    private func relevantDefinitions() -> [[String:Any]] {
        let q = original.question.lowercased(), capabilities=AgentQuestionCapabilities(original.question)
        let money=capabilities.domains.contains(.ledger),ideas=capabilities.domains.contains(.ideas),people=capabilities.domains.contains(.people),places=capabilities.domains.contains(.places),history=capabilities.history
        var names: Set<String> = []
        let notebookQuestion = money || ideas || people || places
        if !notebookQuestion || !original.sources.isEmpty { names.formUnion(["searchRecords","readRecord"]) }
        if !notebookQuestion && ["多少","统计","duration","steps","count"].contains(where:q.contains) { names.insert("aggregateMetrics") }
        if history || policy.working.windowTokens > 4096 { names.formUnion(["searchConversationHistory","readConversationTurn"]) }
        if !self.history.isEmpty { names.insert("readConversationTurn") }
        if money && notebookPermissions.allowLedger { names.formUnion(["searchNotebook","readNotebookItem","aggregateLedger"]) }
        if (ideas || capabilities.usesAgent(question:original.question,permissions:notebookPermissions) && capabilities.domains.isEmpty) && notebookPermissions.allowIdeas { names.formUnion(["searchNotebook","readNotebookItem"]) }
        if people && notebookPermissions.allowPeople { names.formUnion(["searchNotebook","readNotebookItem","listPersonSegments"]) }
        if places && notebookPermissions.allowPlaces { names.formUnion(["searchNotebook","readNotebookItem","listPlaceVisits"]) }
        if (policy.working.windowTokens > 4096 || capabilities.domains.isEmpty) && !notebookPermissions.allowedDomains.subtracting([.timeline,.conversation]).isEmpty { names.formUnion(["searchNotebook","readNotebookItem"]) }
        let priority = money ? ["aggregateLedger","readNotebookItem","searchNotebook","readConversationTurn","searchConversationHistory","readRecord","searchRecords","aggregateMetrics"] : ["searchNotebook","readNotebookItem","readConversationTurn","searchConversationHistory","listPersonSegments","listPlaceVisits","searchRecords","readRecord","aggregateMetrics"]
        var loaded: [[String:Any]] = []
        for name in priority where names.contains(name) {
            guard let definition = AskAIReadTools.toolDefinitions.first(where: { $0["name"] as? String == name }) else { continue }
            let candidate = loaded + [definition]
            let schema = String(data:(try? JSONSerialization.data(withJSONObject:candidate,options:.sortedKeys)) ?? Data(),encoding:.utf8) ?? ""
            if initialBudget.estimatedInput(instruction:instruction,content:CustomAISummarizer.answerContent(question:original.providerQuestion,context:"CURRENT QUESTION:\n" + original.question + "\nCURRENT VERIFIED EVIDENCE:\n") + String(repeating:"x ",count:80),tools:schema) <= initialBudget.inputLimit { loaded = candidate }
        }
        return loaded
    }
    var capabilityStatus: String { policy.working.windowTokens <= 4096 ? "当前模型窗口较小，仅装载与本次问题相关的能力；更早问答按需读取。" : "" }
    var loadedToolDefinitions: [[String:Any]] { definitions }
    private var sourceDigest: String { Self.digest(original.evidence.fingerprint + permissionDigest + String(original.dayStart.timeIntervalSinceReferenceDate) + String(original.dayEnd.timeIntervalSinceReferenceDate)) }
    private var configDigest: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return Self.digest(String(data:(try? encoder.encode(configuration)) ?? Data(),encoding:.utf8)! + ":\(configurationRevision):" + instruction + schemaText + ProcessInfo.processInfo.operatingSystemVersionString)
    }
    static func digest(_ text:String) -> String { SHA256.hash(data:Data(text.utf8)).map { String(format:"%02x",$0) }.joined() }
    private func check() throws {
        try Task.checkCancellation()
        guard fence.check(), isCurrent() else { fence.invalidate(); throw CancellationError() }
        guard !generationActive || ProcessInfo.processInfo.systemUptime - activeStart - consentSeconds < activeDeadline else { throw Failure.deadline }
    }
    private func update(_ state:AskAIRuntimeStore.State) async throws {
        try check(); guard let run else { throw Failure.invalidState }
        try await store.updateAttempt(runID:run.id,state:state,providerRequests:requests,toolCalls:tools?.toolCallCount ?? 0)
        try check()
    }
    func prepare() async throws -> DaybookRetrieval.Prepared {
        try check(); guard run == nil else { throw Failure.invalidState }
        generation = try await store.cacheGeneration()
        run = try await store.startAttempt(turnID:turnID,provider:configuration.mode.rawValue,model:configuration.model,configRevision:String(configurationRevision))
        history = try await store.runtimeHistory(limit:40).filter { $0.id != turnID && $0.evidence.allowedKinds.isSubset(of:original.evidence.allowedKinds) && $0.evidence.speakerContactID == original.evidence.speakerContactID }
        definitions = relevantDefinitions()
        memoryBlocks = try await store.loadMemoryBlocks(permissionDigest:permissionDigest,destination:queryScope.destination)
        history = history.filter { turn in
            AgentRunProvenance.consulting(turn).permits(queryScope) && (turn.evidenceRefs ?? []).allSatisfy { queryScope.domains.contains($0.domain) && $0.sourceKinds.isSubset(of:queryScope.allowedKinds) } && (!configuration.isRemote || turn.disclosurePolicy == .allowedRemote)
        }
        var freshHistory:[DaybookConversationTurn]=[]
        for turn in history { if try await store.validateProvenance(.consulting(turn),scope:queryScope) { freshHistory.append(turn) } }
        history=freshHistory
        memoryBlocks=memoryBlocks.filter { $0.runProvenance?.permits(queryScope) != false }
        let readTools = AskAIReadTools(prepared:original,records:records,history:history,scopeIsCurrent:isCurrent,notebookReader:notebookReader,runtimeStore:store,queryScope:queryScope,enabledToolNames:Set(definitions.compactMap { $0["name"] as? String }),maxOutputTokens:400)
        tools = readTools
        memoryBlocks.sort { a,b in
            let terms = DaybookRetrieval.keywords(original.question)
            return terms.filter { a.context.localizedCaseInsensitiveContains($0) }.count > terms.filter { b.context.localizedCaseInsensitiveContains($0) }.count
        }
        let result = try bounded(readTools.evidence.map(\.source), history:history, memory:memory)
        prepared = result
        try await persistEvidence(); try await update(configuration.isRemote ? .awaitingConsent : .preparing); try check(); return result
    }
    private func bounded(_ sources:[DaybookRetrieval.Source],history:[DaybookConversationTurn],memory:AskAIRollingMemory?) throws -> DaybookRetrieval.Prepared {
        // Wrapper/question are charged as instruction overhead too; this intentionally overestimates.
        var prefix = ""
        if original.evidence.speakerContactID != nil {
            // prepareSpeaker's first line is a controlled contact identity prefix, never transcript text.
            let first = String(original.context.prefix(300).split(separator:"\n",omittingEmptySubsequences:false).first ?? "")
            if first.hasPrefix("当前检索对象是联系人「") || first.hasPrefix("当前关联联系人：") || first.hasPrefix("当前问题") || first.hasPrefix("关联联系人：") || first.hasPrefix("当前联系人：") { prefix = first + "\n" }
        }
        let overhead = CustomAISummarizer.answerContent(question:original.providerQuestion,context:prefix)
        let context = try AskAIContextBuilder.build(question:original.question,history:history,evidence:sources,instruction:instruction + overhead,tools:schemaText,memory:memory,budget:initialBudget,memoryBlocks:memoryBlocks,recentTurnLimit:policy.recentRoundCount)
        if let tools {
            for turn in history where context.historyTurnIDs.contains(turn.id) { tools.recordContext(.consulting(turn)) }
            for block in memoryBlocks where context.memoryBlockIDs.contains(block.id) { if let provenance=block.runProvenance { tools.recordContext(provenance) } }
        }
        let originalHeader = "CURRENT QUESTION:\n" + original.question + "\n"
        let outgoingContent = "CURRENT QUESTION:\n" + original.providerQuestion + "\n" + context.content.dropFirst(originalHeader.count)
        let result = original.projecting(sources:context.sources,context:prefix + outgoingContent,allowRuntime:true)
        guard initialBudget.fits(instruction:instruction,content:CustomAISummarizer.answerContent(question:result.providerQuestion,context:result.context),tools:schemaText) else { throw Failure.contextOverflow }
        return result
    }
    private func persistEvidence() async throws {
        guard let run, let tools else { throw Failure.invalidState }
        for entry in tools.evidence {
            try check()
            try await store.recordEvidence(runID:run.id,id:entry.id,sourceIdentity:entry.source.id.uuidString,sourceVersion:Self.digest(entry.source.snippet),queryScope:sourceDigest,excerpt:String(entry.source.snippet.prefix(200)),permissionDigest:permissionDigest)
        }
    }
    private func validateCurrentEvidence() async throws -> Bool {
        guard let tools else { return true }
        return try await timed { try await tools.validateEvidence() }
    }
    private func countRequest(_ count:Int = 1) async throws {
        try await ensureFresh(); guard try await validateCurrentEvidence() else { throw CancellationError() }; try check(); guard requests + count <= 8 else { throw Failure.requestLimit }; requests += count; try await update(.generating)
    }
    private func consent(_ text:String) async throws {
        guard authorizedContents.insert(Self.digest(text)).inserted else { return }
        try await update(.awaitingConsent)
        let start = ProcessInfo.processInfo.systemUptime
        do { try await authorizeAdditional(text) }
        catch { consentSeconds += ProcessInfo.processInfo.systemUptime - start; throw error }
        consentSeconds += ProcessInfo.processInfo.systemUptime - start
        try check()
    }
    private func execute(_ call:AskAIToolCall, remote:Bool) async throws -> String {
        try check(); guard let run, let tools else { throw Failure.invalidState }
        guard tools.toolCallCount < 6 else { throw AskAIReadTools.Failure.callLimit }
        guard seenCalls.insert(call.id).inserted else { throw Failure.repeatedCall }
        let start = ProcessInfo.processInfo.systemUptime
        try await update(.toolRunning); onStage("正在查阅本地资料…")
        // Persist hashes only: model-supplied arguments can repeat private excerpts or prompt injection.
        try await store.recordToolCall(runID:run.id,callID:Self.digest(call.id),toolName:AskAIReadTools.toolDefinitions.contains(where:{$0["name"] as? String == call.name}) ? call.name : "unknown",argsDigest:Self.digest(String(decoding:call.arguments,as:UTF8.self)),arguments:"{}",state:"running",resultReferences:[],elapsedMilliseconds:0)
        let output:String; let references:[String]; let state:String
        do {
            let result = try await timed { try await tools.execute(name:call.name,arguments:call.arguments) }
            output = "status=\(result.status)\n" + result.text; references = result.evidenceIDs; state = "completed"
        } catch is CancellationError { throw CancellationError() }
        catch AskAIReadTools.Failure.staleEvidence { throw CancellationError() }
        catch AskAIReadTools.Failure.callLimit { throw AskAIReadTools.Failure.callLimit }
        catch {
            // Never reflect raw filesystem/SQL/network/localized errors to a provider.
            output = "status=error\nLocal tool could not complete this request. This is not an empty result."; references = []; state = "failed"
        }
        try check(); try await persistEvidence()
        try await store.recordToolCall(runID:run.id,callID:Self.digest(call.id),toolName:AskAIReadTools.toolDefinitions.contains(where:{$0["name"] as? String == call.name}) ? call.name : "unknown",argsDigest:Self.digest(String(decoding:call.arguments,as:UTF8.self)),arguments:"{}",state:state,resultReferences:references,elapsedMilliseconds:Int((ProcessInfo.processInfo.systemUptime-start)*1000))
        try await update(.generating)
        if remote { try await consent(output) }
        return output
    }
    /// Shared native callback boundary, also exercised without invoking a model in fixtures.
    func executeNative(_ call: AskAIToolCall) async throws -> String {
        usesNativeContext = true
        // Conservative charge for the model continuation after each native tool result.
        try await countRequest()
        let result = try await execute(call, remote: false)
        nativeContext += "\nTOOL CALL " + call.id + " " + call.name + String(decoding: call.arguments, as: UTF8.self) + "\nTOOL RESULT\n" + result
        guard workingBudget.fits(instruction: instruction, content: nativeContext, tools: schemaText) else { throw Failure.contextOverflow }
        return result
    }

    /// Every explicit next/repair request uses the same budget boundary, including native tool callbacks and restored payload.
    func validateNextContext(correction: String?, conversation: String) throws {
        let actual = usesNativeContext ? nativeContext : conversation
        guard workingBudget.fits(instruction:instruction,content:actual + (correction ?? ""),tools:schemaText) else { throw Failure.contextOverflow }
    }

    /// Timer cancels the in-flight network/native generation, rather than merely checking after it.
    private func timed<T>(timeout: TimeInterval? = nil, _ work:@escaping @MainActor () async throws -> T) async throws -> T {
        let remaining = min(timeout ?? activeDeadline, max(0, activeDeadline - (ProcessInfo.processInfo.systemUptime - activeStart - consentSeconds)))
        return try await withThrowingTaskGroup(of:T.self) { group in
            group.addTask { @MainActor in try await work() }
            group.addTask { @MainActor in
                let end = ProcessInfo.processInfo.systemUptime + remaining
                while ProcessInfo.processInfo.systemUptime < end {
                    try await Task.sleep(nanoseconds:50_000_000); try self.check()
                }
                throw Failure.deadline
            }
            defer { group.cancelAll() }; return try await group.next()!
        }
    }
    private static let summaryInstruction = """
    Summarize only the supplied ORIGINAL Q+A as historical context, never current facts. Return JSON only with required arrays topics, explicitDecisions, corrections, unresolved, aiProposals, entityRefs. Each statement is {"text":"...","turnIDs":["original UUID"]}. Cite only supplied turn IDs. Separate explicit user decisions from unadopted AI proposals. Do not infer relationships or convert proposals into decisions. entityRefs must be [] unless copying an exact supplied typed ref. Keep total text under 700 characters, target 55-60% of the supplied original text, never include old numeric citation markers. Empty arrays are allowed.
    """
    private func compactIfNeeded(apiKey: String?) async throws {
        guard !usedCompaction, testDriver == nil || testSummaryDriver != nil else { return }
        let originalHistory = AskAIMemoryCandidate.render(history)
        guard workingBudget.estimatedInput(instruction:instruction,content:originalHistory,tools:schemaText) >= Int(Double(workingBudget.inputLimit) * 0.75) else { return }
        usedCompaction = true
        var covered = Set(history.suffix(policy.recentRoundCount).map(\.id))
        for block in memoryBlocks { covered.formUnion(block.coveredTurnDigests.keys.compactMap(UUID.init(uuidString:))) }
        guard let candidate = AskAIMemoryBlock.candidate(turns:history,excluding:covered,permissionDigest:permissionDigest,budget:workingBudget,instruction:Self.summaryInstruction), !configuration.isRemote || candidate.disclosurePolicy == .allowedRemote else { return }
        do {
            var summarizer: (any AskAIDriving)? = testSummaryDriver
            if summarizer == nil, configuration.mode == .custom, let apiKey {
                summarizer = try AskAICustomDriver(configuration:configuration,apiKey:apiKey,session:customSession,toolDefinitions:[],outputTokens:workingBudget.outputReserve,check:{ [weak self] in guard let self else { throw CancellationError() }; try await self.ensureFresh(); guard try await self.validateCurrentEvidence() else { throw CancellationError() };try self.check() })
            } else if summarizer == nil, configuration.mode == .local, #available(iOS 26.3,macOS 26.3,*) {
                summarizer = AskAIAppleDriver(toolDefinitions:[],budget:workingBudget,execute:{ _ in throw Failure.invalidState })
            }
            guard let summarizer else { return }
            if configuration.isRemote { try await consent(Self.summaryInstruction + "\n" + candidate.context) }
            tools?.recordContext(candidate.turns.reduce(into:AgentRunProvenance()) { $0.merge(.consulting($1)) })
            try summarizer.start(instruction:Self.summaryInstruction,content:candidate.context)
            try await countRequest(); onStage("正在整理较早的对话…")
            let reply = try await timed(timeout:min(15,summaryTimeout)) { try await summarizer.next(correction:nil) }
            guard reply.calls.isEmpty else { return }
            let block = try AskAIMemoryBlock.parse(Data(reply.text.utf8),candidate:candidate,model:configuration.model)
            try check(); try await ensureFresh()
            try await store.saveMemoryBlock(block,expectedGeneration:generation,publicationFence:fence)
            memoryBlocks.insert(block,at:0)
            prepared = try bounded(tools?.evidence.map(\.source) ?? original.sources,history:history,memory:nil)
        } catch is CancellationError { try check() }
        catch { try check() } // Optional cache failure preserves original history and read tools.
    }
    func generate(apiKey:String?,fallback:any DaybookAnswering) async throws -> AskAIReadTools.Finalized {
        activeStart = ProcessInfo.processInfo.systemUptime; consentSeconds = 0
        generationActive = true; defer { generationActive = false }
        try check(); guard let reviewed = prepared, let tools, !generated else { throw Failure.invalidState }
        authorizedContents.insert(Self.digest(CustomAISummarizer.answerContent(question:reviewed.providerQuestion,context:reviewed.context)))
        try await compactIfNeeded(apiKey:apiKey)
        guard let prepared else { throw Failure.invalidState }
        if configuration.isRemote { try await consent(CustomAISummarizer.answerContent(question:prepared.providerQuestion,context:prepared.context)) }
        // The clock began once above; only explicit consent time is excluded.
        var driver: (any AskAIDriving)? = testDriver
        if driver == nil, configuration.mode == .custom {
            guard let apiKey else { throw AIServiceError.authentication }
            let custom = try AskAICustomDriver(configuration:configuration,apiKey:apiKey,session:customSession,toolDefinitions:definitions,outputTokens:workingBudget.outputReserve,check:{ [weak self] in guard let self else { throw CancellationError() }; try await self.ensureFresh(); guard try await self.validateCurrentEvidence() else { throw CancellationError() };try self.check() })
            try await countRequest()
            if try await timed({ try await custom.probe() }) { driver = custom }
        } else if driver == nil, configuration.mode == .local {
            if #available(iOS 26.3, macOS 26.3, *) {
                let native = AskAIAppleDriver(toolDefinitions:definitions,budget:workingBudget,execute:{ [weak self] call in
                    guard let self else { throw CancellationError() }
                    return try await self.executeNative(call)
                })
                apple = native; driver = native; usesNativeContext = true
            }
        }
        guard let driver else {
            var supplemental = ""
            let names = Set(definitions.compactMap { $0["name"] as? String })
            var plan: [(String,[String:Any])] = []
            if names.contains("aggregateLedger") {
                guard let filters=try? AskAILedgerFilterResolver.resolve(original.question,now:queryNow,calendar:queryCalendar) else { throw Failure.unresolvedLedgerFilters }
                plan.append(("aggregateLedger",filters))
            }
            else if names.contains("searchNotebook") {
                let domains = queryScope.domains.intersection([.ideas,.ledger,.people,.places]).sorted { $0.rawValue < $1.rawValue }
                for domain in domains.prefix(2) { plan.append(("searchNotebook",["type":domain.rawValue,"query":original.question,"limit":3])) }
            }
            if names.contains("searchConversationHistory") { plan.append(("searchConversationHistory",["query":original.question,"limit":2])) }
            for (name,args) in plan.prefix(3) {
                let call = AskAIToolCall(id:"fallback-" + UUID().uuidString,name:name,arguments:try JSONSerialization.data(withJSONObject:args,options:.sortedKeys))
                supplemental += "\n" + (try await execute(call,remote:configuration.isRemote))
            }
            var content = prepared.context + supplemental
            while !workingBudget.fits(instruction:instruction,content:CustomAISummarizer.answerContent(question:prepared.providerQuestion,context:content),tools:"") && !supplemental.isEmpty {
                supplemental = String(supplemental.dropLast(max(1,supplemental.count/8))); content = prepared.context + supplemental
            }
            let fallbackPrepared = prepared.projecting(sources:prepared.sources,context:content)
            let text = try await timed {
                if let service = fallback as? DaybookAnswerService {
                    return try await service.answerReviewed(fallbackPrepared,configuration:self.configuration,apiKey:apiKey,instruction:self.instruction,isCurrent:self.isCurrent,ensureFresh:{ try await self.ensureFresh();guard try await self.validateCurrentEvidence() else { throw CancellationError() } },sourceNumbers:tools.citationNumbers,maximumResponseTokens:self.workingBudget.outputReserve,beforeRequest:{
                        guard self.workingBudget.fits(instruction:self.instruction + DaybookAnswerCitationPolicy.repairInstruction(tools.citationNumbers),content:CustomAISummarizer.answerContent(question:fallbackPrepared.providerQuestion,context:fallbackPrepared.context)) else { throw Failure.contextOverflow }
                        try await self.countRequest()
                    })
                }
                try await self.countRequest()
                return try await fallback.answer(fallbackPrepared,configuration:self.configuration,apiKey:apiKey,isCurrent:self.isCurrent)
            }
            try check(); guard try await validateCurrentEvidence() else { throw CancellationError() }
            let finalized = try tools.finalize(answer:text); generated = true; finalResult = finalized; return finalized
        }
        nativeContext = CustomAISummarizer.answerContent(question:prepared.providerQuestion,context:prepared.context)
        try driver.start(instruction:instruction,content:nativeContext)
        if let apple {
            let inputDigest = Self.digest(prepared.context + prepared.providerQuestion)
            if let checkpoint = try await store.loadCheckpoint(providerConfigDigest:configDigest,permissionDigest:permissionDigest,sourceDigest:sourceDigest,inputDigest:inputDigest) {
                if apple.restore(checkpoint.payload, newInput:prepared.context + instruction + schemaText) { nativeContext += String(decoding:checkpoint.payload,as:UTF8.self) }
            }
        }
        var correction:String?; var transcript = CustomAISummarizer.answerContent(question:prepared.providerQuestion,context:prepared.context)
        while true {
            try check()
            do {
                try validateNextContext(correction:correction,conversation:transcript)
                try await countRequest(); onStage("正在整理回答…")
                let prompt = correction
                let reply = try await timed { try await driver.next(correction:prompt) }; correction = nil
                transcript += (prompt ?? "") + reply.text
                if usesNativeContext { nativeContext += (prompt ?? "") + reply.text }
                if !reply.calls.isEmpty {
                    for call in reply.calls {
                        let result = try await execute(call,remote:configuration.isRemote)
                        try driver.receive(call:call,result:result)
                        transcript += "\nASSISTANT TOOL CALL " + call.id + " " + call.name + "\n" + String(decoding:call.arguments,as:UTF8.self) + "\nTOOL RESULT " + call.id + "\n" + result
                    }
                    continue
                }
                try await update(.validating)
                do { guard try await validateCurrentEvidence() else { throw CancellationError() }; let finalized = try tools.finalize(answer:reply.text); guard try await validateCurrentEvidence() else { throw CancellationError() }; generated = true; finalResult = finalized; return finalized }
                catch AskAIReadTools.Failure.invalidCitation {
                    guard !usedRepair else { throw DaybookAnswerFailure.missingCitations }
                    usedRepair = true
                    correction = DaybookAnswerCitationPolicy.repairInstruction(tools.citationNumbers) + " At most five sources, one window per record."
                }
            } catch Failure.contextOverflow {
                guard !usedRebuild else { throw Failure.contextOverflow }; usedRebuild = true
                let rebuilt = try bounded(Array(tools.evidence.suffix(5)).map(\.source),history:[],memory:nil)
                let content = CustomAISummarizer.answerContent(question:rebuilt.providerQuestion,context:rebuilt.context)
                if configuration.isRemote { try await consent(content) }
                try driver.start(instruction:instruction,content:content); transcript = content; nativeContext = content
            }
        }
    }
    func publish(_ turn:DaybookConversationTurn) async throws {
        guard let run, generated, let finalResult, turn.id == turnID, turn.text == finalResult.text, turn.sources == finalResult.sources, turn.evidence == finalResult.prepared.evidence, (turn.evidenceRefs ?? []) == finalResult.evidenceRefs,turn.runProvenance == finalResult.runProvenance else { throw Failure.invalidState }
        while true {
            try await ensureFresh(); try check()
            guard try await validateCurrentEvidence() else { throw CancellationError() }
            do {
                try await store.completeAttempt(runID:run.id,turn:turn,publicationFence:fence,beforePublicationLease:beforePublicationLease)
                break
            } catch AskAIPublicationFence.Failure.validationPending {
                // Revalidate and retry only this generated publication, never inference.
                try await fence.waitUntilReady()
            }
        }
        guard fence.check(), isCurrent() else { return }
        let derived = AskAIRollingMemory.build(turns:history + [turn],dependencyDigest:permissionDigest + sourceDigest)
        // These are disposable caches; a failed cache save cannot turn an atomic success into a failed answer.
        try? await store.saveMemory(derived,anchorTurnID:turnID,expectedGeneration:generation,publicationFence:fence)
        if tools?.toolCallCount == 0, let payload = apple?.completedCheckpoint(), let prepared {
            let checkpoint = AskAIRuntimeStore.Checkpoint(anchorTurnID:turnID,providerConfigDigest:configDigest,formatVersion:"1",toolVersion:"1",promptVersion:"1",inputDigest:Self.digest(prepared.context + prepared.providerQuestion),permissionDigest:permissionDigest,sourceDigest:sourceDigest,payload:payload)
            if fence.check(), isCurrent() { try? await store.saveCheckpoint(checkpoint,expectedGeneration:generation,publicationFence:fence) }
        }
    }
    func suspendPublication(validation: UUID) { fence.suspend(validation: validation) }
    func resumePublication(validation: UUID) { fence.resume(validation: validation) }
    func cancel(reason: String = "cancelled") {
        cancellationReason = reason
        fence.invalidate()
        if let run { Task { try? await store.interruptAttempt(runID:run.id,state:.cancelled,errorCode:reason) } }
    }
    func fail(_ error:Error) async {
        fence.invalidate(); guard let run else { return }
        try? await store.interruptAttempt(runID:run.id,state:error is CancellationError ? .cancelled : .failed,errorCode:cancellationReason ?? (error is CancellationError ? "cancelled" : "generation_failed"))
    }
}

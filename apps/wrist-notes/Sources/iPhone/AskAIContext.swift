import CryptoKit
import Foundation

/// Shared pure mixed-language estimate; Ask AI applies its own safety margin in the budget.
enum AskAITokenEstimator {
    static func estimate(_ text: String) -> Int { ContentModelBudget.estimateTokens(text) }
}

struct AskAIContextBudget: Sendable {
    var windowTokens: Int = 4096
    var inputLimit: Int = 2200
    var outputReserve: Int = 512
    func fits(instruction: String, content: String, tools: String = "") -> Bool {
        let input = estimatedInput(instruction: instruction, content: content, tools: tools)
        return inputLimit > 0 && outputReserve >= 0 && input <= inputLimit && input <= windowTokens - outputReserve
    }
    func estimatedInput(instruction: String, content: String, tools: String = "") -> Int {
        // Framing margin covers role boundaries and the answer/citation wrapper.
        let raw = 64 + AskAITokenEstimator.estimate(instruction) + AskAITokenEstimator.estimate(content) + AskAITokenEstimator.estimate(tools)
        return raw + (raw + 3) / 4
    }
}

/// Intent only: assistant assertions and record bodies never enter rolling memory.
struct AskAIRollingMemory: Codable, Equatable, Sendable {
    let questions: [String]
    let coveredCursor: String?
    let dependencyDigest: String
    let inputDigest: String
    var promptVersion = "ask-ai-memory-v1"
    static func build(turns: [DaybookConversationTurn], dependencyDigest: String) -> Self {
        let ordered = turns.filter { $0.completionState == .completed }.sorted {
            let a = $0.createdAt ?? .distantPast, b = $1.createdAt ?? .distantPast
            return a == b ? $0.id.uuidString < $1.id.uuidString : a < b
        }
        let recent = ordered.suffix(12)
        let questions = recent.map { String($0.question.prefix(120)) }
        let digestText = recent.map { $0.id.uuidString + ":" + $0.question }.joined(separator: "\n")
        let digest = SHA256.hash(data: Data((dependencyDigest + "\n" + digestText).utf8)).map { String(format: "%02x", $0) }.joined()
        return Self(questions: questions, coveredCursor: ordered.last.map { "\(($0.createdAt ?? .distantPast).timeIntervalSinceReferenceDate):\($0.id.uuidString)" }, dependencyDigest: dependencyDigest, inputDigest: digest)
    }
}

struct AskAIBoundedContext: Sendable {
    let content: String
    let sources: [DaybookRetrieval.Source]
    let estimatedInputTokens: Int
    let historyTurnIDs: [UUID]
    var memoryBlockIDs: [UUID] = []
}

enum AskAIContextBuilder {
    enum Failure: Error { case invalidQuestion, budgetExceeded, noEvidence }
    static func build(question: String, history: [DaybookConversationTurn], evidence: [DaybookRetrieval.Source], instruction: String, tools: String = "", memory: AskAIRollingMemory? = nil, budget: AskAIContextBudget = .init(), memoryBlocks: [AskAIMemoryBlock] = [], recentTurnLimit: Int? = nil) throws -> AskAIBoundedContext {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, question.count <= 300 else { throw Failure.invalidQuestion }
        var content = "CURRENT QUESTION:\n" + question + "\nCURRENT VERIFIED EVIDENCE:\n"
        guard budget.fits(instruction: instruction, content: content, tools: tools) else { throw Failure.budgetExceeded }
        if let latest = history.last(where: { $0.completionState == .completed }) {
            let pointer = "LATEST PREVIOUS ANSWER TURN " + latest.id.uuidString + "; use readConversationTurn if original answer is omitted below.\n"
            guard budget.fits(instruction:instruction,content:content + pointer,tools:tools) else { throw Failure.budgetExceeded }
            content += pointer
        }
        var sources: [DaybookRetrieval.Source] = []
        for source in evidence.prefix(5) {
            var excerpt = String(source.snippet.prefix(200))
            let title = String(source.title.prefix(48))
            while !excerpt.isEmpty {
                let block = "[\(source.number)] id=\(source.id.uuidString) capturedAt=\(ISO8601DateFormatter().string(from: source.capturedAt)) kind=\(source.kind.rawValue) \(title)\n\(excerpt)\n"
                if budget.fits(instruction: instruction, content: content + block, tools: tools) {
                    content += block
                    sources.append(.init(id: source.id, number: source.number, title: title, capturedAt: source.capturedAt, kind: source.kind, snippet: excerpt, truncated: source.truncated || excerpt != source.snippet, provenance: source.provenance, sourceKey: source.sourceKey, speakerID: source.speakerID, speakerOffset: source.speakerOffset, speakerEndOffset: source.speakerEndOffset))
                    break
                }
                excerpt = String(excerpt.dropLast())
            }
        }
        if !evidence.isEmpty && sources.isEmpty { throw Failure.noEvidence }
        // Complete original Q+A preserves numbered answers. Historical assertions are context only.
        var historyIDs: [UUID] = []
        let count = max(1, min(recentTurnLimit ?? (budget.windowTokens <= 4096 ? 1 : budget.windowTokens <= 8192 ? 2 : 4), 4))
        for turn in history.filter({ $0.completionState == .completed }).suffix(count).reversed() {
            let answer = turn.text.replacingOccurrences(of:#"\[(\d+)\]"#,with:"(historical source $1)",options:.regularExpression)
            let label = "TURN " + turn.id.uuidString + " createdAt=" + (turn.createdAt ?? turn.evidence.dayStart).ISO8601Format()
            let block = "\nCONVERSATION BACKGROUND (historical context, not current facts):\n" + label + "\nUSER: " + turn.question + "\nHISTORICAL AI ANSWER: " + answer + "\n"
            if budget.fits(instruction: instruction, content: content + block, tools: tools) { content += block; historyIDs.append(turn.id) }
            else {
                let omitted = "\n" + label + " HISTORICAL ANSWER OMITTED for budget; readConversationTurn retrieves this exact previous answer.\n"
                if budget.fits(instruction:instruction,content:content + omitted,tools:tools) { content += omitted; historyIDs.append(turn.id) }
                // An older answer must never silently replace the most recent answer.
                break
            }
        }
        var includedBlocks: [UUID] = []
        for block in memoryBlocks.prefix(budget.windowTokens <= 4096 ? 1 : 3) {
            if budget.fits(instruction: instruction, content: content + "\n" + block.context, tools: tools) { content += "\n" + block.context;includedBlocks.append(block.id) }
        }
        if let memory {
            for question in memory.questions.reversed() {
                let block = "\nEARLIER USER INTENT (not evidence): " + question + "\n"
                if budget.fits(instruction: instruction, content: content + block, tools: tools) { content += block }
            }
        }
        return AskAIBoundedContext(content: content, sources: sources, estimatedInputTokens: budget.estimatedInput(instruction: instruction, content: content, tools: tools), historyTurnIDs: historyIDs,memoryBlockIDs:includedBlocks)
    }
}

struct AskAIModelBudgetPolicy: Sendable {
    let initial: AskAIContextBudget
    let working: AskAIContextBudget
    let recentRoundCount: Int
    let isEstimated: Bool
}

extension AskAIContextBudget {
    /// Input estimator already includes the 25% uncertainty allowance; never apply it again.
    static func policy(window: Int?, isCustom: Bool) -> AskAIModelBudgetPolicy {
        let capacity = isCustom ? min(max(window ?? 4096, 1), 32768) : 4096
        let output = capacity <= 4096 ? 512 : capacity <= 16384 ? 1024 : 2048
        let available = max(0, capacity - output - 128) // continuation framing, not a second uncertainty margin
        let initialLimit = min(available, capacity <= 4096 ? 2200 : Int(Double(available) * 0.65))
        return .init(initial: .init(windowTokens: capacity, inputLimit: initialLimit, outputReserve: output),
                     working: .init(windowTokens: capacity, inputLimit: available, outputReserve: output),
                     recentRoundCount: capacity <= 4096 ? 1 : capacity <= 8192 ? 2 : 4, isEstimated: !isCustom || window == nil)
    }
}

/// A generated statement must cite original turns in its selected input block.
struct AskAIMemoryStatement: Codable, Equatable, Sendable {
    let text: String
    let turnIDs: [UUID]
}

struct AskAIMemorySummary: Codable, Equatable, Sendable {
    let topics: [AskAIMemoryStatement]
    let explicitDecisions: [AskAIMemoryStatement]
    let corrections: [AskAIMemoryStatement]
    let unresolved: [AskAIMemoryStatement]
    let aiProposals: [AskAIMemoryStatement]
    let entityRefs: [AgentEvidenceRef]
}

struct AskAIMemoryCandidate: Sendable {
    let turns: [DaybookConversationTurn]
    let turnDigests: [String: String]
    let entityDependencies: [AgentEvidenceDependency]
    let inputDigest: String
    let permissionDigest: String
    let disclosurePolicy: AgentDisclosurePolicy
    /// Only original Q+A; no previous summary is accepted as input.
    var context: String { Self.render(turns) }
    static func render(_ turns: [DaybookConversationTurn]) -> String { turns.map { "TURN \($0.id.uuidString)\nUSER: \($0.question)\nHISTORICAL AI (not current facts): \($0.text)" }.joined(separator: "\n\n") }
}

struct AskAIMemoryBlock: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let summary: AskAIMemorySummary
    let coveredTurnDigests: [String: String]
    let inputDigest: String
    let permissionDigest: String
    let disclosurePolicy: AgentDisclosurePolicy
    let model: String
    // Optional only for decoding pre-dependency v2 blocks. Nonempty original dependencies
    // must match this authoritative metadata at save/load; model-selected refs are presentation.
    var entityDependencies: [AgentEvidenceDependency]? = nil
    var runProvenance: AgentRunProvenance? = nil
    var version = "ask-ai-memory-v2"
    var context: String {
        let groups = [("USER EXPLICIT DECISIONS", summary.explicitDecisions), ("USER CORRECTIONS", summary.corrections), ("UNRESOLVED", summary.unresolved), ("AI PROPOSALS (not adopted unless explicitly stated)", summary.aiProposals), ("TOPICS", summary.topics)]
        return "HISTORICAL SUMMARY (not current facts):\n" + groups.map { $0.0 + ": " + $0.1.map(\.text).joined(separator: "; ") }.joined(separator: "\n")
    }
    static func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func turnDigest(_ turn: DaybookConversationTurn) -> String {
        // JSON sortedKeys canonicalizes maps, but Set encodes as an unordered array.
        // Normalize every persisted Set explicitly while retaining ordered citation/content arrays.
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let data = try! encoder.encode(turn)
        var value = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        var evidence = value["evidence"] as! [String: Any]
        evidence["allowedKinds"] = turn.evidence.allowedKinds.map(\.rawValue).sorted()
        value["evidence"] = evidence
        if let refs = turn.evidenceRefs {
            var encodedRefs = value["evidenceRefs"] as! [[String: Any]]
            for index in refs.indices { encodedRefs[index]["sourceKinds"] = refs[index].sourceKinds.map(\.rawValue).sorted() }
            value["evidenceRefs"] = encodedRefs
        }
        if let provenance = turn.runProvenance {
            var p = value["runProvenance"] as! [String:Any]
            p["domains"] = provenance.domains.map(\.rawValue).sorted(); p["sourceKinds"] = provenance.sourceKinds.map(\.rawValue).sorted()
            var refs = p["refs"] as! [[String:Any]]
            for index in provenance.refs.indices { refs[index]["sourceKinds"] = provenance.refs[index].sourceKinds.map(\.rawValue).sorted() }
            p["refs"] = refs; value["runProvenance"] = p
        }
        let canonical = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }
    static func dependencies(turns: [DaybookConversationTurn]) -> [AgentEvidenceDependency] {
        let all = turns.flatMap { turn in (turn.runProvenance?.dependencies ?? []) + (turn.evidenceRefs ?? []).flatMap { ref in
            [AgentEvidenceDependency(domain: ref.domain, entityID: ref.entityID, revision: ref.revision)] + ref.dependencies
        } }
        return Set(all).sorted {
            ($0.domain.rawValue, $0.entityID, $0.revision) < ($1.domain.rawValue, $1.entityID, $1.revision)
        }
    }
    static func candidate(turns: [DaybookConversationTurn], excluding covered: Set<UUID> = [], permissionDigest: String, budget: AskAIContextBudget, instruction: String = "Summarize only explicit statements with original turn citations.") -> AskAIMemoryCandidate? {
        var selected: [DaybookConversationTurn] = []
        for turn in turns.filter({ $0.completionState == .completed && !covered.contains($0.id) }).prefix(12) {
            let proposed = selected + [turn]
            let context = AskAIMemoryCandidate.render(proposed)
            guard budget.fits(instruction: instruction, content: context) else { break }
            selected = proposed
        }
        guard !selected.isEmpty else { return nil }
        let digests = Dictionary(uniqueKeysWithValues: selected.map { ($0.id.uuidString, turnDigest($0)) })
        let digestText = selected.map { $0.id.uuidString + ":" + digests[$0.id.uuidString]! }.joined(separator: "\n")
        let local = selected.contains { $0.disclosurePolicy == .localOnly }
        return .init(turns: selected, turnDigests: digests, entityDependencies: dependencies(turns: selected), inputDigest: digest(digestText), permissionDigest: permissionDigest, disclosurePolicy: local ? .localOnly : .allowedRemote)
    }
    enum Failure: Error { case invalidSummary }
    static func parse(_ data: Data, candidate: AskAIMemoryCandidate, model: String) throws -> Self {
        guard data.count <= 16000, model.utf8.count <= 300 else { throw Failure.invalidSummary }
        let summary = try JSONDecoder().decode(AskAIMemorySummary.self, from: data)
        let groups = [summary.topics, summary.explicitDecisions, summary.corrections, summary.unresolved, summary.aiProposals]
        let allowed = Set(candidate.turns.map(\.id))
        guard groups.allSatisfy({ $0.count <= 12 && $0.allSatisfy { !$0.text.isEmpty && $0.text.count <= 300 && !$0.turnIDs.isEmpty && Set($0.turnIDs).isSubset(of: allowed) } }), summary.entityRefs.count <= 20 else { throw Failure.invalidSummary }
        let availableRefs = candidate.turns.flatMap { $0.evidenceRefs ?? [] }
        guard summary.entityRefs.allSatisfy({ $0.isValid && availableRefs.contains($0) }) else { throw Failure.invalidSummary }
        return .init(id: UUID(), summary: summary, coveredTurnDigests: candidate.turnDigests, inputDigest: candidate.inputDigest, permissionDigest: candidate.permissionDigest, disclosurePolicy: candidate.disclosurePolicy, model: model, entityDependencies: candidate.entityDependencies,runProvenance:candidate.turns.reduce(into:AgentRunProvenance()) { $0.merge(.consulting($1)) })
    }
}


extension AgentRunProvenance {
    static func consulting(_ turn:DaybookConversationTurn) -> Self {
        var value=turn.runProvenance ?? evidence(turn.evidenceRefs ?? [])
        value.domains.insert(.conversation);value.sourceKinds.formUnion(turn.evidence.allowedKinds)
        if turn.runProvenance == nil && (turn.evidenceRefs ?? []).isEmpty { value.disclosurePolicy = .localOnly }
        value.historyTurnDigests[turn.id.uuidString] = AskAIMemoryBlock.turnDigest(turn)
        return value
    }
}

struct AgentQuestionCapabilities {
    var domains: Set<AgentEvidenceDomain> = []
    var history = false
    init(_ question:String) {
        let q=question.lowercased()
        if ["账","花费","花了","支出","收入","消费","金额","预算","钱","ledger","spend","expense","money"].contains(where:q.contains) { domains.insert(.ledger) }
        if ["灵感","想法","idea"].contains(where:q.contains) { domains.insert(.ideas) }
        if ["人物","联系人","谁","关系","person","people","contact"].contains(where:q.contains) { domains.insert(.people) }
        if ["地点","哪里","去过","place","visit","位置"].contains(where:q.contains) { domains.insert(.places) }
        history=["之前","上次","上一","刚才","历史","第","previous","history","answer"].contains(where:q.contains)
    }
    func usesAgent(question:String,permissions:AgentNotebookPermissions) -> Bool {
        if !domains.isEmpty || history { return true }
        let q=question.lowercased()
        let discovery=["查找","找找","寻找","哪些","有什么","show","find","what"].contains(where:q.contains)
        return discovery && !DaybookRetrieval.isAggregateQuestion(question) && !permissions.allowedDomains.subtracting([.timeline,.conversation]).isEmpty
    }
}

enum AgentToolPageBudget {
    static func prefix(_ text:String,tokens:Int) -> String {
        let chars=Array(text);var lo=0,hi=chars.count
        while lo<hi { let mid=(lo+hi+1)/2;if AskAITokenEstimator.estimate(String(chars.prefix(mid))) <= max(1,tokens) {lo=mid}else{hi=mid-1} }
        return String(chars.prefix(lo))
    }
}

/// Deliberately small compatibility grammar. Unrecognized qualifiers never become all-time totals.
enum AskAILedgerFilterResolver {
    enum Failure: Error { case unresolved }
    static func resolve(_ question:String,now:Date,calendar:Calendar = .current) throws -> [String:Any] {
        var remaining=question.lowercased(),args:[String:Any]=["groupBy":"none","limit":1]
        func consume(_ values:[String]) -> Bool { var found=false;for value in values.sorted(by:{$0.count>$1.count}) where remaining.contains(value) { remaining=remaining.replacingOccurrences(of:value,with:" ");found=true };return found }
        let format=DateFormatter();format.calendar=calendar;format.timeZone=calendar.timeZone;format.locale=Locale(identifier:"en_US_POSIX");format.dateFormat="yyyy-MM-dd"
        if consume(["本月","这个月","this month"]) {
            let start=calendar.dateInterval(of:.month,for:now)!.start;args["start"]=format.string(from:start);args["end"]=format.string(from:calendar.date(byAdding:.month,value:1,to:start)!)
        } else if consume(["上个月","上月","last month"]) {
            let end=calendar.dateInterval(of:.month,for:now)!.start;args["start"]=format.string(from:calendar.date(byAdding:.month,value:-1,to:end)!);args["end"]=format.string(from:end)
        } else if consume(["今天","today","昨天","yesterday"]) {
            let yesterday=question.contains("昨天") || question.lowercased().contains("yesterday")
            let start=calendar.date(byAdding:.day,value:yesterday ? -1 : 0,to:calendar.startOfDay(for:now))!;args["start"]=format.string(from:start);args["end"]=format.string(from:calendar.date(byAdding:.day,value:1,to:start)!)
        } else {
            let expression=try NSRegularExpression(pattern:#"(\d{4})[-年](\d{1,2})(?:月)?(?![-\d])"#)
            if let m=expression.firstMatch(in:remaining,range:NSRange(remaining.startIndex...,in:remaining)),let range=Range(m.range,in:remaining),let y=Range(m.range(at:1),in:remaining),let mon=Range(m.range(at:2),in:remaining),let year=Int(remaining[y]),let month=Int(remaining[mon]),(1...12).contains(month),let start=calendar.date(from:DateComponents(year:year,month:month,day:1)) {
                args["start"]=format.string(from:start);args["end"]=format.string(from:calendar.date(byAdding:.month,value:1,to:start)!);remaining.removeSubrange(range)
            }
        }
        let income=consume(["收入","income"]),expense=consume(["支出","花费","花了","消费","spend","expense"])
        if income != expense { args["direction"]=income ? "income" : "expense" }
        if consume(["多少钱","花多少","花钱"]) { args["direction"]="expense" }
        let categories=["餐饮","交通","购物","住房","娱乐","医疗","教育","旅行","food","transport"]
        let matched=categories.filter { remaining.contains($0) };guard matched.count<=1 else { throw Failure.unresolved }
        if let category=matched.first { args["category"]=category;_ = consume([category]) }
        let currencies:[(String,[String])]=[("CNY",["人民币","rmb","cny"]),("USD",["美元","usd"]),("EUR",["欧元","eur"]),("GBP",["英镑","gbp"]),("JPY",["日元","jpy"])]
        var codes:[String]=[];for (code,aliases) in currencies { if consume(aliases) { codes.append(code) } };guard codes.count<=1 else { throw Failure.unresolved };if let code=codes.first {args["currency"]=code}
        if consume(["按分类","分类统计","by category"]) {args["groupBy"]="category"}
        if consume(["按月份","按月","by month"]) {args["groupBy"]="month"}
        if consume(["按日期","按日","by date"]) {args["groupBy"]="date"}
        _=consume(["所有时间","全部","总共","合计","总计","总额","金额","统计","记账","账目","账","钱","我的","我","请问","请","帮我","有多少","是多少","多少","有哪些","多少笔","的","了","是","吗","呢","all time","ledger","total","how much","what","my","is"])
        guard remaining.trimmingCharacters(in:.whitespacesAndNewlines.union(.punctuationCharacters)).isEmpty else { throw Failure.unresolved }
        return args
    }
}

import Foundation

@main
struct AskAIRuntimeSmoke {
    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw TestFailure(message: message) }
    }
    struct TestFailure: Error { let message: String }
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ask-ai-runtime-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("history.json")
        let db = try DaybookDatabase(url: root.appendingPathComponent("fixture.sqlite3"))
        let store = DaybookConversationStore(url: legacy, database: db)
        let day = Date(timeIntervalSinceReferenceDate: 800000000)
        let evidence = DaybookEvidenceSnapshot(records: [], dayStart: day, dayEnd: day.addingTimeInterval(86400), allowedKinds: [.voice])
        let turn = DaybookConversationTurn(id: UUID(), question: "上周项目怎样？", text: "OLD_ASSISTANT_FACT_MUST_NOT_BECOME_EVIDENCE", generated: true, provider: "fixture", evidence: evidence, sources: [], scopeDescription: "fixture", state: .completed, createdAt: day)
        try store.saveTurn(turn, day: day)
        let source = DaybookRetrieval.Source(id: UUID(), number: 1, title: "当前证据", capturedAt: day, kind: .voice, snippet: "项目已交付 CURRENT_EVIDENCE", truncated: false)
        let context = try AskAIContextBuilder.build(question: String(repeating: "中英文mix ", count: 35), history: [turn], evidence: [source], instruction: "Use current evidence only", tools: String(repeating: "schema ", count: 100))
        try check(context.estimatedInputTokens <= 2200, "mixed Chinese/English must fit total budget")
        try check(context.content.contains("CURRENT_EVIDENCE"), "current evidence must survive history trimming")
        try check(context.content.contains("OLD_ASSISTANT_FACT") && context.content.contains("not current facts"), "complete original answer must survive as historical context, not current facts")
        let memory = AskAIRollingMemory.build(turns: [turn], dependencyDigest: "permissions-v1")
        try check(memory.questions == [turn.question] && memory.coveredCursor != nil, "memory includes user intent and coverage cursor")
        try check(memory == AskAIRollingMemory.build(turns: [turn], dependencyDigest: "permissions-v1"), "memory is deterministic")
        try check(context.content.contains("capturedAt=") && context.content.contains("kind=voice"), "evidence retains temporal and kind identity")
        let numbered = DaybookRetrieval.Source(id: source.id, number: 4, title: source.title, capturedAt: day, kind: .voice, snippet: source.snippet, truncated: false)
        let numberedContext = try AskAIContextBuilder.build(question: "项目？", history: [], evidence: [numbered], instruction: "ground facts")
        try check(numberedContext.sources.first?.number == 4 && numberedContext.content.contains("[4]"), "existing source numbers remain stable")
        do {
            _ = try AskAIContextBuilder.build(question: "项目？", history: [], evidence: [source], instruction: "", budget: .init(windowTokens: 160, inputLimit: 140, outputReserve: 0))
            throw TestFailure(message: "nonempty evidence failed to fit but builder accepted")
        } catch AskAIContextBuilder.Failure.noEvidence { }
        let runtime = AskAIRuntimeStore(conversationStore: store)
        let generation = try await runtime.cacheGeneration()
        let first = try await runtime.startAttempt(turnID: turn.id, provider: "local", model: "fixture", configRevision: "1")
        let second = try await runtime.startAttempt(turnID: turn.id, provider: "local", model: "fixture", configRevision: "1")
        try check(first.attempt == 1 && second.attempt == 2, "attempt numbers are monotonic")
        do { try await runtime.completeAttempt(runID: first.id, turn: turn); throw TestFailure(message: "stale attempt published") }
        catch AskAIRuntimeStore.Failure.staleAttempt { }
        let completed = DaybookConversationTurn(id: turn.id, question: turn.question, text: "new answer", generated: true, provider: "local", evidence: evidence, sources: [], scopeDescription: "fixture", state: .completed, createdAt: day.addingTimeInterval(400))
        let before = try db.query("SELECT day,position,created_at FROM conversation_turns WHERE id = ?", [.text(turn.id.uuidString)])
        try await runtime.completeAttempt(runID: second.id, turn: completed)
        let after = try db.query("SELECT day,position,created_at FROM conversation_turns WHERE id = ?", [.text(turn.id.uuidString)])
        try check(before == after, "retry must preserve original day position and created_at")
        try check(try store.load().first?.turns.first?.text == "new answer", "successful attempt publishes answer")
        let savedRun = try await runtime.loadRun(id: second.id)
        try check(savedRun?.state == .completed, "successful run and answer agree")
        let failedRetry = try await runtime.startAttempt(turnID: turn.id, provider: "local", model: "fixture", configRevision: "1")
        let invalid = DaybookConversationTurn(id: turn.id, question: turn.question, text: String(repeating: "X", count: 8001), generated: true, provider: "fixture", evidence: evidence, sources: [], scopeDescription: "fixture", state: .completed)
        do { try await runtime.completeAttempt(runID: failedRetry.id, turn: invalid); throw TestFailure(message: "invalid answer published") }
        catch DaybookConversationFailure.save { }
        try check(try store.runtimeTurn(id: turn.id)?.text == "new answer", "failed publication rolls back answer")
        try await runtime.interruptAttempt(runID: failedRetry.id, state: .failed, errorCode: "fixture_failure")
        try check(try store.runtimeTurn(id: turn.id)?.text == "new answer", "failed retry preserves prior success")
        for offset in 1...12 {
            let item = DaybookConversationTurn(id: UUID(), question: "question \(offset)", text: "answer", generated: false, provider: "", evidence: evidence, sources: [], scopeDescription: "", state: .completed, createdAt: day.addingTimeInterval(Double(offset)))
            try store.saveTurn(item, day: day)
        }
        let runtimeHistory = try await runtime.runtimeHistory(limit: 12)
        try check(runtimeHistory.count == 12 && runtimeHistory.first?.question == "question 1", "worker history ignores ten-turn UI page and returns chronological turns")
        try await runtime.saveMemory(memory, anchorTurnID: turn.id, expectedGeneration: generation)
        let checkpoint = AskAIRuntimeStore.Checkpoint(anchorTurnID: turn.id, providerConfigDigest: "config", formatVersion: "1", toolVersion: "1", promptVersion: "1", inputDigest: "input", permissionDigest: "permissions-v1", sourceDigest: "sources", payload: Data("stable snapshot".utf8))
        try await runtime.saveCheckpoint(checkpoint, expectedGeneration: generation)
        let reopened = AskAIRuntimeStore(conversationStore: DaybookConversationStore(url: legacy, database: try DaybookDatabase(url: db.url)))
        let loadedMemory = try await reopened.loadMemory(dependencyDigest: "permissions-v1")
        try check(loadedMemory == memory, "memory survives reopen")
        let loadedCheckpoint = try await reopened.loadCheckpoint(providerConfigDigest: "config", permissionDigest: "permissions-v1", sourceDigest: "sources")
        try check(loadedCheckpoint == checkpoint, "checkpoint survives reopen")
        let mismatch = try await reopened.loadCheckpoint(providerConfigDigest: "changed", permissionDigest: "permissions-v1", sourceDigest: "sources")
        try check(mismatch == nil, "configuration mismatch discards snapshot")
        let third = try await reopened.startAttempt(turnID: turn.id, provider: "local", model: "fixture", configRevision: "1")
        try await reopened.recordToolCall(runID: third.id, callID: "call-1", toolName: "searchRecords", argsDigest: "digest", arguments: "{}", state: "completed", resultReferences: ["source-1"], elapsedMilliseconds: 4)
        try await reopened.recordEvidence(runID: third.id, id: "e1", sourceIdentity: "source-1", sourceVersion: "1", queryScope: "today/voice", excerpt: "bounded excerpt", permissionDigest: "permissions-v1")
        try await reopened.saveCheckpoint(checkpoint, expectedGeneration: generation)
        try await reopened.updateAttempt(runID: third.id, state: .toolRunning, providerRequests: 2, toolCalls: 1)
        do { try await reopened.updateAttempt(runID: third.id, state: .generating, providerRequests: 1, toolCalls: 1); throw TestFailure(message: "counters regressed") }
        catch AskAIRuntimeStore.Failure.invalidMetadata { }
        do { try await reopened.recordEvidence(runID: first.id, id: "stale", sourceIdentity: "source", sourceVersion: "1", queryScope: "today", excerpt: "stale", permissionDigest: "permissions-v1"); throw TestFailure(message: "stale evidence accepted") }
        catch AskAIRuntimeStore.Failure.staleAttempt { }
        try await reopened.interruptUnfinishedAttempts()
        let interrupted = try await reopened.loadRun(id: third.id)
        try check(interrupted?.state == .interrupted, "restart interrupts unfinished runs")
        let privacyStore = DaybookConversationStore(url: legacy, database: try DaybookDatabase(url: db.url))
        try privacyStore.redactDisallowed([.voice])
        try check(try db.query("SELECT * FROM ask_ai_memory").count == 1, "unchanged allowed permissions must retain caches")
        try privacyStore.redactDisallowed([])
        for table in ["ask_ai_evidence", "ask_ai_tool_calls", "ask_ai_memory", "ask_ai_checkpoints"] {
            try check(try db.query("SELECT * FROM " + table).isEmpty, "redaction removes permission-dependent caches: " + table)
        }
        do { try await reopened.saveCheckpoint(checkpoint, expectedGeneration: generation); throw TestFailure(message: "late revoked checkpoint restored") }
        catch AskAIRuntimeStore.Failure.staleAttempt { }
        do { try await reopened.saveMemory(memory, anchorTurnID: turn.id, expectedGeneration: generation); throw TestFailure(message: "late revoked memory restored") }
        catch AskAIRuntimeStore.Failure.staleAttempt { }
        // A fresh valid anchor proves FK cleanup without restoring redacted data.
        let fresh = DaybookConversationTurn(id: UUID(), question: "fresh", text: "fresh", generated: false, provider: "", evidence: evidence, sources: [], scopeDescription: "", state: .completed, createdAt: day)
        try store.saveTurn(fresh, day: day)
        let currentGeneration = try await reopened.cacheGeneration()
        try await reopened.saveMemory(memory, anchorTurnID: fresh.id, expectedGeneration: currentGeneration)
        let pending = DaybookConversationTurn(id: UUID(), question: "pending", text: "", generated: false, provider: "", evidence: evidence, sources: [], scopeDescription: "", state: .pending, createdAt: day)
        try store.saveTurn(pending, day: day)
        let pendingRun = try await reopened.startAttempt(turnID: pending.id, provider: "local", model: "fixture", configRevision: "1")
        try await reopened.clearPermissionDependentCaches()
        try check(try store.runtimeTurn(id: pending.id)?.completionState == .cancelled, "cache invalidation settles pending conversation row")
        let cancelledRun = try await reopened.loadRun(id: pendingRun.id)
        try check(cancelledRun?.state == .interrupted, "cache invalidation settles run")
        try await reopened.saveMemory(memory, anchorTurnID: fresh.id, expectedGeneration: try await reopened.cacheGeneration())
        try store.reset()
        try check(try db.query("SELECT * FROM ask_ai_runs").isEmpty, "reset cascades runs")
        try check(try db.query("SELECT * FROM ask_ai_memory").isEmpty, "reset cascades anchors")
        // Phase 2 policy: cloud uses its configured window; the estimator margin is charged once.
        for (window, reserve, rounds) in [(4096,512,1), (16384,1024,4), (32768,2048,4)] {
            let policy = AskAIContextBudget.policy(window: window, isCustom: true)
            try check(policy.initial.windowTokens == window && policy.working.outputReserve == reserve && policy.recentRoundCount == rounds, "model-aware window policy")
            try check(policy.working.inputLimit + reserve + 128 <= window, "working budget preserves output and continuation reserve")
        }
        try check(AskAIContextBudget.policy(window: nil, isCustom: true).working.windowTokens == 4096, "unknown model is conservative")
        try check(AskAIContextBudget.policy(window: 128000, isCustom: false).working.windowTokens == 4096, "Apple window stays conservative")
        try check(AskAIContextBudget.policy(window: 128000, isCustom: true).working.windowTokens == 32768, "application cap")
        let raw = 64 + AskAITokenEstimator.estimate("mixed 中文")
        try check(AskAIContextBudget().estimatedInput(instruction: "", content: "mixed 中文") == raw + (raw + 3) / 4, "25 percent once")
        try check(AgentNotebookPermissions().allowedDomains == [.timeline,.conversation], "new notebook permissions default off")
        var originals: [DaybookConversationTurn] = []
        for index in 0..<55 {
            let t = DaybookConversationTurn(id: UUID(), question: "original question \(index)", text: index == 0 ? "UNIQUE_OLD_ANSWER_SEARCH" : "1. first \(index)\n2. exact original second \(index)\n3. third", generated: true, provider: "fixture", evidence: evidence, sources: [], scopeDescription: "", state: .completed, createdAt: day.addingTimeInterval(Double(index)))
            try store.saveTurn(t, day: day); originals.append(t)
        }
        let scope = AgentQueryScope(domains: [.timeline,.conversation,.people,.ledger], allowedKinds: [.voice])
        let allHistoryPage = try await runtime.searchConversationHistory(query: "original", scope: scope)
        try check(allHistoryPage.turns.count == 10 && allHistoryPage.hasMore, "history search pages at ten")
        let secondHistoryPage = try await runtime.searchConversationHistory(query: "original", scope: scope, before: allHistoryPage.cursor)
        try check(Set(secondHistoryPage.turns.map(\.id)).isDisjoint(with: allHistoryPage.turns.map(\.id)), "history cursor does not repeat IDs")
        let ancient = try await runtime.searchConversationHistory(query: "UNIQUE_OLD_ANSWER_SEARCH", scope: scope)
        try check(ancient.turns.map(\.id) == [originals[0].id], "answer search finds original beyond forty recent turns")
        let originalPage = try await runtime.readConversationTurn(id: originals[54].id, scope: scope, offset: 0, limit: 4000)
        try check(originalPage?.answer == originals[54].text && originalPage?.answer.contains("2. exact original second 54") == true, "read returns exact numbered original answer")
        let partial = try await runtime.readConversationTurn(id: originals[54].id, scope: scope, offset: 0, limit: 12)
        let remainder = try await runtime.readConversationTurn(id: originals[54].id, scope: scope, offset: partial!.nextOffset!, limit: 4000)
        try check(partial!.answer + remainder!.answer == originals[54].text, "character cursor reconstructs original exactly")
        let largeContext = try AskAIContextBuilder.build(question: "expand point 2", history: Array(originals.suffix(4)), evidence: [], instruction: "context", budget: AskAIContextBudget.policy(window: 16384, isCustom: true).initial)
        try check(largeContext.historyTurnIDs.count == 4 && largeContext.content.contains("2. exact original second 54"), "large model includes four complete original Q+A")
        let legacyTurnData = try JSONEncoder().encode(originals[0])
        let decodedLegacyTurn = try JSONDecoder().decode(DaybookConversationTurn.self, from: legacyTurnData)
        try check(decodedLegacyTurn.evidenceRefs == nil && decodedLegacyTurn.notebookPermissions == nil, "v1 turn archive decodes without new metadata")
        let legacyMemoryData = try JSONEncoder().encode(memory)
        try check(try JSONDecoder().decode(AskAIRollingMemory.self, from: legacyMemoryData) == memory, "v1 rolling memory payload remains compatible")
        let generation2 = try await runtime.cacheGeneration()
        let candidate = AskAIMemoryBlock.candidate(turns: originals, permissionDigest: "stable-permissions", budget: AskAIContextBudget.policy(window: 32768, isCustom: true).working)!
        try check(candidate.turns.count == 12 && candidate.context.contains("HISTORICAL AI"), "bounded summary selects original Q+A, not previous summaries")
        let summary = AskAIMemorySummary(topics: [], explicitDecisions: [], corrections: [], unresolved: [.init(text: "Original question remains unresolved", turnIDs: [originals[1].id])], aiProposals: [], entityRefs: [])
        let block = try AskAIMemoryBlock.parse(JSONEncoder().encode(summary), candidate: candidate, model: "synthetic")
        try await runtime.saveMemoryBlock(block, expectedGeneration: generation2)
        let reopenedBlocks = try await reopened.loadMemoryBlocks(permissionDigest: "stable-permissions")
        try check(reopenedBlocks == [block] && block.disclosurePolicy == .localOnly, "block survives reopen with local-only propagation")
        let badSummary = AskAIMemorySummary(topics: [.init(text: "unsupported", turnIDs: [UUID()])], explicitDecisions: [], corrections: [], unresolved: [], aiProposals: [], entityRefs: [])
        do { _ = try AskAIMemoryBlock.parse(JSONEncoder().encode(badSummary), candidate: candidate, model: "synthetic"); throw TestFailure(message: "foreign turn summary accepted") } catch AskAIMemoryBlock.Failure.invalidSummary { }
        let middle = originals[4]
        try store.saveTurn(.init(id: middle.id, question: middle.question, text: "corrected original answer", generated: true, provider: "fixture", evidence: evidence, sources: [], scopeDescription: "", state: .completed, createdAt: middle.createdAt), day: day)
        let invalidated = try await runtime.loadMemoryBlocks(permissionDigest: "stable-permissions")
        try check(invalidated.isEmpty, "reanswer of middle covered turn invalidates block while last anchor exists")
        let currentOriginals = try await runtime.runtimeHistory(limit: 100)
        let candidate2 = AskAIMemoryBlock.candidate(turns: currentOriginals, permissionDigest: "stable-permissions", budget: AskAIContextBudget.policy(window: 32768, isCustom: true).working)!
        let block2 = try AskAIMemoryBlock.parse(JSONEncoder().encode(summary), candidate: candidate2, model: "synthetic")
        try await runtime.saveMemoryBlock(block2, expectedGeneration: generation2)
        try db.execute("DELETE FROM conversation_turns WHERE id=?", [.text(originals[5].id.uuidString)])
        let deletedBlock = try await runtime.loadMemoryBlocks(permissionDigest: "stable-permissions")
        try check(deletedBlock.isEmpty, "delete of middle covered turn invalidates block")
        var typed = originals[54]
        typed.evidenceRefs = [
            .init(domain: .people, entityID: "manual:person-1", number: 2, title: "Person", snippet: "profile", revision: "r1", disclosurePolicy: .allowedRemote),
            .init(domain: .places, entityID: "grid-v1:cell", number: 7, title: "Place", snippet: "visit", revision: "r2", disclosurePolicy: .localOnly),
            .init(domain: .people, entityID: "ios:contact-2", number: 9, title: "Contact", snippet: "profile", revision: "r3", disclosurePolicy: .allowedRemote)]
        typed.notebookPermissions = .init(allowIdeas: false, allowLedger: false, allowPeople: true, allowPlaces: true)
        let typedRun = try await runtime.startAttempt(turnID: typed.id, provider: "fixture", model: "fixture", configRevision: "2")
        try await runtime.completeAttempt(runID: typedRun.id, turn: typed)
        let loadedTyped = try await reopened.runtimeTurn(id: typed.id)
        try check(loadedTyped?.turn.evidenceRefs == typed.evidenceRefs && loadedTyped?.turn.notebookPermissions == typed.notebookPermissions, "typed sidecar and original turn publish atomically and reopen")
        try check(try store.loadPage().turns.last?.evidenceRefs?.map(\.number) == [2,7,9], "UI page preserves mixed numeric citations")
        let deniedRemote = try await runtime.readConversationTurn(id: typed.id, scope: .init(domains: Set(AgentEvidenceDomain.allCases), allowedKinds: [.voice], destination: .allowedRemote))
        try check(deniedRemote == nil, "local-only history cannot be read for remote destination")
        try store.redactDisallowed([.voice], notebookPermissions: .init())
        try check(try store.runtimeTurn(id: typed.id)?.completionState == .redacted, "notebook revoke removes history answer and typed refs")
        try check(try db.query("SELECT * FROM ask_ai_turn_evidence_v2 WHERE turn_id=?", [.text(typed.id.uuidString)]).isEmpty, "revocation removes typed sidecar")
        do { try await runtime.saveMemoryBlock(block2, expectedGeneration: generation2); throw TestFailure(message: "late revoked block restored") } catch AskAIRuntimeStore.Failure.staleAttempt { }
        let beforeResetGeneration = try await runtime.cacheGeneration()
        try store.reset()
        let afterResetGeneration = try await runtime.cacheGeneration()
        try check(afterResetGeneration > beforeResetGeneration, "reset invalidates late cache write generation")

        // Review regressions: canonical nested sets and complete, durably fenced entity dependencies.
        let multiEvidence = DaybookEvidenceSnapshot(records: [], dayStart: day, dayEnd: day.addingTimeInterval(86400), allowedKinds: [.voice,.image,.location])
        var multiTurn = DaybookConversationTurn(id: UUID(), question: "What did the person suggest?", text: "Historical person proposal", generated: true, provider: "fixture", evidence: multiEvidence, sources: [], scopeDescription: "", state: .completed, createdAt: day)
        multiTurn.notebookPermissions = .init(allowPeople: true)
        multiTurn.evidenceRefs = [.init(domain: .people, entityID: "manual:canonical", number: 3, title: "Person", snippet: "Original source", revision: "r1", dependencies: [.init(domain: .ideas, entityID: "source-parent", revision: "parent-r1")], sourceKinds: [.image,.voice,.location])]
        let canonicalDigest = AskAIMemoryBlock.turnDigest(multiTurn)
        for _ in 0..<64 {
            let roundTripped = try JSONDecoder().decode(DaybookConversationTurn.self, from: JSONEncoder().encode(multiTurn))
            try check(roundTripped == multiTurn && AskAIMemoryBlock.turnDigest(roundTripped) == canonicalDigest, "equal multi-kind decoded turns have canonical stable digests")
        }
        try store.saveTurn(multiTurn, day: day)
        let reviewGeneration = try await runtime.cacheGeneration()
        let reviewBudget = AskAIContextBudget.policy(window: 32768, isCustom: true).working
        let omittedRefsSummary = AskAIMemorySummary(topics: [.init(text: "Historical person proposal", turnIDs: [multiTurn.id])], explicitDecisions: [], corrections: [], unresolved: [], aiProposals: [], entityRefs: [])
        let multiCandidate = AskAIMemoryBlock.candidate(turns: [multiTurn], permissionDigest: "review", budget: reviewBudget)!
        let omittedRefsBlock = try AskAIMemoryBlock.parse(JSONEncoder().encode(omittedRefsSummary), candidate: multiCandidate, model: "synthetic")
        try await runtime.saveMemoryBlock(omittedRefsBlock, expectedGeneration: reviewGeneration)
        let reviewReopened = AskAIRuntimeStore(conversationStore: DaybookConversationStore(url: legacy, database: try DaybookDatabase(url: db.url)))
        let multiReopened = try await reviewReopened.loadMemoryBlocks(permissionDigest: "review")
        try check(multiReopened == [omittedRefsBlock], "multi-kind turn memory survives DB decode and reopened store")
        do {
            try db.transaction {
                try AskAIRuntimeStore.recordMemoryDependencyChange(db, domain: .ideas, entityID: "source-parent", currentRevision: "parent-r2")
                throw TestFailure(message: "synthetic notebook transaction rollback")
            }
        } catch is TestFailure { }
        let afterMutationRollback = try await reviewReopened.loadMemoryBlocks(permissionDigest: "review")
        try check(afterMutationRollback == [omittedRefsBlock], "notebook transaction rollback also rolls back durable fence and invalidation")
        try await runtime.invalidateMemoryDependency(domain: .ideas, entityID: "source-parent", currentRevision: "parent-r2")
        let afterOmittedDependencyMutation = try await reviewReopened.loadMemoryBlocks(permissionDigest: "review")
        try check(afterOmittedDependencyMutation.isEmpty, "all original source dependencies invalidate despite omitted model entity refs")
        do { try await reviewReopened.saveMemoryBlock(omittedRefsBlock, expectedGeneration: reviewGeneration); throw TestFailure(message: "invalidated block retry resurrected stale entity revision") } catch AskAIRuntimeStore.Failure.staleAttempt { }
        // New generated block ID still cannot publish old source revision after mutation before first save.
        let lateBlock = try AskAIMemoryBlock.parse(JSONEncoder().encode(omittedRefsSummary), candidate: multiCandidate, model: "synthetic")
        do { try await reviewReopened.saveMemoryBlock(lateBlock, expectedGeneration: reviewGeneration); throw TestFailure(message: "late first save bypassed durable current revision") } catch AskAIRuntimeStore.Failure.staleAttempt { }
        // Explicitly invalidated block IDs remain invalid even if the source later matches again.
        try await runtime.invalidateMemoryDependency(domain: .ideas, entityID: "source-parent", currentRevision: "parent-r1")
        do { try await reviewReopened.saveMemoryBlock(omittedRefsBlock, expectedGeneration: reviewGeneration); throw TestFailure(message: "invalid block ID was resurrected after revision returned") } catch AskAIRuntimeStore.Failure.staleAttempt { }
        // A deletion tombstone must survive reopen and fence even never-persisted candidate blocks.
        try await runtime.invalidateMemoryDependency(domain: .people, entityID: "manual:canonical", currentRevision: nil)
        let tombstoneReopened = AskAIRuntimeStore(conversationStore: DaybookConversationStore(url: legacy, database: try DaybookDatabase(url: db.url)))
        do { try await tombstoneReopened.saveMemoryBlock(lateBlock, expectedGeneration: reviewGeneration); throw TestFailure(message: "late first save bypassed durable deletion tombstone") } catch AskAIRuntimeStore.Failure.staleAttempt { }

        // Defense in depth: load must check durable source state even if a stale cache row says valid.
        try db.execute("UPDATE ask_ai_memory_blocks SET status='valid' WHERE id=?", [.text(omittedRefsBlock.id.uuidString)])
        let staleValidLoad = try await tombstoneReopened.loadMemoryBlocks(permissionDigest: "review")
        try check(staleValidLoad.isEmpty, "load checks durable deletion even with stale valid cache status")
        print("Ask AI runtime: bounded context, deterministic memory, migration/reopen, stale attempts, atomic retry, interruption, redaction and reset passed")
    }
}

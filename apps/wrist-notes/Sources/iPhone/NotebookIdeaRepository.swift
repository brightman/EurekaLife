import Foundation

final class NotebookIdeaRepository {
    private let db: DaybookDatabase
    private let assets: FlashCaptureRepository
    init(database: DaybookDatabase) throws {
        db=database; assets=try FlashCaptureRepository(database:database)
        try db.migrate("notebook-idea-drafts-v1") {
            try db.execute("CREATE TABLE notebook_idea_drafts(id TEXT PRIMARY KEY,created_at REAL NOT NULL,payload BLOB NOT NULL)")
        }
    }
    /// Plain merge uses the same source snapshots as AI recreation, without an AI call.
    func merge(id: UUID, seeds: [FlashAsset], title: String, text: String, now: Date = .now) throws -> FlashAsset {
        guard (2...10).contains(seeds.count), Set(seeds.map(\.id)).count == seeds.count,
              !seeds.contains(where: { $0.id == id || $0.kind != .idea || $0.revoked }) else {
            throw ActionFailure.invalid("请选择 2 至 10 条未删除的不同灵感。")
        }
        let parents=seeds.map(FlashIdeaSource.init)
        return try db.transaction {
            try Task.checkCancellation()
            if let saved=try assets.asset(id) {
                guard !saved.revoked, saved.source.recordingKind == "merged", saved.parentIdeas == parents,
                      saved.title == title, saved.text == text else { throw ActionFailure.changed }
                return saved
            }
            for seed in seeds { guard try assets.asset(seed.id) == seed else { throw ActionFailure.changed } }
            let source=ActionSource(id:id,title:"合并灵感",quote:text,capturedAt:now,timeZoneID:TimeZone.current.identifier,recordingKind:"merged",timeZoneKnown:true)
            var result=FlashAsset(kind:.idea,title:title,text:text,source:source)
            result.id=id; result.origin = .manual; result.parentIdeas=parents
            result.requiresLocalAI=seeds.contains { $0.requiresLocalAI == true || $0.source.device == "EurekaRing" || $0.parentIdeas?.contains { $0.source.device == "EurekaRing" } == true }
            return try assets.save(result)
        }
    }
    func save(_ draft: NotebookIdeaDraft) throws {
        _=try NotebookIdeaGeneration.context(draft.seeds,direction:draft.direction)
        guard (1...3).contains(draft.candidates.count) else { throw ActionFailure.invalid("候选灵感数量无效。") }
        guard Set(draft.candidates.map(\.id)).count == draft.candidates.count,
              draft.candidates.allSatisfy({ !$0.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.title.count <= 200 && !$0.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.text.count <= 4000 }) else {
            throw ActionFailure.invalid("候选灵感内容无效。")
        }
        try Task.checkCancellation()
        try db.transaction {
            try Task.checkCancellation()
            guard try db.query("SELECT COUNT(*) AS count FROM notebook_idea_drafts").first?.requiredInt("count") ?? 0 < 50 else {
                throw ActionFailure.invalid("已有 50 份草稿，请先处理或丢弃旧草稿后再生成。")
            }
            for seed in draft.seeds { guard try assets.asset(seed.id) == seed else { throw ActionFailure.changed } }
            try Task.checkCancellation()
            try db.execute("INSERT INTO notebook_idea_drafts(id,created_at,payload) VALUES(?,?,?)",[.text(draft.id.uuidString),.real(draft.createdAt.timeIntervalSinceReferenceDate),try DaybookDatabase.json(draft)])
        }
    }
    func drafts() throws -> [NotebookIdeaDraft] {
        try db.query("SELECT payload FROM notebook_idea_drafts ORDER BY created_at DESC LIMIT 50").map { try DaybookDatabase.decode(NotebookIdeaDraft.self,$0["payload"]) }
    }
    func discard(_ id: UUID) throws { try db.execute("DELETE FROM notebook_idea_drafts WHERE id=?",[.text(id.uuidString)]) }
    /// Both the new asset and accepted marker commit together, including a retry after interruption.
    func accept(draftID: UUID, candidateIDs: Set<UUID>, now: Date = .now) throws -> [FlashAsset] {
        try db.transaction {
            guard let row=try db.query("SELECT payload FROM notebook_idea_drafts WHERE id=?",[.text(draftID.uuidString)]).first else { throw ActionFailure.changed }
            var draft=try DaybookDatabase.decode(NotebookIdeaDraft.self,row["payload"])
            guard !candidateIDs.isEmpty, candidateIDs.isSubset(of:Set(draft.candidates.map(\.id))) else { throw ActionFailure.invalid("请选择有效的候选灵感。") }
            var saved:[FlashAsset]=[]
            for candidate in draft.candidates where candidateIDs.contains(candidate.id) && !draft.savedCandidateIDs.contains(candidate.id) {
                let source=ActionSource(id:candidate.id,title:"AI 再创作",quote:candidate.text,capturedAt:now,timeZoneID:TimeZone.current.identifier,recordingKind:"generated",timeZoneKnown:true)
                var asset=FlashAsset(kind:.idea,title:candidate.title,text:candidate.text,source:source)
                asset.id=candidate.id; asset.origin = .generated; asset.parentIdeas=draft.seeds.map(FlashIdeaSource.init)
                asset.requiresLocalAI=draft.seeds.contains { $0.requiresLocalAI == true || $0.source.device == "EurekaRing" || $0.parentIdeas?.contains { $0.source.device == "EurekaRing" } == true }
                saved.append(try assets.save(asset)); draft.savedCandidateIDs.insert(candidate.id)
            }
            try db.execute("UPDATE notebook_idea_drafts SET payload=? WHERE id=?",[try DaybookDatabase.json(draft),.text(draftID.uuidString)])
            return saved
        }
    }
}

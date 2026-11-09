import CryptoKit
import Foundation

/// Only a digest of the complete allowed scope is retained, never a duplicate of raw record bodies.
struct DaybookEvidenceSnapshot: Codable, Equatable, Sendable {
    let dayStart: Date
    let dayEnd: Date
    let allowedKinds: Set<DayRecord.Kind>
    let fingerprint: String
    var speakerContactID: String? = nil
    var speakerFingerprint: String? = nil

    init(records: [DayRecord], dayStart: Date, dayEnd: Date, allowedKinds: Set<DayRecord.Kind>, speakerContactID:String? = nil, speakerFingerprint:String? = nil) {
        self.dayStart = dayStart; self.dayEnd = dayEnd; self.allowedKinds = allowedKinds
        self.speakerContactID=speakerContactID; self.speakerFingerprint=speakerFingerprint
        let scoped = DayRecord.evidenceRecords(records, scope: DateInterval(start:dayStart,end:dayEnd)).filter { allowedKinds.contains($0.kind) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        // DayRecord is an entirely Codable value; nonfinite numbers have an explicit stable encoding.
        let data = try! encoder.encode(scoped)
        fingerprint = speakerFingerprint ?? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func isCurrent(records: [DayRecord], allowedKinds: Set<DayRecord.Kind>) -> Bool {
        // A persisted speaker fingerprint cannot be checked against the current SQLite
        // contact links here. Only DaybookAssistantModel has the repository needed to do
        // that check; generic retrieval must never reuse speaker answers as prior context.
        if speakerContactID != nil { return false }
        return self.allowedKinds == allowedKinds && self == Self(records: records, dayStart: dayStart, dayEnd: dayEnd, allowedKinds: allowedKinds)
    }
}

struct DaybookConversationTurn: Codable, Equatable, Identifiable, Sendable {
    enum State: String, Codable, Sendable { case pending, completed, cancelled, failed, redacted }
    let id: UUID
    let question: String
    let text: String
    let generated: Bool
    let provider: String
    let evidence: DaybookEvidenceSnapshot
    let sources: [DaybookRetrieval.Source]
    let scopeDescription: String
    // Original user references are scoped to the preceding displayed answer, not this turn's new labels.
    // Optional for decoding version-1 archives written before identity-aware user references.
    var questionReferenceIDs: [Int: UUID]? = nil
    var state: State? = nil
    var createdAt: Date? = nil
    var evidenceRefs: [AgentEvidenceRef]? = nil
    var notebookPermissions: AgentNotebookPermissions? = nil
    var runProvenance: AgentRunProvenance? = nil
    var disclosurePolicy: AgentDisclosurePolicy {
        // Missing metadata is conservatively local-only, including legacy histories.
        if let runProvenance { return runProvenance.disclosurePolicy }
        guard let refs = evidenceRefs, !refs.isEmpty else { return .localOnly }
        return refs.contains { $0.disclosurePolicy == .localOnly } ? .localOnly : .allowedRemote
    }
    var completionState: State { state ?? .completed }

    func replacing(text: String, state: State) -> Self {
        Self(id: id, question: question, text: text, generated: false, provider: "", evidence: evidence,
             sources: [], scopeDescription: "", questionReferenceIDs: nil, state: state, createdAt: createdAt)
    }

    func redacted() -> Self {
        replacing(text: "相关资料的读取权限已关闭，回答和引用已移除。你的问题仍保留在历史中。", state: .redacted)
    }

    var referencedSourceIDs: Set<UUID> {
        Set(sources.filter { text.contains("[\($0.number)]") }.map(\.id))
    }
}

struct DaybookConversation: Codable, Equatable, Sendable {
    let day: Date
    var updatedAt: Date
    var turns: [DaybookConversationTurn]
}

enum DaybookConversationFailure: LocalizedError {
    case load, save
    var errorDescription: String? {
        switch self {
        case .load: "无法读取本机对话，原文件已保留。可重试读取，或明确重置本机对话存储。"
        case .save: "本机对话保存失败，此次更改尚未保存。请检查存储空间后重试保存。"
        }
    }
}

/// Atomic, versioned, local storage. Corruption is never replaced without an explicit reset.
final class DaybookConversationStore {
    private struct Archive: Codable { let version: Int; let conversations: [DaybookConversation] }
    private let url: URL
    private var database: DaybookDatabase?
    private let connectionLock = NSRecursiveLock()
    private var blockedValue = false
    private var blocked: Bool {
        get { connectionLock.lock(); defer { connectionLock.unlock() }; return blockedValue }
        set { connectionLock.lock(); defer { connectionLock.unlock() }; blockedValue = newValue }
    }
    static let pageSize = 10
    struct Cursor: Equatable, Sendable { let createdAt: Double; let id: String }
    struct Page { let turns: [DaybookConversationTurn]; let cursor: Cursor?; let hasMore: Bool }

    static func local() -> DaybookConversationStore {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DaybookConversationStore(url: root.appendingPathComponent("WristNotes/Conversations/history.json"))
    }

    init(url: URL, database: DaybookDatabase? = nil) { self.url = url; self.database = database }
    private func connection() throws -> DaybookDatabase {
        connectionLock.lock(); defer { connectionLock.unlock() }
        if let database { return database }
        let db = try DaybookDatabase(url: DaybookDatabase.url(forLegacy: url)); database = db; return db
    }

    private func preparedConnection() throws -> DaybookDatabase {
        let db = try connection()
        try db.migrate("conversation-history-v2") {
            try db.execute("ALTER TABLE conversation_turns ADD COLUMN state TEXT")
            try db.execute("ALTER TABLE conversation_turns ADD COLUMN created_at REAL")
            // Old rows have no individual send time. Preserve their thread/order deterministically.
            try db.execute("UPDATE conversation_turns SET created_at = (SELECT updated_at FROM conversations WHERE day = conversation_turns.day) - ((SELECT COUNT(*) FROM conversation_turns AS sibling WHERE sibling.day = conversation_turns.day) - 1 - position) * 0.000001")
            try db.execute("CREATE INDEX conversation_turns_history ON conversation_turns(created_at DESC, id DESC)")
        }
        try db.migrate("ask-ai-contracts-v2") {
            try db.execute("CREATE TABLE ask_ai_privacy_state (id INTEGER PRIMARY KEY CHECK(id=1), notebook_digest TEXT NOT NULL)")
            try db.execute("CREATE TABLE ask_ai_turn_evidence_v2 (turn_id TEXT PRIMARY KEY REFERENCES conversation_turns(id) ON DELETE CASCADE, refs BLOB, notebook_permissions BLOB)")
            try db.execute("CREATE TABLE ask_ai_memory_blocks (id TEXT PRIMARY KEY, session_key TEXT NOT NULL, summary_json BLOB NOT NULL, permission_digest TEXT NOT NULL, input_digest TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'valid')")
            try db.execute("CREATE TABLE ask_ai_memory_dependencies (block_id TEXT NOT NULL REFERENCES ask_ai_memory_blocks(id) ON DELETE CASCADE, dependency_key TEXT NOT NULL, turn_id TEXT REFERENCES conversation_turns(id) ON DELETE CASCADE, content_digest TEXT, domain TEXT, entity_id TEXT, revision TEXT, permission_digest TEXT, PRIMARY KEY(block_id,dependency_key))")
            try db.execute("CREATE INDEX ask_ai_memory_dependency_turn ON ask_ai_memory_dependencies(turn_id)")
            try db.execute("CREATE TRIGGER ask_ai_memory_turn_delete BEFORE DELETE ON conversation_turns BEGIN UPDATE ask_ai_memory_blocks SET status='invalid' WHERE id IN (SELECT block_id FROM ask_ai_memory_dependencies WHERE turn_id=OLD.id); END")
            try db.execute("CREATE TRIGGER ask_ai_memory_turn_update AFTER UPDATE ON conversation_turns WHEN OLD.question != NEW.question OR OLD.text != NEW.text OR OLD.evidence != NEW.evidence OR COALESCE(OLD.state,'completed') != COALESCE(NEW.state,'completed') BEGIN UPDATE ask_ai_memory_blocks SET status='invalid' WHERE id IN (SELECT block_id FROM ask_ai_memory_dependencies WHERE turn_id=OLD.id); END")
            try db.execute("CREATE TRIGGER ask_ai_memory_refs_update AFTER UPDATE ON ask_ai_turn_evidence_v2 WHEN OLD.refs IS NOT NEW.refs OR OLD.notebook_permissions IS NOT NEW.notebook_permissions BEGIN UPDATE ask_ai_memory_blocks SET status='invalid' WHERE id IN (SELECT block_id FROM ask_ai_memory_dependencies WHERE turn_id=OLD.turn_id); END")
        }
        try db.migrate("ask-ai-run-provenance-v1") {
            try db.execute("ALTER TABLE ask_ai_turn_evidence_v2 ADD COLUMN run_provenance BLOB")
            try db.execute("CREATE TRIGGER ask_ai_memory_provenance_update AFTER UPDATE OF run_provenance ON ask_ai_turn_evidence_v2 WHEN OLD.run_provenance IS NOT NEW.run_provenance BEGIN UPDATE ask_ai_memory_blocks SET status='invalid' WHERE id IN (SELECT block_id FROM ask_ai_memory_dependencies WHERE turn_id=OLD.turn_id); END")
        }
        try db.migrate("ask-ai-memory-entity-revisions-v1") {
            // Row absence = no mutation observed; NULL revision = durable deletion tombstone.
            try db.execute("CREATE TABLE IF NOT EXISTS ask_ai_memory_entity_revisions (domain TEXT NOT NULL, entity_id TEXT NOT NULL, revision TEXT, PRIMARY KEY(domain,entity_id))")
        }
        try db.migrate("conversations") {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            guard data.count <= 12_000_000 else { throw DaybookConversationFailure.load }
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            try Self.validate(archive)
            try Self.write(archive.conversations, db: db)
        }
        return db
    }

    /// Runtime worker shares the authoritative connection and domain migration. No database path escapes.
    func runtimeDatabase() throws -> DaybookDatabase { try preparedConnection() }

    func runtimeTurn(id: UUID) throws -> DaybookConversationTurn? {
        try preparedConnection().query("SELECT * FROM conversation_turns WHERE id = ?", [.text(id.uuidString)]).first.map { try Self.turn($0, db: preparedConnection()) }
    }

    func load() throws -> [DaybookConversation] {
        do {
            let db = try preparedConnection()
            let archive = Archive(version: 1, conversations: try Self.read(db))
            try Self.validate(archive)
            blocked = false
            return archive.conversations
        } catch { blocked = true; throw DaybookConversationFailure.load }
    }

    @discardableResult
    func save(_ conversations: [DaybookConversation]) throws -> [DaybookConversation] {
        guard !blocked else { throw DaybookConversationFailure.load }
        do {
            let db = try preparedConnection()
            try Self.validate(Archive(version: 1, conversations: conversations))
            try db.transaction { try Self.write(conversations, db: db) }
            return conversations
        } catch { throw DaybookConversationFailure.save }
    }

    func loadPage(before cursor: Cursor? = nil, limit: Int = pageSize) throws -> Page {
        do {
            let db = try preparedConnection()
            let count = max(1, min(limit, 100))
            var values: [DaybookDatabase.Value] = []
            var query = "SELECT * FROM conversation_turns"
            if let cursor {
                query += " WHERE (created_at, id) < (?, ?)"
                values += [.real(cursor.createdAt), .text(cursor.id)]
            }
            query += " ORDER BY created_at DESC, id DESC LIMIT ?"
            values.append(.integer(Int64(count + 1)))
            let rows = try db.query(query, values)
            let page = Array(rows.prefix(count))
            let turns = try page.map { try Self.turn($0, db: db) }.reversed()
            let next = try page.last.map { Cursor(createdAt: try $0.requiredDouble("created_at"), id: try $0.requiredString("id")) }
            blocked = false
            return Page(turns: Array(turns), cursor: next, hasMore: rows.count > count)
        } catch { blocked = true; throw DaybookConversationFailure.load }
    }

    func latestEvidenceDay(selectedDay: Date, allowedKinds: Set<DayRecord.Kind>) throws -> Date? {
        let db = try preparedConnection()
        guard let row = try db.query("SELECT evidence FROM conversation_turns WHERE day = ? AND COALESCE(state,'completed') = 'completed' ORDER BY position DESC LIMIT 1", [.real(selectedDay.timeIntervalSinceReferenceDate)]).first else { return nil }
        let evidence = try DaybookDatabase.decode(DaybookEvidenceSnapshot.self, row["evidence"])
        return evidence.allowedKinds.isSubset(of: allowedKinds) ? evidence.dayStart : nil
    }

    /// The request and every subsequent state are committed by UUID, never by replacing the archive.
    /// `day` assigns a new question's thread. Existing questions keep their stored thread,
    /// even when retried after midnight or with a different homepage date selected.
    func saveTurn(_ turn: DaybookConversationTurn, day: Date) throws {
        guard !blocked else { throw DaybookConversationFailure.load }
        do {
            try Self.validate(Archive(version: 1, conversations: [.init(day: day, updatedAt: .now, turns: [turn])]))
            let db = try preparedConnection()
            try db.transaction {
                let existing = try db.query("SELECT position,day FROM conversation_turns WHERE id = ?", [.text(turn.id.uuidString)]).first
                let dayValue = existing?["day"] ?? .real(day.timeIntervalSinceReferenceDate)
                try db.execute("INSERT INTO conversations(day,updated_at) VALUES (?,?) ON CONFLICT(day) DO UPDATE SET updated_at = excluded.updated_at", [dayValue, .real(Date.now.timeIntervalSinceReferenceDate)])
                let position = try existing?["position"] ?? db.query("SELECT COALESCE(MAX(position),-1)+1 AS next FROM conversation_turns WHERE day = ?", [dayValue])[0]["next"]!
                try Self.writeTurn(turn, day: dayValue, position: position, fallbackDate: .now, db: db)
            }
        } catch { throw DaybookConversationFailure.save }
    }

    func interruptPending() throws {
        let db = try preparedConnection()
        try db.execute("UPDATE conversation_turns SET state = 'cancelled', text = ?, sources = ?, question_references = NULL WHERE state = 'pending'", [.text("上次回答已中断，可重新提问。"), try DaybookDatabase.json([DaybookRetrieval.Source]())])
    }

    /// Read only bounded batches of permission metadata; unrelated rows and their content are untouched.
    func redactDisallowed(_ allowedKinds: Set<DayRecord.Kind>, notebookPermissions: AgentNotebookPermissions? = nil) throws {
        let db = try preparedConnection()
        try db.transaction {
            var didRedact = false
            if let permissions = notebookPermissions {
                let old = try db.query("SELECT notebook_digest FROM ask_ai_privacy_state WHERE id=1").first?["notebook_digest"]?.string
                didRedact = old != permissions.digest
                try db.execute("INSERT INTO ask_ai_privacy_state(id,notebook_digest) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET notebook_digest=excluded.notebook_digest", [.text(permissions.digest)])
            }
            var cursor = ""
            while true {
                let rows = try db.query("SELECT id,evidence FROM conversation_turns WHERE id > ? AND COALESCE(state,'completed') != 'redacted' ORDER BY id LIMIT 128", [.text(cursor)])
                guard !rows.isEmpty else { break }
                for row in rows {
                    cursor = try row.requiredString("id")
                    let evidence = try DaybookDatabase.decode(DaybookEvidenceSnapshot.self, row["evidence"])
                    let metadata = try db.query("SELECT * FROM ask_ai_turn_evidence_v2 WHERE turn_id=?", [.text(cursor)]).first
                    let refs: [AgentEvidenceRef] = try metadata?["refs"].flatMap { $0 == .null ? nil : try DaybookDatabase.decode([AgentEvidenceRef].self, $0) } ?? []
                    let provenance: AgentRunProvenance? = try metadata?["run_provenance"].flatMap { $0 == .null ? nil : try DaybookDatabase.decode(AgentRunProvenance.self,$0) }
                    let transitiveDenied = provenance.map { !$0.sourceKinds.isSubset(of:allowedKinds) || (notebookPermissions.map { !$0.allowedDomains.isSuperset(of:provenance!.domains) } ?? false) } ?? false
                    let notebookDenied = transitiveDenied || refs.contains { ref in !ref.sourceKinds.isSubset(of: allowedKinds) || (notebookPermissions.map { !$0.allowedDomains.contains(ref.domain) } ?? false) }
                    if !evidence.allowedKinds.isSubset(of: allowedKinds) || notebookDenied {
                        didRedact = true
                        try db.execute("DELETE FROM ask_ai_turn_evidence_v2 WHERE turn_id=?", [.text(cursor)])
                        try db.execute("UPDATE conversation_turns SET state = 'redacted', text = ?, generated = 0, provider = '', sources = ?, scope = '', question_references = NULL WHERE id = ?", [.text("相关资料的读取权限已关闭，回答和引用已移除。你的问题仍保留在历史中。"), try DaybookDatabase.json([DaybookRetrieval.Source]()), .text(cursor)])
                    }
                }
            }
            // Privacy cleanup must work even when this launch has not constructed the runtime.
            // Routine refreshes with unchanged permissions retain stable caches and active runs.
            if didRedact {
                if !(try db.query("SELECT domain FROM storage_migrations WHERE domain = 'ask-ai-runtime-v1'")).isEmpty { try Self.invalidateRuntimeCaches(db) }
                else {
                    try db.execute("DELETE FROM ask_ai_memory_blocks")
                    try db.execute("INSERT INTO storage_migrations(domain,imported_at) VALUES('ask-ai-runtime-cache-generation',1) ON CONFLICT(domain) DO UPDATE SET imported_at=imported_at+1")
                }
            }
        }
    }

    /// Called inside a short transaction, including by the worker-owned runtime.
    static func invalidateRuntimeCaches(_ db: DaybookDatabase) throws {
        try db.execute("INSERT INTO storage_migrations(domain,imported_at) VALUES('ask-ai-runtime-cache-generation',1) ON CONFLICT(domain) DO UPDATE SET imported_at=imported_at+1")
        try db.execute("UPDATE conversation_turns SET state='cancelled',text=?,generated=0,provider='',sources=?,scope='',question_references=NULL WHERE state='pending' AND id IN (SELECT turn_id FROM ask_ai_runs WHERE state NOT IN ('completed','failed','cancelled','interrupted'))", [.text("资料权限已变化，本次回答已中断，可重试。"), try DaybookDatabase.json([DaybookRetrieval.Source]())])
        try db.execute("UPDATE ask_ai_runs SET state='interrupted',ended_at=?,error_code='permissions_changed' WHERE state NOT IN ('completed','failed','cancelled','interrupted')", [.real(Date.now.timeIntervalSinceReferenceDate)])
        for table in ["ask_ai_evidence", "ask_ai_tool_calls", "ask_ai_memory", "ask_ai_checkpoints", "ask_ai_memory_blocks"] { try db.execute("DELETE FROM " + table) }
    }

    func reset() throws {
        // Explicit reset clears this domain only and keeps legacy bytes for recovery.
        do {
            let db = try connection()
            try db.transaction {
                if !(try db.query("SELECT domain FROM storage_migrations WHERE domain='ask-ai-runtime-v1'")).isEmpty { try Self.invalidateRuntimeCaches(db) }
                else { try db.execute("INSERT INTO storage_migrations(domain,imported_at) VALUES('ask-ai-runtime-cache-generation',1) ON CONFLICT(domain) DO UPDATE SET imported_at=imported_at+1") }
                if !(try db.query("SELECT domain FROM storage_migrations WHERE domain='ask-ai-contracts-v2'")).isEmpty { try db.execute("DELETE FROM ask_ai_memory_blocks") }
                try db.execute("DELETE FROM conversations")
                try db.markMigrated("conversations")
            }
            blocked = false
        } catch { throw DaybookConversationFailure.save }
    }
    private static func validate(_ archive: Archive) throws {
            guard archive.version == 1,
                  Set(archive.conversations.map(\.day)).count == archive.conversations.count,
                  Set(archive.conversations.flatMap { $0.turns.map(\.id) }).count == archive.conversations.reduce(0, { $0 + $1.turns.count }) else { throw DaybookConversationFailure.load }
            for thread in archive.conversations {
                guard thread.day.timeIntervalSinceReferenceDate.isFinite, thread.updatedAt.timeIntervalSinceReferenceDate.isFinite,
                      Set(thread.turns.map(\.id)).count == thread.turns.count else { throw DaybookConversationFailure.load }
                for turn in thread.turns {
                    guard turn.question.count <= 300, turn.text.count <= 8_000, turn.provider.count <= 300,
                          turn.sources.count <= 5, turn.sources.allSatisfy({ $0.snippet.count <= 200 && $0.title.count <= 48 }),
                          turn.evidence.dayStart < turn.evidence.dayEnd,
                          turn.evidence.fingerprint.count == 64,
                          turn.runProvenance?.isValid != false,
                          turn.runProvenance.map { $0.domains.isSubset(of:(turn.notebookPermissions ?? .init()).allowedDomains) } != false,
                          (turn.evidenceRefs?.count ?? 0) <= 5,
                          turn.evidenceRefs?.allSatisfy(\.isValid) != false,
                          Set((turn.evidenceRefs ?? []).map(\.number)).count == (turn.evidenceRefs?.count ?? 0),
                          (turn.evidenceRefs ?? []).allSatisfy({ ref in
                              ref.domain == .timeline || ref.domain == .conversation || (turn.notebookPermissions ?? .init()).allowedDomains.contains(ref.domain)
                          }),
                          (turn.evidenceRefs ?? []).allSatisfy({ ref in !turn.sources.contains { $0.number == ref.number && (ref.domain != .timeline || ref.entityID != $0.id.uuidString) } }),
                          turn.createdAt?.timeIntervalSinceReferenceDate.isFinite != false else { throw DaybookConversationFailure.load }
                }
            }
    }
    private static func write(_ conversations: [DaybookConversation], db: DaybookDatabase) throws {
        try db.execute("DELETE FROM conversations")
        for thread in conversations {
            let day = DaybookDatabase.Value.real(thread.day.timeIntervalSinceReferenceDate)
            try db.execute("INSERT INTO conversations VALUES (?, ?)", [day, .real(thread.updatedAt.timeIntervalSinceReferenceDate)])
            for (index, turn) in thread.turns.enumerated() {
                try writeTurn(turn, day: day, position: .integer(Int64(index)), fallbackDate: thread.updatedAt.addingTimeInterval(-Double(thread.turns.count - 1 - index) * 0.000001), db: db)
            }
        }
    }
    private static func writeTurn(_ turn: DaybookConversationTurn, day: DaybookDatabase.Value, position: DaybookDatabase.Value, fallbackDate: Date, db: DaybookDatabase) throws {
        try db.execute("""
            INSERT INTO conversation_turns(id,day,position,question,text,generated,provider,evidence,sources,scope,question_references,state,created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
            question=excluded.question,text=excluded.text,generated=excluded.generated,provider=excluded.provider,
            evidence=excluded.evidence,sources=excluded.sources,scope=excluded.scope,question_references=excluded.question_references,state=excluded.state
            """, [.text(turn.id.uuidString), day, position, .text(turn.question), .text(turn.text), .integer(turn.generated ? 1 : 0), .text(turn.provider), try DaybookDatabase.json(turn.evidence), try DaybookDatabase.json(turn.sources), .text(turn.scopeDescription), try turn.questionReferenceIDs.map { try DaybookDatabase.json($0) } ?? .null, turn.state.map { .text($0.rawValue) } ?? .null, .real((turn.createdAt ?? fallbackDate).timeIntervalSinceReferenceDate)])
        try db.execute("INSERT INTO ask_ai_turn_evidence_v2(turn_id,refs,notebook_permissions,run_provenance) VALUES (?,?,?,?) ON CONFLICT(turn_id) DO UPDATE SET refs=excluded.refs,notebook_permissions=excluded.notebook_permissions,run_provenance=excluded.run_provenance", [.text(turn.id.uuidString), try turn.evidenceRefs.map { try DaybookDatabase.json($0) } ?? .null, try turn.notebookPermissions.map { try DaybookDatabase.json($0) } ?? .null,try turn.runProvenance.map { try DaybookDatabase.json($0) } ?? .null])
    }

    private static func turn(_ value: DaybookDatabase.Row, db: DaybookDatabase) throws -> DaybookConversationTurn {
        guard let id = UUID(uuidString: try value.requiredString("id")) else { throw DaybookConversationFailure.load }
        let state = value["state"]?.string.flatMap(DaybookConversationTurn.State.init(rawValue:))
        guard value["state"] == .null || state != nil else { throw DaybookConversationFailure.load }
        var turn = DaybookConversationTurn(id: id, question: try value.requiredString("question"), text: try value.requiredString("text"), generated: value["generated"] == .integer(1), provider: try value.requiredString("provider"), evidence: try DaybookDatabase.decode(DaybookEvidenceSnapshot.self, value["evidence"]), sources: try DaybookDatabase.decode([DaybookRetrieval.Source].self, value["sources"]), scopeDescription: try value.requiredString("scope"), questionReferenceIDs: value["question_references"] == .null ? nil : try DaybookDatabase.decode([Int: UUID].self, value["question_references"]), state: state, createdAt: Date(timeIntervalSinceReferenceDate: try value.requiredDouble("created_at")))
        if let metadata = try db.query("SELECT * FROM ask_ai_turn_evidence_v2 WHERE turn_id=?", [.text(id.uuidString)]).first {
            turn.runProvenance = metadata["run_provenance"] == .null ? nil : try DaybookDatabase.decode(AgentRunProvenance.self,metadata["run_provenance"])
            turn.evidenceRefs = metadata["refs"] == .null ? nil : try DaybookDatabase.decode([AgentEvidenceRef].self, metadata["refs"])
            turn.notebookPermissions = metadata["notebook_permissions"] == .null ? nil : try DaybookDatabase.decode(AgentNotebookPermissions.self, metadata["notebook_permissions"])
        }
        try validate(Archive(version: 1, conversations: [.init(day: turn.evidence.dayStart, updatedAt: turn.createdAt!, turns: [turn])]))
        return turn
    }
    private static func read(_ db: DaybookDatabase) throws -> [DaybookConversation] {
        try db.transaction {
            try db.query("SELECT * FROM conversations ORDER BY updated_at DESC").map { row in
                let turns = try db.query("SELECT * FROM conversation_turns WHERE day = ? ORDER BY position", [row["day"]!]).map { value -> DaybookConversationTurn in
                    try turn(value, db: db)
                }
                return DaybookConversation(day: Date(timeIntervalSinceReferenceDate: try row.requiredDouble("day")), updatedAt: Date(timeIntervalSinceReferenceDate: try row.requiredDouble("updated_at")), turns: turns)
            }
        }
    }
}

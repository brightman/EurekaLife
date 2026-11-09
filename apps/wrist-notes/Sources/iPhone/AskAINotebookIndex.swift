import Foundation
import CryptoKit

/// Rebuildable, bounded incremental text projection. Business rows remain the only authority.
/// No embeddings/model downloads. Contact projection deliberately excludes email and phone.
enum AskAINotebookIndex {
    private struct Current { let text:String;let revision:String }
    static func prepare(database db:DaybookDatabase, domain:AgentEvidenceDomain) throws {
        guard [.ideas,.people].contains(domain) else { return }
        try db.migrate("ask-ai-notebook-fts-v1") {
            try db.execute("CREATE TABLE IF NOT EXISTS ask_ai_notebook_text (id TEXT PRIMARY KEY,domain TEXT NOT NULL,entity_id TEXT NOT NULL,revision TEXT NOT NULL,text_fingerprint TEXT NOT NULL,text TEXT NOT NULL)")
            try db.execute("CREATE VIRTUAL TABLE IF NOT EXISTS ask_ai_notebook_fts USING fts5(id UNINDEXED,text,tokenize='unicode61')")
            try db.execute("CREATE TABLE IF NOT EXISTS ask_ai_notebook_text_outbox (domain TEXT NOT NULL,entity_id TEXT NOT NULL,PRIMARY KEY(domain,entity_id))")
            try db.execute("CREATE TABLE IF NOT EXISTS ask_ai_notebook_text_seed (domain TEXT PRIMARY KEY,cursor TEXT NOT NULL DEFAULT '',done INTEGER NOT NULL DEFAULT 0)")
        }
        let tables=Set(try db.query("SELECT name FROM sqlite_master WHERE type='table'").compactMap{$0["name"]?.string})
        for table in ["flash_assets","contacts","notebook_contact_relationships"] where tables.contains(table) {
            try db.migrate("ask-ai-notebook-fts-outbox-v1-"+table) {
                let target=table == "flash_assets" ? "ideas" : "people"
                for event in ["INSERT","UPDATE","DELETE"] {
                    let row=event == "DELETE" ? "OLD" : "NEW"
                    let key=table == "notebook_contact_relationships" ? "contact_id" : "id"
                    let condition=table == "flash_assets" ? (event == "UPDATE" ? " WHEN OLD.kind='idea' OR NEW.kind='idea'" : " WHEN \(row).kind='idea'") : ""
                    try db.execute("CREATE TRIGGER IF NOT EXISTS ask_ai_text_\(table)_\(event) AFTER \(event) ON \(table)\(condition) BEGIN INSERT OR IGNORE INTO ask_ai_notebook_text_outbox(domain,entity_id) VALUES('\(target)',\(row).\(key)); END")
                }
            }
        }
        let table=domain == .ideas ? "flash_assets" : "contacts"
        guard tables.contains(table) else { return }
        // Seed at most32 existing IDs; new/changed/deleted IDs always come through the outbox.
        try db.transaction {
            try db.execute("INSERT OR IGNORE INTO ask_ai_notebook_text_seed(domain) VALUES(?)",[.text(domain.rawValue)])
            let state=try db.query("SELECT cursor,done FROM ask_ai_notebook_text_seed WHERE domain=?",[.text(domain.rawValue)]).first!
            if state["done"]?.double == 0 {
                let rows=try db.query("SELECT id FROM \(table) WHERE id>?"+(domain == .ideas ? " AND kind='idea'" : "")+" ORDER BY id LIMIT 32",[.text(state["cursor"]?.string ?? "")])
                for row in rows { try db.execute("INSERT OR IGNORE INTO ask_ai_notebook_text_outbox VALUES(?,?)",[.text(domain.rawValue),.text(try row.requiredString("id"))]) }
                try db.execute("UPDATE ask_ai_notebook_text_seed SET cursor=?,done=? WHERE domain=?",[.text(rows.last?["id"]?.string ?? state["cursor"]?.string ?? ""),.integer(rows.count<32 ? 1 : 0),.text(domain.rawValue)])
            }
            for row in try db.query("SELECT entity_id FROM ask_ai_notebook_text_outbox WHERE domain=? ORDER BY entity_id LIMIT 32",[.text(domain.rawValue)]) {
                let entity=try row.requiredString("entity_id"),id=domain.rawValue+":"+entity
                try db.execute("DELETE FROM ask_ai_notebook_fts WHERE id=?",[.text(id)])
                try db.execute("DELETE FROM ask_ai_notebook_text WHERE id=?",[.text(id)])
                if let value=try current(database:db,domain:domain,id:entity) {
                    try db.execute("INSERT INTO ask_ai_notebook_text VALUES(?,?,?,?,?,?)",[.text(id),.text(domain.rawValue),.text(entity),.text(value.revision),.text(hash(value.text)),.text(value.text)])
                    try db.execute("INSERT INTO ask_ai_notebook_fts(id,text) VALUES(?,?)",[.text(id),.text(value.text)])
                }
                try db.execute("DELETE FROM ask_ai_notebook_text_outbox WHERE domain=? AND entity_id=?",[.text(domain.rawValue),.text(entity)])
            }
        }
    }
    /// Call INSIDE the Reader's current business read snapshot; stale projection never exposes old text.
    static func matches(database db:DaybookDatabase,domain:AgentEvidenceDomain,query:String) throws -> [String] {
        guard [.ideas,.people].contains(domain) else { return [] }
        let words=query.split(whereSeparator:{!$0.isLetter && !$0.isNumber}).prefix(12)
        guard !words.isEmpty else { return [] }
        let match=words.map { "\""+String($0).replacingOccurrences(of:"\"",with:"\"\"")+"\"" }.joined(separator:" AND ")
        let rows=try db.query("SELECT p.entity_id,p.revision,p.text_fingerprint FROM ask_ai_notebook_fts f JOIN ask_ai_notebook_text p ON p.id=f.id WHERE ask_ai_notebook_fts MATCH ? AND p.domain=? ORDER BY rank,p.entity_id LIMIT 32",[.text(match),.text(domain.rawValue)])
        return try rows.compactMap { row in
            let id=try row.requiredString("entity_id")
            guard let value=try current(database:db,domain:domain,id:id),value.revision == row["revision"]?.string,hash(value.text) == row["text_fingerprint"]?.string else { return nil }
            return id
        }
    }
    static func coverage(database db:DaybookDatabase,domain:AgentEvidenceDomain)->String {
        guard [.ideas,.people].contains(domain) else { return "keyword SQL; semantic matching not loaded" }
        guard (try? db.query("SELECT name FROM sqlite_master WHERE name='ask_ai_notebook_fts'").isEmpty) == false else { return "keyword SQL; FTS unavailable; semantic matching not loaded" }
        let done=(try? db.query("SELECT done FROM ask_ai_notebook_text_seed WHERE domain=?",[.text(domain.rawValue)]).first?["done"]?.double) == 1
        let queued=(try? db.query("SELECT COUNT(*) AS n FROM ask_ai_notebook_text_outbox WHERE domain=?",[.text(domain.rawValue)]).first?["n"]?.double) ?? 1
        return "keyword SQL + current-version FTS (\(done && queued == 0 ? "complete text projection" : "incremental text coverage")); semantic matching not loaded"
    }
    private static func current(database db:DaybookDatabase,domain:AgentEvidenceDomain,id:String) throws -> Current? {
        if domain == .ideas {
            guard let row=try db.query("SELECT payload,revision FROM flash_assets WHERE id=? AND kind='idea' AND revoked=0",[.text(id)]).first,let data=row["payload"]?.data,let object=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { return nil }
            let text=(object["title"] as? String ?? "")+"\n"+(object["text"] as? String ?? "")
            return Current(text:text,revision:hash(data.base64EncodedString()+"|"+String(row["revision"]?.double ?? 0)))
        }
        guard let row=try db.query("SELECT display_name,organization,updated_at FROM contacts WHERE id=?",[.text(id)]).first else { return nil }
        let hasRelations=(try db.query("SELECT name FROM sqlite_master WHERE name='notebook_contact_relationships'").first) != nil
        let relations=hasRelations ? try db.query("SELECT relationship FROM notebook_contact_relationships WHERE contact_id=? ORDER BY relationship",[.text(id)]).compactMap{$0["relationship"]?.string}.joined(separator:" ") : ""
        let text=(row["display_name"]?.string ?? "")+"\n"+(row["organization"]?.string ?? "")+"\n"+relations
        return Current(text:text,revision:hash(text+"|"+String(row["updated_at"]?.double ?? 0)))
    }
    private static func hash(_ value:String)->String { SHA256.hash(data:Data(value.utf8)).map{String(format:"%02x",$0)}.joined() }
}

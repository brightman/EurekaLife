import Foundation
import CryptoKit
import CoreFoundation

/// Read-only notebook queries. Every result and its complete query dependency share one WAL snapshot.
/// Connections and all synchronous SQL execute on a utility worker; no model-provided SQL is accepted.
struct AskAINotebookReader: Sendable {
    enum Failure: Error { case invalidArguments, staleEvidence }
    struct Item: Codable, Sendable {
        let id: String
        let title: String
        let text: String
        let revision: String
        let fields: [String:String]
    }
    struct LedgerGroup: Codable, Sendable {
        let currency: String
        let direction: String
        let group: String
        let amountMinor: Int64
        let count: Int
    }
    struct Page: Codable, Sendable {
        var status: String = "ok"
        var items: [Item] = []
        var groups: [LedgerGroup] = []
        var querySpecification: String? = nil
        var unclassifiedCount = 0
        var groupCount = 0
        var nextGroupCursor: String? = nil
        var undatedCountScope = "All matching saved entries without a transaction date; excluded from period totals"
        var matchedCount = 0
        var pendingCount = 0
        var undatedCount = 0
        var restrictedCount = 0
        var nextCursor: String? = nil
        var nextOffset: Int? = nil
        var availableRange: [String] = []
        var coverage = "current saved entries"
        var searchMode = "keyword SQL; semantic matching not loaded"
        var evidenceRefs: [AgentEvidenceRef] = []
    }
    private struct Query: Codable, Sendable {
        var name: String; var type: AgentEvidenceDomain; var query = ""; var id = ""
        var start: String?; var end: String?; var day: String?; var direction: String?; var currency: String?; var category: String?; var relationship: String?
        var originScope: AgentQueryScope? = nil
        var textTokenLimit: Int? = nil
        var groupBy = "none"; var cursor = 0; var limit = 10; var offset = 0; var includeContactDetails = false
    }
    let databaseURL: URL
    let permissions: AgentNotebookPermissions
    let scope: AgentQueryScope
    let now: Date
    init(databaseURL: URL = DaybookDatabase.applicationURL, permissions: AgentNotebookPermissions = .init(), scope: AgentQueryScope = .init(), now: Date = .now) {
        self.databaseURL=databaseURL;self.permissions=permissions;self.scope=scope;self.now=now
    }
    func execute(name: String, arguments: Data,textTokenLimit:Int? = nil,pageLimit:Int? = nil) async throws -> Page {
        var query = try parse(name:name,arguments:arguments)
        query.textTokenLimit=textTokenLimit
        if let pageLimit { query.limit=min(query.limit,pageLimit) }
        return try await perform(query)
    }
    func validateEvidence(_ refs: [AgentEvidenceRef]) async throws -> Bool {
        for ref in refs where [.ideas,.ledger,.people,.places].contains(ref.domain) {
            guard let spec=ref.querySpecification, let data=spec.data(using:.utf8), let query=try? JSONDecoder().decode(Query.self,from:data), query.type == ref.domain else { return false }
            let current=try await perform(query)
            guard current.status != "restricted", current.status != "unavailable", current.evidenceRefs.contains(where:{$0.entityID == ref.entityID && $0.revision == ref.revision && $0.disclosurePolicy == ref.disclosurePolicy}) else { return false }
        }
        return true
    }
    /// Reruns the saved query against current data. Deleted/changed sources return unavailable.
    func detail(for ref: AgentEvidenceRef, offset: Int = 0) async throws -> Page {
        guard offset >= 0, offset <= 1_000_000, let spec=ref.querySpecification, let data=spec.data(using:.utf8), var query=try? JSONDecoder().decode(Query.self,from:data),query.type == ref.domain else { throw Failure.invalidArguments }
        let original=try await perform(query)
        guard original.evidenceRefs.contains(where:{$0.entityID == ref.entityID && $0.revision == ref.revision}) else { return Page(status:"unavailable",coverage:"Source deleted, changed or outside current permissions") }
        if query.type == .places {
            query.name="placeEvidenceDetails";query.id=String(ref.entityID.split(separator:"@",maxSplits:1)[0]);query.cursor=offset;query.limit=10
            let parts=ref.entityID.split(separator:"@",maxSplits:1);query.day=parts.count>1 ? String(parts[1]) : nil
        } else if query.name == "aggregateLedger" { query.cursor=offset;query.limit=10 } else if query.name == "readNotebookItem" { query.offset=offset } else { query.cursor=offset }
        return try await perform(query)
    }
    private func perform(_ query: Query,replay:Bool = true) async throws -> Page {
        try Task.checkCancellation()
        if replay,let origin=query.originScope {
            var effective=origin
            effective.domains.formIntersection(scope.domains.intersection(permissions.allowedDomains))
            effective.allowedKinds.formIntersection(scope.allowedKinds)
            if !scope.entityIDs.isEmpty {
                effective.entityIDs=origin.entityIDs.isEmpty ? scope.entityIDs : Array(Set(origin.entityIDs).intersection(scope.entityIDs))
                if effective.entityIDs.isEmpty { return Page(status:"restricted",coverage:"Original entity scope is no longer authorized") }
            }
            if let current=scope.dateRange {
                if let old=origin.dateRange { guard let overlap=old.intersection(with:current),overlap.duration>0 else {return Page(status:"restricted")};effective.dateRange=overlap }
                else { effective.dateRange=current }
            }
            // Keep the originating remote subset even when opened on this device.
            let reader=AskAINotebookReader(databaseURL:databaseURL,permissions:permissions,scope:effective,now:now)
            return try await reader.perform(query,replay:false)
        }
        guard query.textTokenLimit.map({ (1...1600).contains($0) }) != false,(1...10).contains(query.limit),(0...1_000_000).contains(query.cursor),(0...1_000_000).contains(query.offset),query.id.utf8.count<=512,query.query.count<=300,["searchNotebook","readNotebookItem","aggregateLedger","listPersonSegments","listPlaceVisits","placeEvidenceDetails"].contains(query.name) else { throw Failure.invalidArguments }
        if !query.id.isEmpty,!scope.entityIDs.isEmpty,!scope.entityIDs.contains(query.id) { return Page(status:"restricted",coverage:"Entity outside current allowed scope") }
        let task=Task.detached(priority:.utility) { () throws -> Page in
            try Task.checkCancellation()
            guard permissions.allowedDomains.contains(query.type),scope.domains.contains(query.type) else { return Page(status:"restricted",coverage:"Notebook category permission is disabled") }
            guard FileManager.default.fileExists(atPath:databaseURL.path) else { return Page(status:"unavailable",coverage:"Notebook database unavailable") }
            let db=try DaybookDatabase(url:databaseURL)
            try Self.installMutationTracking(database:db)
            // Projection maintenance is bounded and independent of exact SQL aggregation. Fail open to keyword SQL.
            if query.name == "searchNotebook" { try? AskAINotebookIndex.prepare(database:db,domain:query.type) }
            do { return try db.readTransaction { try read(query,db:db) } }
            catch let error as DaybookDatabase.Failure { return Page(status:"unavailable",coverage:error.detail.contains("overflow") ? "Integer overflow: exact total unavailable" : "Notebook data/index unavailable") }
        }
        return try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})
    }
    /// Installs only tiny domain counters/triggers. Business content and search indexes are never reconciled here.
    /// Safe whether Reader or ConversationStore prepares the shared database first.
    static func installMutationTracking(database db:DaybookDatabase) throws {
        try db.migrate("ask-ai-memory-entity-revisions-v1") {
            try db.execute("CREATE TABLE IF NOT EXISTS ask_ai_memory_entity_revisions (domain TEXT NOT NULL,entity_id TEXT NOT NULL,revision TEXT,PRIMARY KEY(domain,entity_id))")
        }
        let tables=Set(try db.query("SELECT name FROM sqlite_master WHERE type='table'").compactMap{$0["name"]?.string})
        let domains:[String:[String]]=["flash_assets":["ideas","ledger"],"contacts":["people"],"notebook_contact_relationships":["people"],"recording_speaker_contacts":["people"],"content_segments":["people"],"content_segment_ranges":["people"],"audio_transcript_spans":["people"],"audio_processing_jobs":["people"],"audio_processing_sources":["people","places"],"notebook_place_evidence":["places"],"notebook_place_labels":["places"],"voice_notes":["people","places"],"recording_sessions":["people","places"],"photo_moments":["places"],"photo_attachments":["places"],"recording_chunks":["places"],"recording_location_samples":["places"]]
        for table in domains.keys.sorted() where tables.contains(table) {
            try db.migrate("ask-ai-notebook-counter-v1-"+table) {
                for domain in domains[table]! {
                    try db.execute("INSERT OR IGNORE INTO ask_ai_memory_entity_revisions(domain,entity_id,revision) VALUES(?,'$domain','0')",[.text(domain)])
                    // Installation itself is a revision event: this table may already contain writes
                    // made before its mutation triggers existed.
                    try db.execute("UPDATE ask_ai_memory_entity_revisions SET revision=CAST(CAST(revision AS INTEGER)+1 AS TEXT) WHERE domain=? AND entity_id='$domain'",[.text(domain)])
                    for event in ["INSERT","UPDATE","DELETE"] {
                        var condition=""
                        if table == "flash_assets" {
                            let kind=domain == "ideas" ? "idea" : "expense"
                            condition=" WHEN "+(event == "UPDATE" ? "OLD.kind='\(kind)' OR NEW.kind='\(kind)'" : "\(event == "INSERT" ? "NEW" : "OLD").kind='\(kind)'")
                        }
                        try db.execute("CREATE TRIGGER IF NOT EXISTS ask_ai_counter_\(table)_\(domain)_\(event) AFTER \(event) ON \(table)\(condition) BEGIN UPDATE ask_ai_memory_entity_revisions SET revision=CAST(CAST(revision AS INTEGER)+1 AS TEXT) WHERE domain='\(domain)' AND entity_id='$domain'; END")
                    }
                }
            }
        }
    }
    private func parse(name:String,arguments:Data) throws -> Query {
        guard arguments.count <= 4096,let a=try JSONSerialization.jsonObject(with:arguments) as? [String:Any] else { throw Failure.invalidArguments }
        let keys:Set<String>
        switch name {
        case "searchNotebook": keys=["type","query","filters","start","end","cursor","limit"]
        case "readNotebookItem": keys=["type","id","offset","includeContactDetails"]
        case "aggregateLedger": keys=["start","end","direction","currency","category","groupBy","cursor","limit"]
        case "listPersonSegments": keys=["contactID","start","end","cursor","limit"]
        case "listPlaceVisits": keys=["placeID","start","end","cursor","limit"]
        default: throw Failure.invalidArguments
        }
        guard Set(a.keys).isSubset(of:keys) else { throw Failure.invalidArguments }
        func string(_ key:String,_ values:[String:Any],required:Bool=false,max:Int=300) throws -> String? {
            guard let raw=values[key] else { if required { throw Failure.invalidArguments }; return nil }
            guard let v=raw as? String,v.count <= max,!v.contains("\0"),!v.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw Failure.invalidArguments };return v
        }
        let domain:AgentEvidenceDomain
        if name == "aggregateLedger" { domain = .ledger } else if name == "listPersonSegments" { domain = .people } else if name == "listPlaceVisits" { domain = .places } else {
            guard let value=try string("type",a,required:true),let type=AgentEvidenceDomain(rawValue:value),[.ideas,.ledger,.people,.places].contains(type) else { throw Failure.invalidArguments };domain=type
        }
        var q=Query(name:name,type:domain)
        if name == "searchNotebook" { q.query=try string("query",a,required:true) ?? "" }
        if name == "readNotebookItem" { q.id=try string("id",a,required:true,max:512) ?? "" }
        if name == "listPersonSegments" { q.id=try string("contactID",a,required:true,max:512) ?? "" }
        if name == "listPlaceVisits" { q.id=try string("placeID",a,required:true,max:512) ?? "" }
        if !q.id.isEmpty,!scope.entityIDs.isEmpty,!scope.entityIDs.contains(q.id) { throw Failure.invalidArguments }
        func integer(_ key:String,max:Int,fallback:Int) throws -> Int {
            guard let raw=a[key] else { return fallback }
            guard let n=raw as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue.isFinite,n.doubleValue == Double(n.intValue),n.intValue >= (key == "limit" ? 1 : 0),n.intValue <= max else { throw Failure.invalidArguments };return n.intValue
        }
        q.limit=try integer("limit",max:10,fallback:10);q.offset=try integer("offset",max:1_000_000,fallback:0)
        if let cursor=try string("cursor",a,max:12) { guard let v=Int(cursor),v>=0,v<=1_000_000 else { throw Failure.invalidArguments };q.cursor=v }
        q.start=try string("start",a,max:40);q.end=try string("end",a,max:40)
        for value in [q.start,q.end].compactMap({$0}) { guard date(value) != nil else { throw Failure.invalidArguments } }
        if let s=q.start,let e=q.end { guard let a=date(s),let b=date(e),a<b else { throw Failure.invalidArguments } }
        if let range=scope.dateRange,q.type != .people || name == "listPersonSegments" {
            if let s=q.start,let d=date(s),d<range.start { throw Failure.invalidArguments }
            if let e=q.end,let d=date(e),d>range.end { throw Failure.invalidArguments }
        }
        var filters=a
        if let raw=a["filters"] { guard let f=raw as? [String:Any],Set(f.keys).isSubset(of:["direction","currency","category","relationship"]) else { throw Failure.invalidArguments }; filters=f }
        q.direction=try string("direction",filters,max:10);q.currency=try string("currency",filters,max:3);q.category=try string("category",filters,max:100);q.relationship=try string("relationship",filters,max:100)
        if let d=q.direction,!["income","expense"].contains(d) { throw Failure.invalidArguments }
        if let c=q.currency,!Locale.commonISOCurrencyCodes.contains(c) { throw Failure.invalidArguments }
        if domain != .ledger,(q.direction != nil || q.currency != nil || q.category != nil) { throw Failure.invalidArguments }
        if domain != .people,q.relationship != nil { throw Failure.invalidArguments }
        q.groupBy=try string("groupBy",a,max:20) ?? "none"
        guard ["none","category","date","month"].contains(q.groupBy) else { throw Failure.invalidArguments }
        if let raw=a["includeContactDetails"] { guard let n=raw as? NSNumber,CFGetTypeID(n)==CFBooleanGetTypeID() else { throw Failure.invalidArguments };q.includeContactDetails=n.boolValue }
        var origin=scope;origin.domains=[domain]
        if domain == .ledger || domain == .ideas { origin.allowedKinds=[] }
        q.originScope=origin
        return q
    }
    private func date(_ value:String)->Date? {
        if value.count == 10 {
            let f=DateFormatter();f.calendar=Calendar(identifier:.gregorian);f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(secondsFromGMT:0);f.dateFormat="yyyy-MM-dd";f.isLenient=false
            guard let d=f.date(from:value),f.string(from:d)==value else { return nil };return d
        }
        return ISO8601DateFormatter().date(from:value)
    }
    private func canonicalSpecification(_ query:Query) throws -> String {
        var object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(query)) as! [String:Any]
        if let scope=query.originScope,var value=object["originScope"] as? [String:Any] {
            value["domains"]=scope.domains.map(\.rawValue).sorted();value["allowedKinds"]=scope.allowedKinds.map(\.rawValue).sorted();value["entityIDs"]=scope.entityIDs.sorted();object["originScope"]=value
        }
        return String(decoding:try JSONSerialization.data(withJSONObject:object,options:.sortedKeys),as:UTF8.self)
    }
    private func hash(_ data:Data)->String { SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined() }
    private func read(_ q:Query,db:DaybookDatabase) throws -> Page {
        typealias V=DaybookDatabase.Value
        var sql:String
        // Common row shape permits deterministic SQL pagination/counting without materializing full business models.
        switch q.type {
        case .ideas,.ledger:
            sql="""
            SELECT id,json_extract(CAST(payload AS TEXT),'$.title') AS title,json_extract(CAST(payload AS TEXT),'$.text') AS body,
              CAST(payload AS TEXT) AS version,captured_at AS stamp,json_extract(CAST(payload AS TEXT),'$.date') AS day,
              currency,direction,amount_minor,ready,json_extract(CAST(payload AS TEXT),'$.category') AS category,
              CASE WHEN EXISTS(SELECT 1 FROM json_tree(CAST(payload AS TEXT)) WHERE (key='requiresLocalAI' AND value=1) OR (key IN ('device','captureDevice') AND value IN ('EurekaRing','ring'))) THEN 1 ELSE 0 END AS local,
              '' AS source_kind,COALESCE(json_extract(CAST(payload AS TEXT),'$.origin'),CASE WHEN json_extract(CAST(payload AS TEXT),'$.source.recordingKind')='merged' THEN 'merged' ELSE 'flash' END) AS extra
            FROM flash_assets WHERE revoked=0 AND kind='\(q.type == .ideas ? "idea" : "expense")'
            """
        case .people:
            if q.name == "listPersonSegments" {
                guard scope.allowedKinds.contains(.voice) else { return Page(status:"restricted",coverage:"Audio source permission is disabled") }
                sql="""
                SELECT c.id,json_extract(CAST(c.payload AS TEXT),'$.title') AS title,
                  (SELECT group_concat(speech,'\n') FROM (SELECT DISTINCT t.job_id,t.position,t.text AS speech FROM content_segment_ranges cr
                    JOIN audio_processing_jobs j ON j.source_key=c.source_key AND j.active=1 AND j.configuration_key=s.configuration_key AND j.result IS NOT NULL
                    JOIN audio_transcript_spans t ON t.job_id=j.id AND t.end>cr.start AND t.start<cr.end
                    JOIN recording_speaker_contacts l ON l.source_key=c.source_key AND l.speaker_id=t.speaker_id
                    WHERE cr.segment_id=c.id AND l.contact_id=? ORDER BY t.start,t.end,t.job_id,t.position)) AS body,
                  CAST(c.payload AS TEXT)||CAST(s.descriptor AS TEXT)||COALESCE((SELECT group_concat(l.speaker_id||l.speaker_revision) FROM recording_speaker_contacts l WHERE l.source_key=c.source_key AND l.contact_id=?),'') AS version,
                  COALESCE(n.captured_at,r.started_at,r.created_at)+c.start AS stamp,NULL AS day,NULL AS currency,NULL AS direction,NULL AS amount_minor,1 AS ready,NULL AS category,
                  CASE WHEN EXISTS(SELECT 1 FROM json_tree(CAST(s.descriptor AS TEXT)) WHERE key IN ('device','captureDevice') AND value IN ('EurekaRing','ring')) THEN 1 ELSE 0 END AS local,
                  'voice' AS source_kind,'Speaker identity needs review; binding alone does not prove a physical meeting' AS extra
                FROM content_segments c JOIN audio_processing_sources s ON s.source_key=c.source_key
                LEFT JOIN voice_notes n ON n.id=s.note_id LEFT JOIN recording_sessions r ON r.id=s.session_id
                WHERE c.deleted=0 AND s.cancelled=0 AND json_extract(CAST(c.payload AS TEXT),'$.isFinal')=1 AND json_extract(CAST(c.payload AS TEXT),'$.hasText')=1
                  AND COALESCE(json_extract(CAST(c.payload AS TEXT),'$.editorial.classification'),'meaningful')='meaningful'
                """
            } else {
                let hasRelationships=try !db.query("SELECT name FROM sqlite_master WHERE name='notebook_contact_relationships'").isEmpty
                let relationshipText=hasRelationships ? "COALESCE((SELECT group_concat(relationship,' ') FROM notebook_contact_relationships WHERE contact_id=c.id),'')" : "''"
                sql="""
                SELECT c.id,c.display_name AS title,COALESCE(c.organization,'')||' '||\(relationshipText) AS body,
                  c.display_name||COALESCE(c.organization,'')||c.emails_json||c.phone_numbers_json||CAST(c.updated_at AS TEXT)||\(relationshipText) AS version,
                  c.created_at AS stamp,NULL AS day,NULL AS currency,NULL AS direction,NULL AS amount_minor,1 AS ready,NULL AS category,0 AS local,'' AS source_kind,
                  \(q.includeContactDetails ? "c.emails_json||' '||c.phone_numbers_json" : "''") AS extra FROM contacts c
                """
            }
        case .places:
            guard scope.allowedKinds.contains(.location) else { return Page(status:"restricted",coverage:"Location source permission is disabled") }
            // Audio provenance is conservatively local-only unless a surviving source proves otherwise.
            sql="""
            SELECT e.id,COALESCE(NULLIF(l.name,''),e.display_label,'Saved place') AS title,
              e.day||' · '||e.source_kind||' · '||e.date_basis||' · timezone='||e.time_zone AS body,
              e.id||e.place_id||e.source_id||e.day||e.time_zone||e.date_basis||CAST(e.captured_at AS TEXT)||COALESCE(l.name,'')||COALESCE(l.type,'') AS version,
              e.captured_at AS stamp,e.day,e.time_zone AS zone,NULL AS currency,NULL AS direction,NULL AS amount_minor,1 AS ready,NULL AS category,
              CASE WHEN e.source_kind='照片' THEN 0 ELSE 1 END AS local,
              CASE WHEN e.source_kind='照片' THEN 'image' ELSE 'voice' END AS source_kind,e.place_id||'|'||e.source_id AS extra
            FROM notebook_place_evidence e LEFT JOIN notebook_place_labels l ON l.place_id=e.place_id
            WHERE (EXISTS(SELECT 1 FROM voice_notes n WHERE n.id=e.source_id) OR EXISTS(SELECT 1 FROM recording_sessions s WHERE s.id=e.source_id) OR EXISTS(SELECT 1 FROM photo_moments p WHERE p.id=e.source_id))
              AND (e.id NOT LIKE 'photo:%' OR EXISTS(SELECT 1 FROM photo_attachments a WHERE a.id=substr(e.id,7) AND a.moment_id=e.source_id))
              AND (e.id NOT LIKE 'chunk:%' OR EXISTS(SELECT 1 FROM recording_chunks c WHERE c.id=substr(e.id,7) AND c.session_id=e.source_id))
              AND (e.id NOT LIKE 'sample:%' OR EXISTS(SELECT 1 FROM recording_location_samples x WHERE x.id=substr(e.id,8) AND x.session_id=e.source_id))
            """
        default: throw Failure.invalidArguments
        }
        var values:[V]=q.name == "listPersonSegments" ? [.text(q.id),.text(q.id)] : []
        var conditions=["1=1"]
        if q.name == "listPersonSegments" { conditions.append("body IS NOT NULL AND body!=''") }
        if q.name == "readNotebookItem" { conditions.append(q.type == .places ? "substr(extra,1,instr(extra,'|')-1)=?" : "id=?");values.append(.text(q.id)) }
        if q.name == "listPlaceVisits" || q.name == "placeEvidenceDetails" { conditions.append("substr(extra,1,instr(extra,'|')-1)=?");values.append(.text(q.id)) }
        if let day=q.day { conditions.append("day=?");values.append(.text(day)) }
        if !scope.entityIDs.isEmpty,q.id.isEmpty { conditions.append("id IN ("+scope.entityIDs.map{_ in "?"}.joined(separator:",")+")");values += scope.entityIDs.map(V.text) }
        var rankedIDs:[String]=[]
        if !q.query.isEmpty {
            rankedIDs=(try? AskAINotebookIndex.matches(database:db,domain:q.type,query:q.query)) ?? []
            // Full-scope SQL token intersection keeps matchedCount exact even when FTS returns only32 candidates.
            let tokens=q.query.split(whereSeparator:{!$0.isLetter && !$0.isNumber}).prefix(12).map(String.init)
            for token in tokens.isEmpty ? [q.query] : tokens {
                conditions.append("(instr(lower(title),lower(?))>0 OR instr(lower(body),lower(?))>0)")
                values += [.text(token),.text(token)]
            }
        }
        if let d=q.direction { conditions.append("direction=?");values.append(.text(d)) }
        if let c=q.currency { conditions.append("currency=?");values.append(.text(c)) }
        if let c=q.category { conditions.append("category=?");values.append(.text(c)) }
        if let r=q.relationship { guard q.type == .people,q.name != "listPersonSegments" else { throw Failure.invalidArguments };conditions.append("EXISTS(SELECT 1 FROM notebook_contact_relationships r WHERE r.contact_id=base.id AND r.relationship=?)");values.append(.text(r)) }
        let beforeDates="WITH base AS (\(sql)) SELECT * FROM base WHERE "+conditions.joined(separator:" AND ")
        var pending=0,undated=0
        if q.type == .ledger {
            let counts=try db.query("SELECT COUNT(CASE WHEN ready=0 THEN 1 END) AS pending,COUNT(CASE WHEN day IS NULL OR day='' THEN 1 END) AS undated FROM (\(beforeDates))",values).first
            undated=Int(counts?["undated"]?.double ?? 0)
        }
        let usesDates=q.type != .people || q.name == "listPersonSegments"
        if usesDates {
            let start=q.start.flatMap(date) ?? scope.dateRange?.start,end=q.end.flatMap(date) ?? scope.dateRange?.end
            if q.type == .ledger || q.type == .places {
                if let s=q.start ?? start.map({String($0.ISO8601Format().prefix(10))}) { conditions.append("day>=?");values.append(.text(String(s.prefix(10)))) }
                if let e=q.end ?? end.map({String($0.ISO8601Format().prefix(10))}) { conditions.append("day<?");values.append(.text(String(e.prefix(10)))) }
            } else {
                if let s=start { conditions.append("stamp>=?");values.append(.real(s.timeIntervalSinceReferenceDate)) }
                if let e=end { conditions.append("stamp<?");values.append(.real(e.timeIntervalSinceReferenceDate)) }
            }
        }
        var page=Page();page.pendingCount=pending;page.undatedCount=undated
        page.searchMode=AskAINotebookIndex.coverage(database:db,domain:q.type)
        if q.type == .places {
            var ranges:[(String,String,String)]=[]
            let zones=try db.query("SELECT DISTINCT time_zone FROM notebook_place_evidence ORDER BY time_zone").compactMap{$0["time_zone"]?.string}
            for zone in zones.isEmpty ? ["UTC"] : zones {
                var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:zone) ?? TimeZone(secondsFromGMT:0)!
                let f=DateFormatter();f.calendar=calendar;f.timeZone=calendar.timeZone;f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="yyyy-MM-dd"
                let today=calendar.startOfDay(for:now),lower=calendar.date(byAdding:.day,value:-29,to:today)!
                ranges.append((zone,f.string(from:lower),f.string(from:now)))
            }
            let lower=ranges.map{$0.1}.min()!,upper=ranges.map{$0.2}.max()!
            page.availableRange=[lower,upper];page.coverage="Near-30-day evidence index; saved natural day and original timezone; older history unavailable, no full trajectory"
            conditions.append("("+ranges.map{_ in "(zone=? AND day>=? AND day<=?)"}.joined(separator:" OR ")+")")
            for range in ranges { values += [.text(range.0),.text(range.1),.text(range.2)] }
            if q.start == nil || String(q.start!.prefix(10)) < lower || q.end.flatMap(date).map({$0 > now.addingTimeInterval(2*86400)}) == true { page.status="partial" }
            if !scope.allowedKinds.contains(.image) { conditions.append("source_kind!='image'") }
            if !scope.allowedKinds.contains(.voice) { conditions.append("source_kind!='voice'") }
        }
        let unfiltered="WITH base AS (\(sql)) SELECT * FROM base WHERE "+conditions.joined(separator:" AND ")
        if scope.destination == .allowedRemote {
            page.restrictedCount=try count(db,"SELECT COUNT(*) AS n FROM (\(unfiltered)) WHERE local=1",values)
            conditions.append("local=0")
            if page.restrictedCount>0 { page.status="partial" }
        }
        let base="WITH base AS (\(sql)) SELECT * FROM base WHERE "+conditions.joined(separator:" AND ")
        if q.type == .ledger { pending=try count(db,"SELECT COUNT(*) AS n FROM (\(base)) WHERE ready=0",values);page.pendingCount=pending }
        // Conservative per-domain revisions cover every business-table write, including matching
        // insertion/deletion/date/category movement, without materializing the library's text payloads.
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        let spec=try canonicalSpecification(q)
        page.querySpecification=spec
        let domainRevision=try db.query("SELECT revision FROM ask_ai_memory_entity_revisions WHERE domain=? AND entity_id='$domain'",[.text(q.type.rawValue)]).first?["revision"]?.string ?? "0"
        let scopeIdentity:[String:Any]=["domains":scope.domains.map(\.rawValue).sorted(),"sourceKinds":scope.allowedKinds.map(\.rawValue).sorted(),"entityIDs":scope.entityIDs.sorted(),"destination":scope.destination.rawValue,"start":scope.dateRange.map{$0.start.timeIntervalSinceReferenceDate} as Any? ?? NSNull(),"end":scope.dateRange.map{$0.end.timeIntervalSinceReferenceDate} as Any? ?? NSNull()]
        let identity:[String:Any]=["query":spec,"scope":scopeIdentity,"domainRevision":domainRevision,"availableRange":page.availableRange,"coverage":page.coverage]
        let revision=hash(try JSONSerialization.data(withJSONObject:identity,options:[.sortedKeys]))
        let dependencies:[AgentEvidenceDependency]=[.init(domain:q.type,entityID:"query:"+hash(Data(spec.utf8)),revision:revision),.init(domain:q.type,entityID:"$domain",revision:domainRevision)]
        if q.name == "aggregateLedger" {
            let group:String
            switch q.groupBy { case "category":group="COALESCE(category,'unclassified')";case "date":group="day";case "month":group="substr(day,1,7)";default:group="''" }
            let ready="SELECT * FROM (\(base)) WHERE ready=1 AND day IS NOT NULL AND currency IS NOT NULL AND direction IN ('income','expense') AND amount_minor IS NOT NULL"
            page.matchedCount=try count(db,"SELECT COUNT(*) AS n FROM (\(ready))",values)
            page.unclassifiedCount=try count(db,"SELECT COUNT(*) AS n FROM (\(ready)) WHERE category IS NULL OR category=''",values)
            page.groupCount=try count(db,"SELECT COUNT(*) AS n FROM (SELECT 1 FROM (\(ready)) GROUP BY currency,direction,\(group))",values)
            if q.cursor+q.limit<page.groupCount { page.nextGroupCursor=String(q.cursor+q.limit);page.status="partial" }
            page.groups=try db.query("SELECT currency,direction,\(group) AS grouping,SUM(amount_minor) AS amount,COUNT(*) AS n FROM (\(ready)) GROUP BY currency,direction,\(group) ORDER BY currency,direction,grouping LIMIT ? OFFSET ?",values+[.integer(Int64(q.limit)),.integer(Int64(q.cursor))]).map { row in
                guard case let .integer(amount)?=row["amount"] else { throw Failure.invalidArguments }
                return LedgerGroup(currency:try row.requiredString("currency"),direction:try row.requiredString("direction"),group:try row.requiredString("grouping"),amountMinor:amount,count:try row.requiredInt("n"))
            }
            if page.pendingCount>0 || page.undatedCount>0 { page.status="partial" }
            let summary=String(decoding:try encoder.encode(page.groups),as:UTF8.self)
            let policy:AgentDisclosurePolicy = try count(db,"SELECT COUNT(*) AS n FROM (\(base)) WHERE local=1",values)>0 ? .localOnly : .allowedRemote
            page.evidenceRefs=[.init(domain:.ledger,entityID:"aggregate:"+hash(Data(spec.utf8)),number:1,title:"Ledger aggregate",snippet:String(summary.prefix(500)),revision:revision,querySpecification:spec,dependencies:dependencies,disclosurePolicy:policy)]
        } else if q.name == "listPlaceVisits" {
            page.matchedCount=try count(db,"SELECT COUNT(DISTINCT day) AS n FROM (\(base))",values)
        } else if q.type == .places && q.name != "placeEvidenceDetails" {
            page.matchedCount=try count(db,"SELECT COUNT(DISTINCT substr(extra,1,instr(extra,'|')-1)) AS n FROM (\(base))",values)
        } else { page.matchedCount=try count(db,"SELECT COUNT(*) AS n FROM (\(base))",values) }
        let rank=rankedIDs.isEmpty ? "" : "CASE WHEN id IN ("+rankedIDs.map{_ in "?"}.joined(separator:",")+") THEN 0 ELSE 1 END,"
        var pageSQL=base+(q.name == "aggregateLedger" ? " AND ready=1 AND day IS NOT NULL AND currency IS NOT NULL AND direction IN ('income','expense') AND amount_minor IS NOT NULL" : "")+" ORDER BY "+rank+"stamp DESC,id LIMIT ? OFFSET ?"
        if q.name == "listPlaceVisits" { pageSQL="SELECT * FROM (\(base)) GROUP BY day ORDER BY day DESC LIMIT ? OFFSET ?" }
        else if q.type == .places && q.name != "placeEvidenceDetails" { pageSQL="SELECT * FROM (\(base)) GROUP BY substr(extra,1,instr(extra,'|')-1) ORDER BY MAX(stamp) DESC,extra LIMIT ? OFFSET ?" }
        let rows=try db.query(pageSQL,values+rankedIDs.map(V.text)+[.integer(Int64(q.limit)),.integer(Int64(q.cursor))])
        for row in rows {
            var id=try row.requiredString("id")
            let title=String((row["title"]?.string ?? "Notebook entry").prefix(120))
            let body=(row["body"]?.string ?? "")+(q.includeContactDetails ? " "+(row["extra"]?.string ?? "") : "")
            let rawWindow=String(body.dropFirst(q.offset).prefix(q.name == "readNotebookItem" ? 2000 : 500))
            let window=q.textTokenLimit.map { AgentToolPageBudget.prefix(rawWindow,tokens:$0) } ?? rawWindow
            var fields:[String:String]=[:]
            for key in ["day","currency","direction","category","source_kind","extra"] { if let v=row[key]?.string,!v.isEmpty { fields[key]=v } }
            if case let .integer(v)?=row["amount_minor"] { fields["amountMinor"]=String(v) }
            if q.type == .ideas { fields["provenance"]=row["extra"]?.string ?? "flash";fields["parentQuotes"]="Excluded; standalone saved body remains available independently" }
            if let stamp=row["stamp"]?.double { fields["capturedAt"]=Date(timeIntervalSinceReferenceDate:stamp).ISO8601Format() }
            if q.name == "listPersonSegments" { fields["identityNeedsReview"]="true";fields["segmentID"]=id;fields["contactID"]=q.id }
            if q.type == .places {
                let parts=(row["extra"]?.string ?? "").split(separator:"|",maxSplits:1).map(String.init)
                if let placeID=parts.first {
                    fields["placeID"]=placeID
                    if parts.count>1 { fields["sourceID"]=parts[1] }
                    if q.name != "placeEvidenceDetails" { id=q.name == "listPlaceVisits" ? placeID+"@"+(row["day"]?.string ?? "") : placeID }
                    let dayCondition=q.name == "listPlaceVisits" ? " AND day=?" : ""
                    var relatedValues=values+[.text(placeID)];if q.name == "listPlaceVisits" { relatedValues.append(.text(row["day"]?.string ?? "")) }
                    fields["sourceCount"]=String(try count(db,"SELECT COUNT(DISTINCT substr(extra,instr(extra,'|')+1)) AS n FROM (\(base)) WHERE substr(extra,1,instr(extra,'|')-1)=?"+dayCondition,relatedValues))
                    fields["distinctSavedDays"]=String(try count(db,"SELECT COUNT(DISTINCT day) AS n FROM (\(base)) WHERE substr(extra,1,instr(extra,'|')-1)=?",values+[.text(placeID)]))
                }
                fields.removeValue(forKey:"extra")
            }
            page.items.append(.init(id:id,title:title,text:window,revision:revision,fields:fields))
            if q.name == "readNotebookItem",q.offset+window.count<body.count { page.nextOffset=q.offset+window.count }
            if q.name != "aggregateLedger" && q.name != "placeEvidenceDetails" {
                let kind=row["source_kind"]?.string.flatMap(DayRecord.Kind.init(rawValue:))
                page.evidenceRefs.append(.init(domain:q.type,entityID:id,number:page.evidenceRefs.count+1,title:title,snippet:String(window.prefix(500)),revision:revision,querySpecification:spec,dependencies:dependencies,disclosurePolicy:row["local"]?.double == 1 ? .localOnly : .allowedRemote,sourceKinds:kind.map{[$0]} ?? [],excerptRange:"\(q.offset):\(min(500,window.count))"))
            }
        }
        if q.name == "placeEvidenceDetails" { page.coverage += "; detail matchedCount counts individual saved observations; visit totals count distinct natural days" }
        let count=page.matchedCount
        if q.cursor+rows.count<count { page.nextCursor=String(q.cursor+rows.count) }
        if page.matchedCount == 0 && page.status == "ok" { page.status=page.restrictedCount>0 ? "restricted" : "empty" }
        return page
    }
    private func count(_ db:DaybookDatabase,_ sql:String,_ values:[DaybookDatabase.Value]) throws -> Int { try db.query(sql,values).first?.requiredInt("n") ?? 0 }
}

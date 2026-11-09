import Foundation
@main struct AskAINotebookSmoke {
    enum Failed: Error { case check(String) }
    static func check(_ value: Bool, _ message: String) throws { if !value { throw Failed.check(message) } }
    static func main() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notebook-agent-\(UUID()).sqlite3")
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath:url.path+suffix) } }
        let db = try DaybookDatabase(url:url)
        try db.execute("CREATE TABLE flash_assets(id TEXT PRIMARY KEY,source_id TEXT,kind TEXT,captured_at REAL,revision INTEGER,revoked INTEGER,ready INTEGER,currency TEXT,direction TEXT,amount_minor INTEGER,payload BLOB)")
        func insert(_ id:String, currency:String="CNY",ready:Int=1,revoked:Int=0,date:String?="2026-11-02",local:Bool=false) throws {
            var payload:[String:Any] = ["title":"Lunch", "text":"saved body", "category":"food", "requiresLocalAI":local]
            if let date { payload["date"] = date }
            try db.execute("INSERT INTO flash_assets VALUES(?,?,'expense',0,1,?,?,?,'expense',100,?)",[.text(id),.text("gone-audio"),.integer(Int64(revoked)),.integer(Int64(ready)),.text(currency),.blob(try JSONSerialization.data(withJSONObject:payload))])
        }
        for i in 0..<8 { try insert("entry-\(i)") }; try insert("usd",currency:"USD"); try insert("pending",ready:0,date:nil); try insert("revoked",revoked:1); try insert("oct",date:"2026-10-31");try insert("pending-oct",ready:0,date:"2026-10-30");try insert("private",local:true)
        let permissions=AgentNotebookPermissions(allowLedger:true)
        let scope=AgentQueryScope(domains:[.ledger],allowedKinds:[],destination:.localOnly)
        let reader=AskAINotebookReader(databaseURL:url,permissions:permissions,scope:scope)
        let args=Data(#"{"start":"2026-11-01","end":"2026-12-01"}"#.utf8)
        let total=try await reader.execute(name:"aggregateLedger",arguments:args)
        try check(total.matchedCount == 10 && total.groups.first(where:{$0.currency=="CNY"})?.amountMinor == 900,"all rows, exact separate currency totals")
        try check(total.undatedCount == 1 && total.pendingCount == 0,"undated explicit; dated pending outside period excluded")
        try check(try await reader.validateEvidence(total.evidenceRefs),"initial aggregate valid")
        try insert("new")
        try check(try await !reader.validateEvidence(total.evidenceRefs),"new matching entry invalidates complete query")
        let remote=AskAINotebookReader(databaseURL:url,permissions:permissions,scope:.init(domains:[.ledger],destination:.allowedRemote))
        let remoteTotal=try await remote.execute(name:"aggregateLedger",arguments:args)
        try check(remoteTotal.status == "partial" && remoteTotal.matchedCount == 10,"remote restriction explicit")
        let persisted=try JSONDecoder().decode(AgentEvidenceRef.self,from:JSONEncoder().encode(remoteTotal.evidenceRefs[0]))
        let reopenedLocal=AskAINotebookReader(databaseURL:url,permissions:.init(allowIdeas:true,allowLedger:true),scope:.init(domains:[.ledger,.ideas],destination:.localOnly))
        let replay=try await reopenedLocal.detail(for:persisted)
        try check(replay.matchedCount == remoteTotal.matchedCount && replay.groups.map(\.amountMinor) == remoteTotal.groups.map(\.amountMinor) && replay.restrictedCount == 1,"remote aggregate reopens locally with original restricted subset despite unrelated permission expansion")
        let denied=AskAINotebookReader(databaseURL:url,scope:scope)
        try check(try await denied.detail(for:persisted).status == "unavailable","revoked aggregate scope cannot replay")
        try check(try await denied.execute(name:"aggregateLedger",arguments:args).status == "restricted","default deny")
        do { _=try await reader.execute(name:"aggregateLedger",arguments:Data(#"{"sql":"DROP TABLE contacts"}"#.utf8));throw Failed.check("unknown arg") } catch AskAINotebookReader.Failure.invalidArguments {}
        let current=try await reader.execute(name:"aggregateLedger",arguments:args)
        try db.execute("UPDATE flash_assets SET payload=json_set(CAST(payload AS TEXT),'$.date','2026-10-01') WHERE id='entry-0'")
        try check(try await !reader.validateEvidence(current.evidenceRefs),"date movement invalidates")
        let afterMove=try await reader.execute(name:"aggregateLedger",arguments:args)
        try db.execute("DELETE FROM flash_assets WHERE id='entry-1'")
        try check(try await !reader.validateEvidence(afterMove.evidenceRefs),"delete invalidates")
        let beforeCategory=try await reader.execute(name:"aggregateLedger",arguments:args)
        try db.execute("UPDATE flash_assets SET payload=json_set(CAST(payload AS TEXT),'$.category','travel') WHERE id='entry-2'")
        try check(try await !reader.validateEvidence(beforeCategory.evidenceRefs),"category edit invalidates")
        for i in 0..<15 { try insert("group-\(i)");try db.execute("UPDATE flash_assets SET payload=json_set(CAST(payload AS TEXT),'$.category',?) WHERE id=?",[.text("cat-\(i)"),.text("group-\(i)")]) }
        let grouped=try await reader.execute(name:"aggregateLedger",arguments:Data(#"{"groupBy":"category"}"#.utf8))
        try check(grouped.groups.count==10 && grouped.groupCount>10 && grouped.nextGroupCursor != nil,"group results bounded, full count preserved")
        try await testIdeas(db,url)
        try await testPeople(db,url)
        try await testPlaces(db,url)
        try testInitializationOrder(db,url)
        try await testMutationMemory(db,url)
        try await testIndex(db,url)
        let beforeOverflow=try await reader.execute(name:"aggregateLedger",arguments:Data("{}".utf8))
        try db.execute("UPDATE flash_assets SET amount_minor=9223372036854775807 WHERE id='usd'")
        try insert("overflow",currency:"USD")
        let overflow=try await reader.execute(name:"aggregateLedger",arguments:Data("{}".utf8))
        try check(overflow.status=="unavailable" && overflow.groups.isEmpty,"integer SUM overflow explicitly unavailable")
        try check(beforeOverflow.matchedCount>5,"overflow fixture starts from complete larger dataset")
        print("Notebook Reader: exact SQL totals/paging/overflow, all domains, speaker overlap, place days, stale scope and permission regressions passed")
    }
    static func testIdeas(_ db:DaybookDatabase,_ url:URL) async throws {
        let payload=Data(#"{"title":"Old saved idea","text":"Standalone saved body","origin":"generated","parentIdeas":[{"source":{"device":"EurekaRing","quote":"SECRET_PARENT"}}]}"#.utf8)
        try db.execute("INSERT INTO flash_assets VALUES('saved-idea','deleted-parent','idea',0,1,0,1,NULL,NULL,NULL,?)",[.blob(payload)])
        let scope=AgentQueryScope(domains:[.ideas],destination:.localOnly)
        let reader=AskAINotebookReader(databaseURL:url,permissions:.init(allowIdeas:true),scope:scope)
        let result=try await reader.execute(name:"searchNotebook",arguments:Data(#"{"type":"ideas","query":"saved"}"#.utf8))
        try check(result.items.first?.id=="saved-idea" && result.items.first?.text=="Standalone saved body","standalone idea not tied to selected timeline day or deleted audio")
        try check(!String(decoding:try JSONEncoder().encode(result),as:UTF8.self).contains("SECRET_PARENT"),"parent quotes never copied")
        let remote=AskAINotebookReader(databaseURL:url,permissions:.init(allowIdeas:true),scope:.init(domains:[.ideas],destination:.allowedRemote))
        let restricted=try await remote.execute(name:"searchNotebook",arguments:Data(#"{"type":"ideas","query":"saved"}"#.utf8))
        try check(restricted.items.isEmpty && restricted.status != "empty","nested Ring provenance cannot go remote")
        let ref=result.evidenceRefs[0]
        try db.execute("DELETE FROM flash_assets WHERE id='saved-idea'")
        try check(try await reader.detail(for:ref).status == "unavailable","deleted reference reopens unavailable")
    }
    static func testPeople(_ db:DaybookDatabase,_ url:URL) async throws {
        for id in ["manual:alice","ios:alice"] {
            try db.execute(#"INSERT INTO contacts(id,origin_type,system_contact_identifier,display_name,emails_json,phone_numbers_json,sync_state,created_at,updated_at) VALUES(?,?,?,'Alice','[{"label":"email","value":"PRIVATE_EMAIL"}]','[]',?,0,0)"#,[.text(id),.text(id.hasPrefix("manual") ? "manual" : "ios"),id.hasPrefix("manual") ? .null : .text("alice"),.text(id.hasPrefix("manual") ? "manual" : "current")])
        }
        let beforeTableReader=AskAINotebookReader(databaseURL:url,permissions:.init(allowPeople:true),scope:.init(domains:[.people],allowedKinds:[.voice]))
        let beforeTable=try await beforeTableReader.execute(name:"searchNotebook",arguments:Data(#"{"type":"people","query":"Alice"}"#.utf8))
        try check(beforeTable.matchedCount==2,"profiles searchable before optional relationship schema exists")
        try db.execute("CREATE TABLE notebook_contact_relationships(contact_id TEXT,relationship TEXT,position INTEGER)")
        try db.execute("INSERT INTO notebook_contact_relationships VALUES('manual:alice','friend',0)")
        let afterNewTable=try await beforeTableReader.validateEvidence(beforeTable.evidenceRefs)
        try check(!afterNewTable,"installing newly appearing table bumps domain revision for pre-trigger writes")
        let session=UUID().uuidString,key="session:"+session
        try db.execute("INSERT INTO recording_sessions(id,started_at,created_at) VALUES(?,100,100)",[.text(session)])
        try db.execute("INSERT INTO audio_processing_sources(source_key,kind,source_id,session_id,descriptor,fingerprint,configuration_key) VALUES(?,'session',?,?,?,'f','c')",[.text(key),.text(session),.text(session),.blob(Data(#"{"origin":{"device":"iPhone"}}"#.utf8))])
        try db.execute("INSERT INTO audio_processing_jobs(id,source_key,configuration_key,core_start,core_end,window,state,result) VALUES('people-j',?,'c',0,20,?,'completed',?)",[.text(key),.blob(Data()),.blob(Data())])
        for (position,start,end,text,speaker) in [(0,2.0,5.0,"ALICE_ONLY","a"),(1,6.0,8.0,"OTHER_PERSON","b"),(2,14.0,16.0,"GAP_SPEECH","a")] {
            try db.execute("INSERT INTO audio_transcript_spans(job_id,position,start,end,text,speaker_id) VALUES('people-j',?,?,?,?,?)",[.integer(Int64(position)),.real(start),.real(end),.text(text),.text(speaker)])
        }
        try db.execute("INSERT INTO recording_speaker_contacts(source_key,speaker_id,contact_id,linked_at,speaker_revision) VALUES(?,'a','manual:alice',0,'old')",[.text(key)])
        let payload=Data(#"{"title":"Shared segment","isFinal":true,"hasText":true,"editorial":{"classification":"meaningful"}}"#.utf8)
        for id in ["real-segment","gap-segment"] { try db.execute("INSERT INTO content_segments(id,source_key,start,revision,payload) VALUES(?,?,0,1,?)",[.text(id),.text(key),.blob(payload)]) }
        for (id,position,start,end) in [("real-segment",0,0.0,10.0),("gap-segment",0,10.0,12.0),("gap-segment",1,18.0,20.0)] {
            try db.execute("INSERT INTO content_segment_ranges(segment_id,position,start,end,payload) VALUES(?,?,?,?,?)",[.text(id),.integer(Int64(position)),.real(start),.real(end),.blob(Data())])
        }
        let reader=AskAINotebookReader(databaseURL:url,permissions:.init(allowPeople:true),scope:.init(domains:[.people],allowedKinds:[.voice]))
        let candidates=try await reader.execute(name:"searchNotebook",arguments:Data(#"{"type":"people","query":"Alice"}"#.utf8))
        try check(candidates.matchedCount==2 && Set(candidates.items.map(\.id))==["manual:alice","ios:alice"],"same names retain original candidate IDs")
        try check(!String(decoding:try JSONEncoder().encode(candidates),as:UTF8.self).contains("PRIVATE_EMAIL"),"email private unless explicitly requested")
        let speech=try await reader.execute(name:"listPersonSegments",arguments:Data(#"{"contactID":"manual:alice"}"#.utf8))
        try check(speech.matchedCount==1 && speech.items.first?.text=="ALICE_ONLY","actual range overlap; no unrelated speech or min-max gaps")
        try check(speech.items.first?.fields["identityNeedsReview"]=="true","identity review explicit")
        let remote=AskAINotebookReader(databaseURL:url,permissions:.init(allowPeople:true),scope:.init(domains:[.people],allowedKinds:[.voice],destination:.allowedRemote))
        let remoteSpeech=try await remote.execute(name:"listPersonSegments",arguments:Data(#"{"contactID":"manual:alice"}"#.utf8))
        let saved=try JSONDecoder().decode(AgentEvidenceRef.self,from:JSONEncoder().encode(remoteSpeech.evidenceRefs[0]))
        let local=AskAINotebookReader(databaseURL:url,permissions:.init(allowLedger:true,allowPeople:true),scope:.init(domains:[.people,.ledger],allowedKinds:[.voice]))
        try check(try await local.detail(for:saved).items.first?.text == "ALICE_ONLY","remote person report reopens locally preserving original query scope")
        try db.execute("DELETE FROM recording_speaker_contacts WHERE contact_id='manual:alice'")
        try check(try await !reader.validateEvidence(speech.evidenceRefs),"speaker rebind invalidates")
    }
    static func testPlaces(_ db:DaybookDatabase,_ url:URL) async throws {
        try db.execute("CREATE TABLE notebook_place_labels(place_id TEXT PRIMARY KEY,name TEXT,type TEXT,revision INTEGER)")
        try db.execute("CREATE TABLE notebook_place_evidence(id TEXT PRIMARY KEY,place_id TEXT,source_id TEXT,source_kind TEXT,captured_at REAL,day TEXT,time_zone TEXT,date_basis TEXT,display_label TEXT,coordinate_label TEXT)")
        try db.execute("INSERT INTO notebook_place_labels VALUES('grid-v1:1:2','Cafe','cafe',1)")
        for i in 0..<20 {
            try db.execute("INSERT INTO photo_moments(id,captured_at,caption,recognized_text) VALUES(?,0,'','')",[.text("photo-\(i)")])
            try db.execute("INSERT INTO notebook_place_evidence VALUES(?,'grid-v1:1:2',?,'照片',0,'2026-11-08','Asia/Singapore','saved original local date','Cafe','SECRET_COORDINATES')",[.text("obs-\(i)"),.text("photo-\(i)")]) }
        let now=ISO8601DateFormatter().date(from:"2026-11-08T12:00:00Z")!
        let reader=AskAINotebookReader(databaseURL:url,permissions:.init(allowPlaces:true),scope:.init(domains:[.places],allowedKinds:[.image,.location]),now:now)
        let visits=try await reader.execute(name:"listPlaceVisits",arguments:Data(#"{"placeID":"grid-v1:1:2","start":"2026-09-01","end":"2026-11-09"}"#.utf8))
        try check(visits.matchedCount==1 && visits.status=="partial" && visits.availableRange.count==2,"20 observations one saved day; older range partial")
        try check(visits.items[0].fields["sourceCount"]=="20" && visits.items[0].text.contains("Asia/Singapore"),"source count and date timezone basis")
        let details=try await reader.detail(for:visits.evidenceRefs[0])
        let detailsNext=try await reader.detail(for:visits.evidenceRefs[0],offset:10)
        try check(details.matchedCount==20 && details.items.count==10 && details.nextCursor=="10" && detailsNext.items.count==10 && Set((details.items+detailsNext.items).map(\.id)).count==20,"day citation opens all individual sources with real SQL paging")
        let search=try await reader.execute(name:"searchNotebook",arguments:Data(#"{"type":"places","query":"Cafe"}"#.utf8))
        try check(search.matchedCount==1 && search.items[0].id=="grid-v1:1:2","places search returns stable distinct grid entity")
        try check(!String(decoding:try JSONEncoder().encode(search),as:UTF8.self).contains("SECRET_COORDINATES"),"raw coordinates excluded")
        let remote=AskAINotebookReader(databaseURL:url,permissions:.init(allowPlaces:true),scope:.init(domains:[.places],allowedKinds:[.image,.location],destination:.allowedRemote),now:now)
        let remoteVisits=try await remote.execute(name:"listPlaceVisits",arguments:Data(#"{"placeID":"grid-v1:1:2"}"#.utf8))
        let saved=try JSONDecoder().decode(AgentEvidenceRef.self,from:JSONEncoder().encode(remoteVisits.evidenceRefs[0]))
        let local=AskAINotebookReader(databaseURL:url,permissions:.init(allowIdeas:true,allowPlaces:true),scope:.init(domains:[.places,.ideas],allowedKinds:[.image,.location]),now:now)
        try check(try await local.detail(for:saved).matchedCount == 20,"remote place/day report reopens original subset with observation count")
        try db.execute("DELETE FROM photo_moments")
        let removed=try await reader.execute(name:"listPlaceVisits",arguments:Data(#"{"placeID":"grid-v1:1:2"}"#.utf8))
        try check(removed.matchedCount==0 && removed.items.isEmpty,"deleted originals excluded without rebuilding evidence index")
        try check(try await !reader.validateEvidence(search.evidenceRefs),"source deletion invalidates place scope")
    }
    static func testInitializationOrder(_ db:DaybookDatabase,_ url:URL) throws {
        let legacy=url.deletingLastPathComponent().appendingPathComponent("nonexistent-\(UUID()).json")
        let store=DaybookConversationStore(url:legacy,database:db)
        _=try store.load()
        try AskAINotebookReader.installMutationTracking(database:db)
        let prior=try db.query("SELECT revision FROM ask_ai_memory_entity_revisions WHERE domain='ledger' AND entity_id='$domain'")[0]["revision"]?.string
        try db.execute("UPDATE flash_assets SET revision=revision+1 WHERE id='usd'")
        let next=try db.query("SELECT revision FROM ask_ai_memory_entity_revisions WHERE domain='ledger' AND entity_id='$domain'")[0]["revision"]?.string
        try check(prior != next,"Reader-first shared migration and business trigger")
        let memory=try DaybookDatabase(inMemory:true)
        _=try DaybookConversationStore(url:legacy,database:memory).load()
        try AskAINotebookReader.installMutationTracking(database:memory)
        try check(try memory.query("SELECT name FROM sqlite_master WHERE name='ask_ai_memory_entity_revisions'").count==1,"Store-first shared migration")
    }

    static func testMutationMemory(_ db:DaybookDatabase,_ url:URL) async throws {
        let store=DaybookConversationStore(url:url.deletingLastPathComponent().appendingPathComponent("absent-\(UUID()).json"),database:db)
        let runtime=AskAIRuntimeStore(conversationStore:store),day=Date(timeIntervalSinceReferenceDate:100)
        let reader=AskAINotebookReader(databaseURL:url,permissions:.init(allowLedger:true),scope:.init(domains:[.ledger]))
        let budget=AskAIContextBudget.policy(window:4096,isCustom:true).working
        func makeTurn(_ refs:[AgentEvidenceRef])->DaybookConversationTurn {
            var turn=DaybookConversationTurn(id:UUID(),question:"Ledger total?",text:"Historical ledger total",generated:true,provider:"synthetic",evidence:.init(records:[],dayStart:day,dayEnd:day.addingTimeInterval(86400),allowedKinds:[]),sources:[],scopeDescription:"",state:.completed,createdAt:day)
            turn.evidenceRefs=refs;turn.notebookPermissions = .init(allowLedger:true);return turn
        }
        func block(_ turn:DaybookConversationTurn) throws -> AskAIMemoryBlock {
            let candidate=AskAIMemoryBlock.candidate(turns:[turn],permissionDigest:"fixture-permissions",budget:budget)!
            let summary=AskAIMemorySummary(topics:[.init(text:"We discussed the historical ledger total",turnIDs:[turn.id])],explicitDecisions:[],corrections:[],unresolved:[],aiProposals:[],entityRefs:[])
            return try AskAIMemoryBlock.parse(JSONEncoder().encode(summary),candidate:candidate,model:"synthetic")
        }
        let original=makeTurn(try await reader.execute(name:"aggregateLedger",arguments:Data("{}".utf8)).evidenceRefs)
        try store.saveTurn(original,day:day)
        let generation=try await runtime.cacheGeneration(),old=try block(original)
        try await runtime.saveMemoryBlock(old,expectedGeneration:generation)
        try db.execute("UPDATE flash_assets SET revision=revision+1,amount_minor=101 WHERE id='usd'")
        let invalidated=try await runtime.loadMemoryBlocks(permissionDigest:"fixture-permissions")
        try check(invalidated.isEmpty,"business mutation SQL trigger invalidates memory via exact domain counter")
        do { try await runtime.saveMemoryBlock(old,expectedGeneration:generation);throw Failed.check("late stale block restored") } catch AskAIRuntimeStore.Failure.staleAttempt {}
        let fresh=makeTurn(try await reader.execute(name:"aggregateLedger",arguments:Data("{}".utf8)).evidenceRefs)
        try store.saveTurn(fresh,day:day)
        try await runtime.saveMemoryBlock(block(fresh),expectedGeneration:generation)
        let accepted=try await runtime.loadMemoryBlocks(permissionDigest:"fixture-permissions")
        try check(accepted.count==1,"fresh post-edit summary accepts new domain revision")
        try db.execute("UPDATE contacts SET display_name='Unrelated person edit' WHERE id='manual:alice'")
        let unrelated=try await runtime.loadMemoryBlocks(permissionDigest:"fixture-permissions")
        try check(unrelated.count==1,"unrelated domain mutation retains ledger memory")
    }
    static func testIndex(_ db:DaybookDatabase,_ url:URL) async throws {
        try db.execute("INSERT INTO flash_assets VALUES('fts-current','parent','idea',0,1,0,1,NULL,NULL,NULL,?)",[.blob(Data(#"{"title":"Blue concept","text":"Green theme"}"#.utf8))])
        let reader=AskAINotebookReader(databaseURL:url,permissions:.init(allowIdeas:true),scope:.init(domains:[.ideas]))
        let result=try await reader.execute(name:"searchNotebook",arguments:Data(#"{"type":"ideas","query":"Blue Green"}"#.utf8))
        try check(result.matchedCount==1 && result.searchMode.contains("FTS"),"incremental FTS finds terms across title/body with honest keyword mode")
        try check(try db.query("SELECT id FROM ask_ai_notebook_text WHERE domain='ideas'").contains(where:{$0["id"]?.string=="ideas:fts-current"}),"projection IDs namespaced")
        try db.execute("UPDATE flash_assets SET payload=?,revision=revision+1 WHERE id='fts-current'",[.blob(Data(#"{"title":"Changed","text":"Current text"}"#.utf8))])
        // Simulate a lagging index: current-version check must exclude stale FTS even before queue processing.
        let stale=try db.readTransaction { try AskAINotebookIndex.matches(database:db,domain:.ideas,query:"Blue Green") }
        try check(stale.isEmpty,"old projection hits cannot disclose stale text")
        let current=try await reader.execute(name:"searchNotebook",arguments:Data(#"{"type":"ideas","query":"Changed Current"}"#.utf8))
        try check(current.items.first?.text=="Current text","mutation outbox updates projection incrementally")
        try db.execute("DELETE FROM flash_assets WHERE id='fts-current'")
        _=try await reader.execute(name:"searchNotebook",arguments:Data(#"{"type":"ideas","query":"Changed"}"#.utf8))
        try check(try db.query("SELECT id FROM ask_ai_notebook_text WHERE entity_id='fts-current'").isEmpty,"deletion outbox removes projection")
        for i in 0..<47 {
            try db.execute("INSERT INTO flash_assets VALUES(?, 'parent','idea',0,1,0,1,NULL,NULL,NULL,?)",[.text("many-\(i)"),.blob(Data(#"{"title":"Violet concept","text":"Amber theme"}"#.utf8))])
        }
        let many=try await reader.execute(name:"searchNotebook",arguments:Data(#"{"type":"ideas","query":"Violet Amber"}"#.utf8))
        try check(many.matchedCount==47 && many.items.count==10 && many.nextCursor != nil,"more than32 FTS candidates retain exact full SQL token matchedCount")
        try check(many.searchMode.contains("incremental"),"partial index backfill coverage labeled honestly")
    }

}

import Foundation

@MainActor private final class ScriptDriver: AskAIDriving {
    var replies: [Result<AskAIDriverReply,Error>]
    var sent: [String] = []; var results: [String] = []; var starts = 0
    var wait = false
    var delayNanoseconds: UInt64 = 0
    var onNext: (@MainActor () async throws -> Void)?
    init(_ replies:[Result<AskAIDriverReply,Error>]) { self.replies = replies }
    func start(instruction:String,content:String) throws { starts += 1; sent.append(content) }
    func rebuild() throws { starts += 1 }
    func next(correction:String?) async throws -> AskAIDriverReply {
        if let correction { sent.append(correction) }
        if let onNext { self.onNext = nil; try await onNext() }
        if delayNanoseconds > 0 { try await Task.sleep(nanoseconds:delayNanoseconds) }
        if wait { try await Task.sleep(nanoseconds:5_000_000_000) }
        guard !replies.isEmpty else { throw AIServiceError.invalidResponse }
        return try replies.removeFirst().get()
    }
    func receive(call:AskAIToolCall,result:String) throws { results.append(result) }
}
private final class PublicationGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value:0)
    private var entered = false
    private var first = true
    var didEnter: Bool { lock.lock(); defer { lock.unlock() }; return entered }
    func pauseOnce() {
        lock.lock(); let shouldPause = first; first = false; if shouldPause { entered = true }; lock.unlock()
        if shouldPause { semaphore.wait() }
    }
    func release() { semaphore.signal() }
}
private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    static var handler: (URLRequest) throws -> (Int,[String:Any]) = { _ in (500,[:]) }
    override class func canInit(with request:URLRequest) -> Bool { true }
    override class func canonicalRequest(for request:URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status,body) = try Self.handler(request)
            client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:try JSONSerialization.data(withJSONObject:body)); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() {}
}
@MainActor private struct NoFallback: DaybookAnswering {
    func answer(_ prepared:DaybookRetrieval.Prepared,configuration:AIConfiguration,apiKey:String?) async throws -> String { throw AIServiceError.invalidResponse }
}
private final class RuntimeAccountStore: ChatGPTAccountStoring {
    var vault: ChatGPTAccountVault
    init(_ vault: ChatGPTAccountVault) { self.vault = vault }
    func load() throws -> ChatGPTAccountVault? { vault }
    func save(_ vault: ChatGPTAccountVault) throws { self.vault = vault }
}
private actor RuntimeAccountAPI: ChatGPTServing {
    var refreshes = 0, catalogs = 0, requests = 0
    nonisolated func authorizationURL(attempt:ChatGPTAuthorizationAttempt) throws -> URL { URL(string:"https://fixture.invalid/authorize")! }
    func exchange(callbackURL:URL,attempt:ChatGPTAuthorizationAttempt) async throws -> ChatGPTCredential { throw ChatGPTError.invalidCallback }
    func refresh(_ credential:ChatGPTCredential) async throws -> ChatGPTCredential {
        refreshes += 1; try await Task.sleep(nanoseconds:40_000_000)
        return ChatGPTCredential(clientID:credential.clientID,subject:credential.subject,email:nil,hostID:credential.hostID,idToken:"fixture",accessToken:"fixture",refreshToken:"fixture",expiresAt:.now.addingTimeInterval(3600),scopes:credential.scopes)
    }
    func models(accessToken:String) async throws -> [ChatGPTModel] { catalogs += 1; try await Task.sleep(nanoseconds:40_000_000); return [.init(id:"fixture-model",displayName:"Fixture")] }
    func complete(instruction:String,content:String,model:String,accessToken:String) async throws -> String { requests += 1; return "fixture [1]" }
    func revoke(_ credential:ChatGPTCredential) async throws {}
    func counts() -> (Int,Int,Int) { (refreshes,catalogs,requests) }
}
@main struct AskAIDriversSmoke {
    struct Failed: Error { let message:String }
    static func check(_ condition:@autoclosure () throws -> Bool,_ message:String) throws { if try !condition() { throw Failed(message:message) } }
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ask-ai-drivers-" + UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true); defer { try? FileManager.default.removeItem(at:directory) }
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
        let day = calendar.date(from:DateComponents(year:2026,month:11,day:1))!
        let records = [DayRecord(id:UUID(),capturedAt:day,kind:.voice,title:"Synthetic project",text:"project evidence one"), DayRecord(id:UUID(),capturedAt:day.addingTimeInterval(2),kind:.voice,title:"Synthetic second",text:"project evidence two")]
        var retrieval = DaybookRetrieval(); retrieval.calendar = calendar
        let original = try retrieval.prepare(question:"project",records:records,selectedDate:day,allowedKinds:[.voice])
        let fixtureDB = try DaybookDatabase(url:directory.appendingPathComponent("fixture.sqlite"))
        let conversations = DaybookConversationStore(url:directory.appendingPathComponent("history.json"),database:fixtureDB)
        let store = AskAIRuntimeStore(conversationStore:conversations)
        var previews:[String] = []
        func runtime(_ driver:ScriptDriver,remote:Bool = false) throws -> (AskAIRuntime,UUID) {
            let id = UUID()
            let turn = DaybookConversationTurn(id:id,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending)
            try conversations.saveTurn(turn,day:day)
            var configuration = AIConfiguration(); configuration.mode = remote ? .custom : .local
            let engine = AskAIRuntime(prepared:original,records:records,configuration:configuration,configurationRevision:1,turnID:id,store:store,isCurrent:{true},onStage:{_ in},authorizeAdditional:{ text in previews.append(text) })
            engine.testDriver = driver; return (engine,id)
        }
        func reply(_ text:String = "",_ calls:[AskAIToolCall] = []) -> Result<AskAIDriverReply,Error> { .success(.init(text:text,calls:calls)) }
        let call = AskAIToolCall(id:"call-1",name:"searchRecords",arguments:Data(#"{"query":"project"}"#.utf8))
        let scripted = ScriptDriver([reply("",[call]),reply("uncited answer"),reply("Evidence [1]")])
        let (engine,id) = try runtime(scripted,remote:true)
        let bounded = try await engine.prepare()
        try check(AskAIContextBudget().fits(instruction:engine.instruction,content:CustomAISummarizer.answerContent(question:bounded.providerQuestion,context:bounded.context),tools:String(data:try JSONSerialization.data(withJSONObject:engine.loadedToolDefinitions,options:.sortedKeys),encoding:.utf8)!),"initial actual input budget")
        let answer = try await engine.generate(apiKey:nil,fallback:NoFallback())
        try check(answer.sources.count == 1 && scripted.results.count == 1 && previews == scripted.results,"exact supplemental outgoing tool result consent")
        try check(scripted.sent.count == 2 && scripted.sent[1].contains("来源编号"),"one citation repair")
        let final = DaybookConversationTurn(id:id,question:original.question,text:answer.text,generated:true,provider:"fixture",evidence:answer.prepared.evidence,sources:answer.sources,scopeDescription:"",state:.completed,evidenceRefs:answer.evidenceRefs,runProvenance:answer.runProvenance)
        try await engine.publish(final); try await engine.publish(final)
        let saved = try await store.runtimeTurn(id:id)
        try check(saved?.turn.text == answer.text,"atomic idempotent publication")
        let repeated = ScriptDriver([reply("",[call]),reply("",[call])]); let (repeatEngine,_) = try runtime(repeated)
        _ = try await repeatEngine.prepare()
        do { _ = try await repeatEngine.generate(apiKey:nil,fallback:NoFallback()); throw Failed(message:"duplicate call id accepted") } catch AskAIRuntime.Failure.repeatedCall {}
        let overflow = ScriptDriver([.failure(AskAIRuntime.Failure.contextOverflow),reply("answer [1]")]); let (overflowEngine,_) = try runtime(overflow)
        _ = try await overflowEngine.prepare(); _ = try await overflowEngine.generate(apiKey:nil,fallback:NoFallback())
        try check(overflow.starts == 2,"single overflow rebuild")
        let twice = ScriptDriver([.failure(AskAIRuntime.Failure.contextOverflow),.failure(AskAIRuntime.Failure.contextOverflow)]); let (twiceEngine,_) = try runtime(twice)
        _ = try await twiceEngine.prepare()
        do { _ = try await twiceEngine.generate(apiKey:nil,fallback:NoFallback()); throw Failed(message:"second overflow accepted") } catch AskAIRuntime.Failure.contextOverflow {}
        let bad = ScriptDriver([reply("invented [999]"),reply("invented [999]")]); let (badEngine,_) = try runtime(bad)
        _ = try await badEngine.prepare()
        do { _ = try await badEngine.generate(apiKey:nil,fallback:NoFallback()); throw Failed(message:"out of ledger accepted") } catch DaybookAnswerFailure.missingCitations {}
        let cancelled = ScriptDriver([reply("answer [1]")]); let (cancelEngine,cancelID) = try runtime(cancelled)
        _ = try await cancelEngine.prepare(); let candidate = try await cancelEngine.generate(apiKey:nil,fallback:NoFallback()); cancelEngine.cancel()
        do { try await cancelEngine.publish(.init(id:cancelID,question:original.question,text:candidate.text,generated:true,provider:"fixture",evidence:original.evidence,sources:candidate.sources,scopeDescription:"",state:.completed,evidenceRefs:candidate.evidenceRefs,runProvenance:candidate.runProvenance)); throw Failed(message:"late publish") } catch is CancellationError {}
        let slow = ScriptDriver([reply("answer [1]")]); slow.wait = true; let (deadline,_) = try runtime(slow); deadline.activeDeadline = 0.08
        _ = try await deadline.prepare()
        do { _ = try await deadline.generate(apiKey:nil,fallback:NoFallback()); throw Failed(message:"deadline did not cancel request") } catch AskAIRuntime.Failure.deadline {}
        let manyCalls = (0..<7).map { AskAIToolCall(id:"c\($0)",name:"searchRecords",arguments:call.arguments) }
        let limited = ScriptDriver(manyCalls.map { reply("",[$0]) }); let (limitEngine,_) = try runtime(limited)
        _ = try await limitEngine.prepare()
        do { _ = try await limitEngine.generate(apiKey:nil,fallback:NoFallback()); throw Failed(message:"tool/request limit bypass") } catch AskAIReadTools.Failure.callLimit {} catch AskAIRuntime.Failure.requestLimit {} catch AskAIRuntime.Failure.contextOverflow {}
        let repeatQuery = ScriptDriver([reply("",[call]), reply("",[.init(id:"call-2",name:call.name,arguments:call.arguments)]), reply("verified [1]")])
        let (repeatQueryEngine,_) = try runtime(repeatQuery)
        _ = try await repeatQueryEngine.prepare(); _ = try await repeatQueryEngine.generate(apiKey:nil,fallback:NoFallback())
        try check(repeatQuery.results.count == 2 && repeatQuery.results[0] == repeatQuery.results[1],"same query with distinct ids is legal and stable")
        let errors = (0..<6).map { AskAIToolCall(id:"error-\($0)",name:"unknown",arguments:Data("{}".utf8)) }
        let exhausted = ScriptDriver(errors.map { reply("",[$0]) } + [.failure(AskAIRuntime.Failure.contextOverflow), reply("uncited"), reply("answer [1]")])
        let (exhaustEngine,_) = try runtime(exhausted)
        _ = try await exhaustEngine.prepare()
        do { _ = try await exhaustEngine.generate(apiKey:nil,fallback:NoFallback()); throw Failed(message:"repair request exceeded eight") } catch AskAIRuntime.Failure.requestLimit {}
        try check(exhausted.results.count == 6 && exhausted.results.allSatisfy { $0.contains("status=error") && !$0.contains("status=empty") },"errors consume budget and remain distinguishable")
        let native = ScriptDriver([reply("native verified [1]")]); let (nativeEngine,_) = try runtime(native)
        _ = try await nativeEngine.prepare()
        var nativeResults: [String] = []
        native.onNext = {
            nativeResults.append(try await nativeEngine.executeNative(call))
            nativeResults.append(try await nativeEngine.executeNative(.init(id:"native-two",name:call.name,arguments:call.arguments)))
        }
        _ = try await nativeEngine.generate(apiKey:nil,fallback:NoFallback())
        try check(nativeResults.count == 2 && nativeResults[0] == nativeResults[1],"actual native callback boundary uses shared budgets and tools")
        let nativeConversation = native.sent[0] + "native verified [1]"
        let nativeSchemas = String(data:try JSONSerialization.data(withJSONObject:nativeEngine.loadedToolDefinitions,options:.sortedKeys),encoding:.utf8)!
        var foundNativeBoundary = false
        for count in stride(from:0,to:3500,by:5) {
            let correction = String(repeating:"修",count:count)
            guard AskAIContextBudget(inputLimit:3584).fits(instruction:nativeEngine.instruction,content:nativeConversation + correction,tools:nativeSchemas) else { continue }
            do { try nativeEngine.validateNextContext(correction:correction,conversation:nativeConversation) }
            catch AskAIRuntime.Failure.contextOverflow { foundNativeBoundary = true; break }
        }
        try check(foundNativeBoundary,"repair boundary must include actual native callback results rather than the smaller driver conversation")
        try await fallbackFreshness(original)
        let pendingDriver = ScriptDriver([]); let (pendingEngine,pendingID) = try runtime(pendingDriver)
        _ = try await pendingEngine.prepare(); pendingEngine.cancel(reason: "inactive")
        await pendingEngine.fail(CancellationError())
        try await Task.sleep(nanoseconds:50_000_000)
        let pending = try await store.runtimeTurn(id:pendingID)
        try check(pending?.turn.completionState == .cancelled,"initial preview cancellation terminalizes durable pending turn")
        let cancellation = try fixtureDB.query("SELECT error_code FROM ask_ai_runs WHERE turn_id=?", [.text(pendingID.uuidString)])
        try check(cancellation.first?["error_code"]?.string == "inactive", "late generic failure must preserve the explicit interruption cause")
        let fence = AskAIPublicationFence(); fence.invalidate()
        let leasedID = UUID(); let leased = DaybookConversationTurn(id:leasedID,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending)
        try conversations.saveTurn(leased,day:day)
        let leasedRun = try await store.startAttempt(turnID:leasedID,provider:"fixture",model:"fixture",configRevision:"1")
        do { try await store.completeAttempt(runID:leasedRun.id,turn:leased.replacing(text:"forbidden",state:.completed),publicationFence:fence); throw Failed(message:"transaction ignored invalid lease") } catch is CancellationError {}
        let leasedStored = try await store.runtimeTurn(id:leasedID)
        try check(leasedStored?.turn.completionState == .pending,"fenced SQL rolled back")
        let cacheGeneration = try await store.cacheGeneration()
        let fencedMemory = AskAIRollingMemory.build(turns:[final],dependencyDigest:"fenced-cache")
        do { try await store.saveMemory(fencedMemory,anchorTurnID:id,expectedGeneration:cacheGeneration,publicationFence:fence); throw Failed(message:"memory cache ignored cancelled fence") } catch is CancellationError {}
        let fencedCheckpoint = AskAIRuntimeStore.Checkpoint(anchorTurnID:id,providerConfigDigest:"fixture",formatVersion:"1",toolVersion:"1",promptVersion:"1",inputDigest:"fixture",permissionDigest:"fixture",sourceDigest:"fixture",payload:Data("fixture".utf8))
        do { try await store.saveCheckpoint(fencedCheckpoint,expectedGeneration:cacheGeneration,publicationFence:fence); throw Failed(message:"checkpoint cache ignored cancelled fence") } catch is CancellationError {}
        for outcome in ["unchanged","changed","superseded"] {
            let once = ScriptDriver([reply("queued evidence [1]")]); let (publicationEngine,publicationID) = try runtime(once)
            _ = try await publicationEngine.prepare(); let publicationAnswer = try await publicationEngine.generate(apiKey:nil,fallback:NoFallback())
            let publication = DaybookConversationTurn(id:publicationID,question:original.question,text:publicationAnswer.text,generated:true,provider:"fixture",evidence:publicationAnswer.prepared.evidence,sources:publicationAnswer.sources,scopeDescription:"",state:.completed,evidenceRefs:publicationAnswer.evidenceRefs,runProvenance:publicationAnswer.runProvenance)
            let gate = PublicationGate(); publicationEngine.beforePublicationLease = { gate.pauseOnce() }
            let pendingPublication = Task { try await publicationEngine.publish(publication) }
            while !gate.didEnter { await Task.yield() }
            let oldValidation = UUID(); let latestValidation = UUID()
            publicationEngine.suspendPublication(validation:oldValidation)
            if outcome == "superseded" { publicationEngine.suspendPublication(validation:latestValidation); publicationEngine.resumePublication(validation:oldValidation) }
            gate.release()
            let stillPending = try await store.runtimeTurn(id:publicationID)
            try check(stillPending?.turn.completionState == .pending,"queued transaction must not publish while scope validation is pending")
            let runState = try fixtureDB.query("SELECT state FROM ask_ai_runs WHERE turn_id=?",[.text(publicationID.uuidString)]).first?["state"]?.string
            try check(runState != "completed","pending validation keeps run incomplete")
            if outcome == "changed" {
                publicationEngine.cancel()
                do { try await pendingPublication.value; throw Failed(message:"changed validation published old answer") } catch is CancellationError {}
                let changed = try await store.runtimeTurn(id:publicationID)
                try check(changed?.turn.completionState != .completed,"relevant edit prevents stale success")
            } else {
                publicationEngine.resumePublication(validation:outcome == "superseded" ? latestValidation : oldValidation)
                try await pendingPublication.value
                let published = try await store.runtimeTurn(id:publicationID)
                let completedRuns = try fixtureDB.query("SELECT COUNT(*) AS n FROM ask_ai_runs WHERE turn_id=? AND state='completed'",[.text(publicationID.uuidString)]).first?["n"]?.double
                try check(published?.turn.text == publicationAnswer.text && completedRuns == 1 && once.replies.isEmpty && once.starts == 1,"unchanged latest validation publishes exactly once without inference")
            }
        }
        try await unsupportedFallback(original,records:records,day:day,store:store,conversations:conversations)
        try await protocols()
        try await configurableSchemas()
        try await notebookRuntime()
        try await runtimeCompaction()
        try await transitiveProvenance()
        try await pagedOriginalRuntime()
        try await scopedLedgerFallback()
        try check(AskAIRuntime.policy(configuration: { var value = AIConfiguration(); value.mode = .custom; value.contextWindowTokens = 16384; return value }()).working.windowTokens == 16384, "runtime must honor configured 16K model window")
        print("Ask AI drivers: bounded actual runtime, exact consent, call pairing, repair, overflow, limits, deadline, cancellation, atomic publication and synthetic protocol fixtures passed")
    }
    @MainActor static func scopedLedgerFallback() async throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("scoped-ledger-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
        let url=dir.appendingPathComponent("db.sqlite"),db=try DaybookDatabase(url:url)
        try db.execute("CREATE TABLE flash_assets(id TEXT PRIMARY KEY,source_id TEXT,kind TEXT,captured_at REAL,revision INTEGER,revoked INTEGER,ready INTEGER,currency TEXT,direction TEXT,amount_minor INTEGER,payload BLOB)")
        for (id,date,category,direction,amount) in [("wanted","2026-11-02","餐饮","expense",100),("other-category","2026-11-02","交通","expense",200),("last-month","2026-10-02","餐饮","expense",400),("income","2026-11-02","餐饮","income",800)] {
            try db.execute("INSERT INTO flash_assets VALUES(?,'gone','expense',0,1,0,1,'CNY',?,?,?)",[.text(id),.text(direction),.integer(Int64(amount)),.blob(try JSONSerialization.data(withJSONObject:["title":"saved","text":"saved","date":date,"category":category]))])
        }
        let conversations=DaybookConversationStore(url:dir.appendingPathComponent("legacy.json"),database:db),store=AskAIRuntimeStore(conversationStore:conversations)
        let settings=URLSessionConfiguration.ephemeral;settings.protocolClasses=[FixtureProtocol.self]
        let session=URLSession(configuration:settings);defer{session.invalidateAndCancel()}
        var config=AIConfiguration();config.mode = .custom;config.model="fixture";config.baseURL="https://fixture.invalid/v1"
        let permissions=AgentNotebookPermissions(allowLedger:true),scope=AgentQueryScope(domains:permissions.allowedDomains,allowedKinds:[.voice],destination:.allowedRemote)
        let reader=AskAINotebookReader(databaseURL:url,permissions:permissions,scope:scope),now=ISO8601DateFormatter().date(from:"2026-11-15T12:00:00Z")!
        for question in ["本月餐饮支出是多少","本月火星支出是多少"] {
            let original=try DaybookRetrieval().prepare(question:question,records:[],selectedDate:now,allowedKinds:[.voice]),id=UUID()
            try conversations.saveTurn(.init(id:id,question:question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
            let engine=AskAIRuntime(prepared:original,records:[],configuration:config,configurationRevision:1,turnID:id,store:store,notebookPermissions:permissions,notebookReader:reader,queryScope:scope,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
            engine.customSession=session;engine.queryNow=now;var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!;engine.queryCalendar=calendar
            var count=0
            FixtureProtocol.handler={request in
                var bytes=request.httpBody
                if bytes == nil,let stream=request.httpBodyStream {stream.open();defer{stream.close()};var data=Data(),buffer=[UInt8](repeating:0,count:4096);while stream.hasBytesAvailable{let n=stream.read(&buffer,maxLength:buffer.count);if n<=0{break};data.append(buffer,count:n)};bytes=data}
                count += 1;if count == 1{return(400,[:])}
                let text=String(decoding:bytes!,as:UTF8.self)
                try check(text.contains("amountMinor=100;") && !text.contains("amountMinor=200;") && !text.contains("amountMinor=400;") && !text.contains("amountMinor=800;"),"filtered fallback excludes October, other category and income")
                try check(text.contains("2026-11-01") && text.contains("2026-12-01") && text.contains("category=餐饮") && text.contains("direction=expense"),"compact aggregate includes actual resolved period and filters")
                return (200,["choices":[["finish_reason":"stop","message":["content":"本月餐饮支出1元 [1]"]]]])
            }
            _=try await engine.prepare()
            if question.contains("火星") {
                do{_=try await engine.generate(apiKey:"synthetic",fallback:DaybookAnswerService(customSummarizer:CustomAISummarizer(session:session)));throw Failed(message:"unresolved filter silently broadened")}catch AskAIRuntime.Failure.unresolvedLedgerFilters{}
                try check(count == 1,"unresolved qualifier stops before aggregate/text fallback")
            } else {
                let answer=try await engine.generate(apiKey:"synthetic",fallback:DaybookAnswerService(customSummarizer:CustomAISummarizer(session:session)))
                try check(count == 2 && answer.evidenceRefs.first?.domain == .ledger,"resolved no-tools query keeps exact ledger citation")
            }
            engine.cancel()
        }
    }
    @MainActor static func pagedOriginalRuntime() async throws {
        for notebook in [false,true] {
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent("paged-original-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
            let url=dir.appendingPathComponent("db.sqlite"),db=try DaybookDatabase(url:url)
            let conversations=DaybookConversationStore(url:dir.appendingPathComponent("legacy.json"),database:db),store=AskAIRuntimeStore(conversationStore:conversations)
            let original=try DaybookRetrieval().prepare(question:notebook ? "有哪些想法" : "之前的原始回答",records:[],selectedDate:.now,allowedKinds:[.voice])
            let body="1. "+String(repeating:"长内容保持连续。",count:65)+"\n2. 第二条精确目标，不能跳过。"
            let prior=UUID()
            if notebook {
                try db.execute("CREATE TABLE flash_assets(id TEXT PRIMARY KEY,source_id TEXT,kind TEXT,captured_at REAL,revision INTEGER,revoked INTEGER,ready INTEGER,currency TEXT,direction TEXT,amount_minor INTEGER,payload BLOB)")
                try db.execute("INSERT INTO flash_assets VALUES('idea-long','gone','idea',0,1,0,1,NULL,NULL,NULL,?)",[.blob(try JSONSerialization.data(withJSONObject:["title":"long idea","text":body]))])
            } else { try conversations.saveTurn(.init(id:prior,question:"原始问题",text:body,generated:true,provider:"fixture",evidence:original.evidence,sources:[],scopeDescription:"",state:.completed),day:original.dayStart) }
            let permissions=AgentNotebookPermissions(allowIdeas:true),scope=AgentQueryScope(domains:permissions.allowedDomains,allowedKinds:[.voice])
            let id=UUID();try conversations.saveTurn(.init(id:id,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
            let engine=AskAIRuntime(prepared:original,records:[],configuration:AIConfiguration(),configurationRevision:1,turnID:id,store:store,notebookPermissions:permissions,notebookReader:AskAINotebookReader(databaseURL:url,permissions:permissions,scope:scope),queryScope:scope,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
            let driver=ScriptDriver([.success(.init(text:"原始要点 [1]",calls:[]))]);engine.testDriver=driver;_=try await engine.prepare()
            var joined="",pages=0
            driver.onNext = {
                var offset=0
                repeat {
                    var args:[String:Any]=["offset":offset]
                    if notebook {args["type"]="ideas";args["id"]="idea-long"} else {args["id"]=prior.uuidString;args["limit"]=4000}
                    let text=try await engine.executeNative(.init(id:"page-\(pages)",name:notebook ? "readNotebookItem" : "readConversationTurn",arguments:try JSONSerialization.data(withJSONObject:args)))
                    pages += 1
                    let marker=notebook ? "long idea\n" : "Original answer (old source markers labeled historical):\n"
                    guard let range=text.range(of:marker) else { throw Failed(message:"missing original page body") }
                    var slice=String(text[range.upperBound...])
                    if notebook,let end=slice.range(of:"\nprovenance=") {slice=String(slice[..<end.lowerBound])}
                    if notebook,let end=slice.range(of:"\nparentQuotes=") {slice=String(slice[..<end.lowerBound])}
                    if notebook,let end=slice.range(of:"\nKeyword") {slice=String(slice[..<end.lowerBound])}
                    if notebook {
                        // Body ends before its fields line. Original body contains no metadata keys.
                        let rows=slice.components(separatedBy:"\n")
                        slice=rows.prefix { !$0.contains("capturedAt=") && !$0.contains("parentQuotes=") && !$0.contains("provenance=") && !$0.contains("keyword SQL") }.joined(separator:"\n")
                    }
                    joined += slice
                    let regex=try NSRegularExpression(pattern:#"nextOffset=(\d+|none)"#)
                    guard let match=regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)),let r=Range(match.range(at:1),in:text) else {throw Failed(message:"missing continuation")}
                    if text[r] == "none" {break}
                    let next=Int(text[r])!;try check(next>offset,"page offset advances after actually supplied text");offset=next
                } while pages<6
            }
            _=try await engine.generate(apiKey:nil,fallback:NoFallback())
            try check(joined == body && pages>1,"actual Runtime pages concatenate without skipped original text or ordinal points")
            engine.cancel()
        }
    }
    @MainActor static func transitiveProvenance() async throws {
        for localOnly in [false,true] {
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent("run-provenance-" + UUID().uuidString)
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
            let url=dir.appendingPathComponent("db.sqlite"),db=try DaybookDatabase(url:url)
            try db.execute("CREATE TABLE flash_assets(id TEXT PRIMARY KEY,source_id TEXT,kind TEXT,captured_at REAL,revision INTEGER,revoked INTEGER,ready INTEGER,currency TEXT,direction TEXT,amount_minor INTEGER,payload BLOB)")
            let payload:[String:Any]=["title":"Meal","text":"private saved body","date":"2026-11-02","requiresLocalAI":localOnly]
            try db.execute("INSERT INTO flash_assets VALUES('expense','gone','expense',0,1,0,1,'CNY','expense',1125,?)",[.blob(try JSONSerialization.data(withJSONObject:payload))])
            let conversations=DaybookConversationStore(url:dir.appendingPathComponent("legacy.json"),database:db),store=AskAIRuntimeStore(conversationStore:conversations)
            let permissions=AgentNotebookPermissions(allowIdeas:true,allowLedger:true),scope=AgentQueryScope(domains:permissions.allowedDomains,allowedKinds:[.voice])
            let reader=AskAINotebookReader(databaseURL:url,permissions:permissions,scope:scope)
            let day=Date.now,record=DayRecord(id:UUID(),capturedAt:day,kind:.voice,title:"project",text:"project current fact")
            func run(_ question:String,_ records:[DayRecord],_ replies:[Result<AskAIDriverReply,Error>]) async throws -> DaybookConversationTurn {
                let original=try DaybookRetrieval().prepare(question:question,records:records,selectedDate:day,allowedKinds:[.voice]),id=UUID()
                try conversations.saveTurn(.init(id:id,question:question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
                let engine=AskAIRuntime(prepared:original,records:records,configuration:AIConfiguration(),configurationRevision:1,turnID:id,store:store,notebookPermissions:permissions,notebookReader:reader,queryScope:scope,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
                engine.testDriver=ScriptDriver(replies);_=try await engine.prepare();let result=try await engine.generate(apiKey:nil,fallback:NoFallback())
                let turn=DaybookConversationTurn(id:id,question:question,text:result.text,generated:true,provider:"fixture",evidence:result.prepared.evidence,sources:result.sources,scopeDescription:"",state:.completed,evidenceRefs:result.evidenceRefs,notebookPermissions:permissions,runProvenance:result.runProvenance)
                try await engine.publish(turn);return try conversations.runtimeTurn(id:id)!
            }
            try db.execute("INSERT INTO flash_assets VALUES('idea','gone','idea',0,1,0,1,NULL,NULL,NULL,?)",[.blob(Data(#"{"title":"想法","text":"current permitted idea"}"#.utf8))])
            let a=try await run("记账花费",[],[.success(.init(text:"",calls:[.init(id:"ledger",name:"aggregateLedger",arguments:Data("{}".utf8))])),.success(.init(text:"LOCAL_NOTEBOOK_SECRET 金额11.25 [1]",calls:[]))])
            let arguments=try JSONSerialization.data(withJSONObject:["id":a.id.uuidString,"limit":400])
            let b=try await run("之前project",[record],[.success(.init(text:"",calls:[.init(id:"history",name:"readConversationTurn",arguments:arguments)])),.success(.init(text:"历史11.25 [2]，project [1]",calls:[]))])
            try check(b.runProvenance?.domains.contains(.ledger) == true && b.runProvenance?.historyTurnDigests[a.id.uuidString] != nil,"history citation preserves transitive authority")
            let c=try await run("有哪些想法",[],[.success(.init(text:"",calls:[.init(id:"idea",name:"readNotebookItem",arguments:Data(#"{"type":"ideas","id":"idea"}"#.utf8))])),.success(.init(text:"历史金额11.25，当前想法 [1]",calls:[]))])
            try check(c.evidenceRefs?.allSatisfy{$0.domain == .ideas} == true && c.runProvenance?.domains.contains(.ledger) == true,"automatically supplied history authority survives even when final display cites only timeline")
            let reopened=DaybookConversationStore(url:dir.appendingPathComponent("legacy.json"),database:try DaybookDatabase(url:url))
            try check(try reopened.runtimeTurn(id:c.id)?.runProvenance == c.runProvenance,"run provenance sidecar survives reopen")
            if localOnly {
                try check(c.disclosurePolicy == .localOnly,"consulted local-only source taints mixed answer independently of selected citations")
                var config=AIConfiguration();config.mode = .custom
                let prepared=try DaybookRetrieval().prepare(question:"project",records:[record],selectedDate:day,allowedKinds:[.voice]),id=UUID()
                try conversations.saveTurn(.init(id:id,question:prepared.question,text:"",generated:false,provider:"",evidence:prepared.evidence,sources:[],scopeDescription:"",state:.pending),day:prepared.dayStart)
                let remote=AskAIRuntime(prepared:prepared,records:[record],configuration:config,configurationRevision:1,turnID:id,store:store,notebookPermissions:permissions,notebookReader:reader,queryScope:.init(domains:permissions.allowedDomains,allowedKinds:[.voice],destination:.allowedRemote),isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
                let context=try await remote.prepare()
                try check(!context.context.contains("LOCAL_NOTEBOOK_SECRET") && !context.context.contains("历史金额11.25"),"local-only derived history cannot enter remote preparation")
                let denied=try await store.readConversationTurn(id:c.id,scope:.init(domains:permissions.allowedDomains,allowedKinds:[.voice],destination:.allowedRemote))
                try check(denied == nil,"remote history tools reject transitive local-only context")
                remote.cancel()
            }
            try conversations.redactDisallowed([.voice],notebookPermissions:.init())
            for id in [a.id,b.id,c.id] { try check(try conversations.runtimeTurn(id:id)?.completionState == .redacted,"A→B→C notebook revoke must remove every derived answer") }
        }
    }
    @MainActor static func runtimeCompaction() async throws {
        for mode in ["valid","malformed","timeout","combinedDeadline"] {
            let valid = mode == "valid"
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("summary-runtime-" + UUID().uuidString)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            defer { try? FileManager.default.removeItem(at:directory) }
            let db=try DaybookDatabase(url:directory.appendingPathComponent("db.sqlite"))
            let conversations=DaybookConversationStore(url:directory.appendingPathComponent("legacy.json"),database:db)
            let store=AskAIRuntimeStore(conversationStore:conversations)
            let original=try DaybookRetrieval().prepare(question:"之前回答的第一条是什么",records:[],selectedDate:.now,allowedKinds:[.voice])
            var previousIDs:[UUID]=[]
            for index in 0..<8 {
                let id=UUID();previousIDs.append(id)
                try conversations.saveTurn(.init(id:id,question:"历史问题 \(index)",text:"1. 原始要点。" + String(repeating:"历史背景内容。",count:90),generated:true,provider:"fixture",evidence:original.evidence,sources:[],scopeDescription:"",state:.completed,createdAt:Date(timeIntervalSinceReferenceDate:Double(index))),day:original.dayStart)
            }
            let id=UUID();try conversations.saveTurn(.init(id:id,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
            let json:[String:Any]=["topics":[["text":"用户讨论历史问题","turnIDs":[previousIDs[0].uuidString]]],"explicitDecisions":[],"corrections":[],"unresolved":[],"aiProposals":[],"entityRefs":[]]
            let text=valid ? String(decoding:try JSONSerialization.data(withJSONObject:json),as:UTF8.self) : "malformed summary"
            let summary=ScriptDriver([.success(.init(text:text,calls:[]))])
            let driver=ScriptDriver([.success(.init(text:"保留历史问答作为背景。",calls:[]))])
            let runtime=AskAIRuntime(prepared:original,records:[],configuration:AIConfiguration(),configurationRevision:1,turnID:id,store:store,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
            runtime.testDriver=driver;runtime.testSummaryDriver=summary
            if mode == "timeout" { summary.wait = true;runtime.summaryTimeout = 0.02 }
            if mode == "combinedDeadline" {
                summary.delayNanoseconds=80_000_000;driver.delayNanoseconds=80_000_000;runtime.activeDeadline=0.12
                _=try await runtime.prepare()
                do { _=try await runtime.generate(apiKey:nil,fallback:NoFallback());throw Failed(message:"summary and answering must share one active deadline") } catch AskAIRuntime.Failure.deadline {}
                continue
            }
            _=try await runtime.prepare();_=try await runtime.generate(apiKey:nil,fallback:NoFallback())
            try check(summary.starts == 1 && (mode == "timeout" || summary.replies.isEmpty),"one optional summary call under history pressure")
            let requests=try db.query("SELECT provider_requests FROM ask_ai_runs WHERE turn_id=?",[.text(id.uuidString)]).first?["provider_requests"]?.double
            try check(requests == 2,"summary uses the original shared provider request budget")
            try check(driver.sent[0].contains(valid ? "HISTORICAL SUMMARY" : "HISTORICAL ANSWER OMITTED"),"valid summary integrated, malformed summary preserves exact previous-turn recovery")
            try check(runtime.loadedToolDefinitions.contains { $0["name"] as? String == "readConversationTurn" },"failed summary retains original history read capability")
            try check(!summary.sent[0].contains(previousIDs.last!.uuidString),"summary excludes latest complete round")
        }
    }
    @MainActor static func notebookRuntime() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notebook-runtime-" + UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let url = directory.appendingPathComponent("fixture.sqlite"), db = try DaybookDatabase(url:url)
        try db.execute("CREATE TABLE flash_assets(id TEXT PRIMARY KEY,source_id TEXT,kind TEXT,captured_at REAL,revision INTEGER,revoked INTEGER,ready INTEGER,currency TEXT,direction TEXT,amount_minor INTEGER,payload BLOB)")
        for i in 0..<9 {
            let payload: [String:Any] = ["title":"Lunch","text":"saved lunch","date":"2026-11-02","category":"food"]
            try db.execute("INSERT INTO flash_assets VALUES(?,?,'expense',0,1,0,1,'CNY','expense',125,?)",[.text("entry-\(i)"),.text("gone-audio"),.blob(try JSONSerialization.data(withJSONObject:payload))])
        }
        let conversations = DaybookConversationStore(url:directory.appendingPathComponent("history.json"),database:db)
        let store = AskAIRuntimeStore(conversationStore:conversations)
        let permissions = AgentNotebookPermissions(allowLedger:true)
        let scope = AgentQueryScope(domains:permissions.allowedDomains,allowedKinds:[.voice],destination:.localOnly)
        let reader = AskAINotebookReader(databaseURL:url,permissions:permissions,scope:scope)
        let original = try DaybookRetrieval().prepare(question:"记账花费",records:[],selectedDate:.now,allowedKinds:[.voice])
        let id = UUID()
        try conversations.saveTurn(.init(id:id,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
        let calls = [AskAIToolCall(id:"exact-ledger",name:"aggregateLedger",arguments:Data(#"{"start":"2026-11-01","end":"2026-12-01"}"#.utf8))]
        let driver = ScriptDriver([.success(.init(text:"",calls:calls)),.success(.init(text:"合计 CNY 11.25，共9条 [1]",calls:[]))])
        var current = true
        let runtime = AskAIRuntime(prepared:original,records:[],configuration:AIConfiguration(),configurationRevision:1,turnID:id,store:store,notebookPermissions:permissions,notebookReader:reader,queryScope:scope,isCurrent:{current},onStage:{_ in},authorizeAdditional:{_ in})
        runtime.testDriver = driver
        let prepared = try await runtime.prepare()
        try check(prepared.directResponse == nil,"empty timeline does not stop notebook-only runtime")
        let names = Set(runtime.loadedToolDefinitions.compactMap { $0["name"] as? String })
        try check(names.contains("aggregateLedger") && !names.contains("aggregateMetrics") && !names.contains("searchRecords"),"4K loads relevant exact ledger schemas and unloads timeline")
        let result = try await runtime.generate(apiKey:nil,fallback:NoFallback())
        try check(driver.results.first?.contains("1125") == true && result.sources.isEmpty && result.evidenceRefs.count == 1,"real SQL total passes through actual4K runtime loop and typed citation")
        let final = DaybookConversationTurn(id:id,question:original.question,text:result.text,generated:true,provider:"fixture",evidence:result.prepared.evidence,sources:result.sources,scopeDescription:"",state:.completed,evidenceRefs:result.evidenceRefs,notebookPermissions:permissions,runProvenance:result.runProvenance)
        try await runtime.publish(final)
        let reopened = DaybookConversationStore(url:directory.appendingPathComponent("history.json"),database:try DaybookDatabase(url:url))
        try check(try reopened.runtimeTurn(id:id)?.evidenceRefs == result.evidenceRefs,"typed notebook citation survives reopen")
        for window: Int? in [4096,16384,32768,nil] {
            var config=AIConfiguration();config.mode = .custom;config.contextWindowTokens=window
            let budgetID=UUID();try conversations.saveTurn(.init(id:budgetID,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
            let script=ScriptDriver([.success(.init(text:"",calls:[.init(id:"window-ledger",name:"aggregateLedger",arguments:calls[0].arguments)])),.success(.init(text:"精确合计 [1]",calls:[]))])
            let engine=AskAIRuntime(prepared:original,records:[],configuration:config,configurationRevision:1,turnID:budgetID,store:store,notebookPermissions:permissions,notebookReader:reader,queryScope:scope,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
            engine.testDriver=script;let context=try await engine.prepare()
            let schemas=String(decoding:try JSONSerialization.data(withJSONObject:engine.loadedToolDefinitions,options:.sortedKeys),as:UTF8.self)
            try check(AskAIRuntime.policy(configuration:config).initial.fits(instruction:engine.instruction,content:CustomAISummarizer.answerContent(question:context.providerQuestion,context:context.context),tools:schemas),"actual configured-window initial context fits")
            let answer=try await engine.generate(apiKey:nil,fallback:NoFallback())
            try check(answer.evidenceRefs.first?.domain == .ledger && script.results.first?.contains("1125") == true,"actual4/16/32K and unknown-window notebook loop")
            await engine.fail(CancellationError())
        }
        for mutate in [true,false] {
            let raceID = UUID()
            try conversations.saveTurn(.init(id:raceID,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
            let script=ScriptDriver([.success(.init(text:"",calls:[.init(id:"race-ledger",name:"aggregateLedger",arguments:calls[0].arguments)])),.success(.init(text:"精确账目合计 [1]",calls:[]))])
            let engine=AskAIRuntime(prepared:original,records:[],configuration:AIConfiguration(),configurationRevision:1,turnID:raceID,store:store,notebookPermissions:permissions,notebookReader:reader,queryScope:scope,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
            engine.testDriver=script;_=try await engine.prepare();let result=try await engine.generate(apiKey:nil,fallback:NoFallback())
            let turn=DaybookConversationTurn(id:raceID,question:original.question,text:result.text,generated:true,provider:"fixture",evidence:result.prepared.evidence,sources:[],scopeDescription:"",state:.completed,evidenceRefs:result.evidenceRefs,notebookPermissions:permissions,runProvenance:result.runProvenance)
            if mutate {
                let gate=PublicationGate();engine.beforePublicationLease={gate.pauseOnce()}
                let publication=Task { try await engine.publish(turn) }
                while !gate.didEnter { await Task.yield() }
                try db.execute("UPDATE flash_assets SET amount_minor=500,revision=2 WHERE id='entry-0'")
                gate.release()
                do { try await publication.value;throw Failed(message:"notebook edit raced publication fence") } catch AskAIRuntimeStore.Failure.staleAttempt {}
                try check(try conversations.runtimeTurn(id:raceID)?.completionState == .pending,"same-transaction dependency fence prevents stale completed answer")
                await engine.fail(CancellationError())
            } else {
                try await engine.publish(turn)
                try check(try conversations.runtimeTurn(id:raceID)?.completionState == .completed,"fresh post-edit answer publishes")
            }
        }
        let settings = URLSessionConfiguration.ephemeral; settings.protocolClasses = [FixtureProtocol.self]
        let session = URLSession(configuration:settings);defer { session.invalidateAndCancel() }
        var custom = AIConfiguration();custom.mode = .custom;custom.model = "fixture";custom.baseURL = "https://fixture.invalid/v1"
        let fallbackID = UUID();try conversations.saveTurn(.init(id:fallbackID,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:original.dayStart)
        let remoteScope = AgentQueryScope(domains:permissions.allowedDomains,allowedKinds:[.voice],destination:.allowedRemote)
        let remoteReader = AskAINotebookReader(databaseURL:url,permissions:permissions,scope:remoteScope)
        let compatibility = AskAIRuntime(prepared:original,records:[],configuration:custom,configurationRevision:1,turnID:fallbackID,store:store,notebookPermissions:permissions,notebookReader:remoteReader,queryScope:remoteScope,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
        compatibility.customSession=session
        var remoteRequests=0
        FixtureProtocol.handler = { request in
            var bytes=request.httpBody
            if bytes == nil,let stream=request.httpBodyStream { stream.open();defer{stream.close()};var buffer=[UInt8](repeating:0,count:4096);var data=Data();while stream.hasBytesAvailable {let n=stream.read(&buffer,maxLength:buffer.count);if n<=0{break};data.append(buffer,count:n)};bytes=data }
            remoteRequests += 1
            if remoteRequests == 1 { return (400,[:]) }
            let body=try JSONSerialization.jsonObject(with:bytes!) as! [String:Any]
            try check(body["tools"] == nil && String(decoding:bytes!,as:UTF8.self).contains("1500"),"no-tools fallback performs deterministic exact notebook lookup first")
            return (200,["choices":[["finish_reason":"stop","message":["content":"CNY11.25 [1]"]]]])
        }
        _=try await compatibility.prepare()
        let compatibleAnswer=try await compatibility.generate(apiKey:"synthetic",fallback:DaybookAnswerService(customSummarizer:CustomAISummarizer(session:session)))
        try check(remoteRequests == 2 && compatibleAnswer.evidenceRefs.first?.domain == .ledger,"no-tools notebook fallback keeps typed refs and bounded provider requests")
        current = false
        do { try await runtime.publish(final); throw Failed(message:"revoked pending publication") } catch is CancellationError {}
        try check(AskAIRuntime.policy(configuration:{var c=AIConfiguration();c.mode = .custom;c.contextWindowTokens=32768;return c}()).working.windowTokens == 32768,"runtime32K")
        try check(AskAIRuntime.policy(configuration:{var c=AIConfiguration();c.mode = .custom;return c}()).isEstimated,"runtime unknown model is estimated")
    }
    @MainActor static func configurableSchemas() async throws {
        let settings = URLSessionConfiguration.ephemeral; settings.protocolClasses = [FixtureProtocol.self]
        let session = URLSession(configuration:settings); defer { session.invalidateAndCancel() }
        for apiProtocol in AIConfiguration.APIProtocol.allCases {
            var config = AIConfiguration(); config.mode = .custom; config.model = "fixture"; config.baseURL = "https://fixture.invalid/v1"; config.apiProtocol = apiProtocol
            for includeTools in [false,true] {
                let schemas = includeTools ? Array(AskAIReadTools.toolDefinitions.prefix(1)) : []
                let driver = try AskAICustomDriver(configuration:config,apiKey:"synthetic",session:session,toolDefinitions:schemas,outputTokens:1024)
                FixtureProtocol.handler = { request in
                    var bytes = request.httpBody
                    if bytes == nil, let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating:0,count:4096); var data = Data(); while stream.hasBytesAvailable { let count = stream.read(&buffer,maxLength:buffer.count); if count <= 0 { break }; data.append(buffer,count:count) }; bytes = data }
                    let body = try JSONSerialization.jsonObject(with:bytes!) as! [String:Any]
                    try check(body["max_tokens"] as? Int == 1024,"configured output budget reaches provider")
                    if includeTools { try check((body["tools"] as? [[String:Any]])?.count == 1,"only loaded schema sent") }
                    else { try check(body["tools"] == nil,"compaction sends no tools field") }
                    return (200,apiProtocol == .openai ? ["choices":[["finish_reason":"stop","message":["content":"fixture"]]]] : ["content":[["type":"text","text":"fixture"]],"stop_reason":"end_turn"])
                }
                try driver.start(instruction:"synthetic",content:"synthetic")
                _ = try await driver.next(correction:nil)
            }
        }
    }
    @MainActor static func unsupportedFallback(_ original:DaybookRetrieval.Prepared,records:[DayRecord],day:Date,store:AskAIRuntimeStore,conversations:DaybookConversationStore) async throws {
        let settings = URLSessionConfiguration.ephemeral; settings.protocolClasses = [FixtureProtocol.self]
        let session = URLSession(configuration:settings); defer { session.invalidateAndCancel() }
        for apiProtocol in AIConfiguration.APIProtocol.allCases {
            let configuration: AIConfiguration = { var value = AIConfiguration(); value.mode = .custom; value.model = "fixture"; value.baseURL = "https://fixture.invalid/v1"; value.apiProtocol = apiProtocol; return value }()
            let id = UUID(); try conversations.saveTurn(.init(id:id,question:original.question,text:"",generated:false,provider:"",evidence:original.evidence,sources:[],scopeDescription:"",state:.pending),day:day)
            let engine = AskAIRuntime(prepared:original,records:records,configuration:configuration,configurationRevision:1,turnID:id,store:store,isCurrent:{true},onStage:{_ in},authorizeAdditional:{_ in})
            engine.customSession = session
            var requests = 0
            FixtureProtocol.handler = { request in
                var bytes = request.httpBody
                if bytes == nil, let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating:0,count:4096); var data = Data(); while stream.hasBytesAvailable { let count = stream.read(&buffer,maxLength:buffer.count); if count <= 0 { break }; data.append(buffer,count:count) }; bytes = data }
                let body = try JSONSerialization.jsonObject(with:bytes!) as! [String:Any]; requests += 1
                if requests == 1 { try check(body["tools"] != nil && !String(decoding:bytes!,as:UTF8.self).contains("project evidence"),"unsupported probe remains synthetic"); return (400,[:]) }
                try check(body["tools"] == nil && body["max_tokens"] as? Int == 512,"reviewed text fallback and citation repair both request512 output tokens")
                let text = requests == 2 ? "uncited fixture" : "cited fixture [1]"
                if apiProtocol == .openai { return (200,["choices":[["finish_reason":"stop","message":["content":text]]]]) }
                return (200,["type":"message","role":"assistant","content":[["type":"text","text":text]],"stop_reason":"end_turn"])
            }
            _ = try await engine.prepare()
            let answer = try await engine.generate(apiKey:"synthetic-key",fallback:DaybookAnswerService(customSummarizer:CustomAISummarizer(session:session)))
            try check(answer.text == "cited fixture [1]" && requests == 3,"actual runtime unsupported probe reaches capped initial+repair compatibility path")
            // Unrelated legacy callers preserve existing output defaults.
            FixtureProtocol.handler = { request in
                var bytes = request.httpBody
                if bytes == nil, let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating:0,count:4096); var data = Data(); while stream.hasBytesAvailable { let count = stream.read(&buffer,maxLength:buffer.count); if count <= 0 { break }; data.append(buffer,count:count) }; bytes = data }
                let body = try JSONSerialization.jsonObject(with:bytes!) as! [String:Any]
                try check(apiProtocol == .openai ? body["max_tokens"] == nil : body["max_tokens"] as? Int == 2048,"legacy output-token defaults retained")
                if apiProtocol == .openai { return (200,["choices":[["finish_reason":"stop","message":["content":"legacy"]]]]) }
                return (200,["type":"message","role":"assistant","content":[["type":"text","text":"legacy"]],"stop_reason":"end_turn"])
            }
            _ = try await CustomAISummarizer(session:session).answer(question:"Fixture",context:"Synthetic",configuration:configuration,apiKey:"synthetic-key")
        }
    }
    @MainActor static func fallbackFreshness(_ prepared:DaybookRetrieval.Prepared) async throws {
        let suite = "ask-ai-fallback-freshness-" + UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!; defer { defaults.removePersistentDomain(forName:suite) }
        for expired in [true,false] {
            let credential = ChatGPTCredential(clientID:"fixture-client",subject:"fixture",email:nil,hostID:"urn:uuid:fixture",idToken:"fixture",accessToken:"fixture",refreshToken:"fixture",expiresAt:.now.addingTimeInterval(expired ? -60 : 3600),scopes:["chatgpt.tokens.use.direct","resource.invoke"])
            let vault = ChatGPTAccountVault(hostID:credential.hostID,registrations:[.init(clientID:credential.clientID,subject:credential.subject,email:nil,credential:credential,acknowledgedPlan:true)],selectedID:credential.clientID)
            let api = RuntimeAccountAPI()
            let account = ChatGPTAccountModel(storage:RuntimeAccountStore(vault),api:api,defaults:defaults,isEnabled:true)
            let configuration: AIConfiguration = { var value = AIConfiguration(); value.mode = .chatgpt; value.chatGPTModel = "fixture-model"; value.chatGPTAccountID = "fixture-client"; return value }()
            var sourceRevision = 1; var validations = 0
            let service = DaybookAnswerService(chatGPT:account)
            let pending = Task { try await service.answerReviewed(prepared,configuration:configuration,apiKey:nil,instruction:"Fixture",isCurrent:{true},ensureFresh:{ validations += 1; await Task.yield(); guard sourceRevision == 1 else { throw CancellationError() } }) }
            while true {
                let counts = await api.counts()
                if expired ? counts.0 > 0 : counts.1 > 0 { break }; await Task.yield()
            }
            sourceRevision = 2
            do { _ = try await pending.value; throw Failed(message:"reviewed fallback sent stale source after account await") } catch is CancellationError {}
            let counts = await api.counts()
            try check(counts.2 == 0 && validations >= 2,"reviewed fallback forwards async source check through credential/catalog suspension")
        }
        // The Mac transport already invokes authorized after discovery and model load;
        // gate the service integration so future refactors cannot silently drop that hook.
        let source = try String(contentsOfFile:"Sources/iPhone/DaybookAnswerService.swift",encoding:.utf8)
        try check(source.contains("authorized:{ try await ensureFresh(); return isCurrent() }"),"Nearby Mac reviewed-answer async authorization forwarding")
    }
    @MainActor static func protocols() async throws {
        let settings = URLSessionConfiguration.ephemeral; settings.protocolClasses = [FixtureProtocol.self]
        let session = URLSession(configuration:settings); defer { session.invalidateAndCancel() }
        for protocolKind in AIConfiguration.APIProtocol.allCases {
            var configuration = AIConfiguration(); configuration.mode = .custom; configuration.model = "synthetic"; configuration.baseURL = "https://fixture.invalid/v1"; configuration.apiProtocol = protocolKind
            let driver = try AskAICustomDriver(configuration:configuration,apiKey:"synthetic-key",session:session)
            var step = 0
            FixtureProtocol.handler = { request in
                var bytes = request.httpBody
                if bytes == nil, let stream = request.httpBodyStream { stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating:0,count:4096); var data = Data(); while stream.hasBytesAvailable { let count = stream.read(&buffer,maxLength:buffer.count); if count <= 0 { break }; data.append(buffer,count:count) }; bytes = data }
                let body = try JSONSerialization.jsonObject(with:bytes!) as! [String:Any]
                let serialized = String(decoding:bytes!,as:UTF8.self)
                step += 1
                if step == 1 { try check(!serialized.contains("SECRET"),"private probe data") }
                else if step == 3 { try check(serialized.contains("call_fixture") && serialized.contains("status=ok"),"call/result pairing sent") }
                if protocolKind == .openai {
                    if step == 3 { return (200,["choices":[["finish_reason":"stop","message":["role":"assistant","content":"done [1]"]]]]) }
                    let name = step == 1 ? "capability_probe" : "searchRecords"
                    let arguments = step == 1 ? #"{"value":"ok"}"# : #"{"query":"project"}"#
                    return (200,["choices":[["finish_reason":"tool_calls","message":["role":"assistant","tool_calls":[["id":"call_fixture","type":"function","function":["name":name,"arguments":arguments]]]]]]])
                }
                _ = body
                if step == 3 { return (200,["content":[["type":"text","text":"done [1]"]],"stop_reason":"end_turn"]) }
                return (200,["content":[["type":"tool_use","id":"call_fixture","name":step == 1 ? "capability_probe" : "searchRecords","input":step == 1 ? ["value":"ok"] : ["query":"project"]]],"stop_reason":"tool_use"])
            }
            let supported = try await driver.probe(); try check(supported,"capability probe")
            try driver.start(instruction:"synthetic",content:"SECRET initial approved synthetic text")
            let first = try await driver.next(correction:nil); try check(first.calls.count == 1,"protocol call decode")
            do { _ = try await driver.next(correction:nil); throw Failed(message:"unpaired call request") } catch AIServiceError.invalidResponse {}
            try driver.receive(call:first.calls[0],result:"status=ok")
            let second = try await driver.next(correction:nil); try check(second.text == "done [1]","protocol text decode")
            FixtureProtocol.handler = { _ in (200,protocolKind == .openai ? ["choices":[["message":["content":"no tools"]]]] : ["content":[["type":"text","text":"no tools"]]]) }
            let unsupported = try await driver.probe(); try check(!unsupported,"absent capability fallback")
            FixtureProtocol.handler = { _ in (401,[:]) }
            do { _ = try await driver.probe(); throw Failed(message:"auth downgraded to unsupported") } catch AIServiceError.authentication {}
        }
    }
}

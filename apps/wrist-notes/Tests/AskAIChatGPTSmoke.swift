import Foundation

private final class DriverStore: ChatGPTAccountStoring {
    var vault: ChatGPTAccountVault
    init() {
        let credential = ChatGPTCredential(clientID:"fixture-client",subject:"fixture",email:nil,hostID:"urn:uuid:fixture",idToken:"fixture",accessToken:"fixture",refreshToken:"fixture",expiresAt:.now.addingTimeInterval(3600),scopes:["chatgpt.tokens.use.direct","resource.invoke"])
        vault = .init(hostID:credential.hostID,registrations:[.init(clientID:credential.clientID,subject:credential.subject,email:nil,credential:credential,acknowledgedPlan:true)],selectedID:credential.clientID)
    }
    func load() throws -> ChatGPTAccountVault? { vault }
    func save(_ value:ChatGPTAccountVault) throws { vault = value }
}
private final class DriverProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (String,Data))!
    override class func canInit(with request:URLRequest) -> Bool { true }
    override class func canonicalRequest(for request:URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (type,data) = try Self.handler(request)
            client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:["Content-Type":type])!,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() {}
}
@MainActor private struct NeverFallback: DaybookAnswering {
    func answer(_ prepared:DaybookRetrieval.Prepared,configuration:AIConfiguration,apiKey:String?) async throws -> String { throw Failure.failed("ChatGPT runtime fell back to text") }
}
private enum Failure: Error { case failed(String) }
private func check(_ condition:@autoclosure () -> Bool,_ message:String) throws { if !condition() { throw Failure.failed(message) } }
private func data(_ object:Any) -> Data { try! JSONSerialization.data(withJSONObject:object,options:.sortedKeys) }
private func body(_ request:URLRequest) -> [String:Any] {
    var bytes = request.httpBody
    if bytes == nil, let stream = request.httpBodyStream {
        stream.open();defer { stream.close() };var buffer=[UInt8](repeating:0,count:4096);var result=Data()
        while stream.hasBytesAvailable { let n=stream.read(&buffer,maxLength:buffer.count);if n<=0 { break };result.append(buffer,count:n) };bytes=result
    }
    return try! JSONSerialization.jsonObject(with:bytes!) as! [String:Any]
}
private func terminal(_ output:[[String:Any]]) -> Data { Data(("data: " + String(decoding:data(["type":"response.completed","response":["status":"completed","output":output]]),as:UTF8.self) + "\n\n").utf8) }
private func text(_ value:String) -> [String:Any] { ["type":"message","role":"assistant","content":[["type":"output_text","text":value]]] }
private func call(_ id:String="call-1") -> [String:Any] { ["type":"function_call","namespace":"eurekalife","name":"searchRecords","call_id":id,"arguments":"{\"query\":\"project\"}"] }
@main struct AskAIChatGPTSmoke {
    @MainActor static func main() async throws {
        let settings = URLSessionConfiguration.ephemeral;settings.protocolClasses=[DriverProtocol.self]
        let session=URLSession(configuration:settings);defer { session.invalidateAndCancel() }
        let suite="chatgpt-driver-"+UUID().uuidString
        let defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let account=ChatGPTAccountModel(storage:DriverStore(),api:ChatGPTAPI(session:session),defaults:defaults,isEnabled:true)
        var configuration=AIConfiguration();configuration.mode = .chatgpt;configuration.chatGPTAccountID="fixture-client";configuration.chatGPTModel="fixture-model"
        let definitions=AskAIReadTools.toolDefinitions.filter { $0["name"] as? String == "searchRecords" }
        var step=0
        DriverProtocol.handler = { request in
            if request.url!.path == "/v1/models" { return ("application/json",data(["models":[["slug":"fixture-model","display_name":"Fixture","visibility":"list"]]])) }
            let json=body(request),input=json["input"] as! [[String:Any]];step += 1
            if step==1 { return ("text/event-stream",terminal([["type":"reasoning","id":"rs_1","summary":[],"encrypted_content":"opaque-fixture"],call()])) }
            try check(input[0]["content"] as? String == "Complete question and approved history","full initial history retained")
            try check(input[1]["type"] as? String == "reasoning" && input[1]["encrypted_content"] as? String == "opaque-fixture","reasoning continuation retained")
            try check(input[2]["call_id"] as? String == "call-1" && input[3]["call_id"] as? String == "call-1" && input[3]["output"] as? String == "Approved local result","call_id result correlation")
            return ("text/event-stream",terminal([text("Verified [1]")]))
        }
        let driver=try AskAIChatGPTDriver(configuration:configuration,account:account,toolDefinitions:definitions)
        try driver.start(instruction:"Read only",content:"Complete question and approved history")
        let first=try await driver.next(correction:nil)
        try check(first.calls.count==1,"completed tool decoded")
        do { _=try await driver.next(correction:nil);throw Failure.failed("pending tool allowed continuation") } catch ChatGPTError.invalidResponse {}
        do { try driver.receive(call:.init(id:"call-1",name:"deleteRecord",arguments:Data("{}".utf8)),result:"bad");throw Failure.failed("substituted tool accepted") } catch ChatGPTError.invalidResponse {}
        try driver.receive(call:first.calls[0],result:"Approved local result")
        do { try driver.receive(call:first.calls[0],result:"duplicate");throw Failure.failed("duplicate result accepted") } catch ChatGPTError.invalidResponse {}
        let final=try await driver.next(correction:nil);try check(final.text=="Verified [1]","tool continuation answer")
        // Repeated IDs across distinct completed responses must not execute twice.
        DriverProtocol.handler = { _ in ("text/event-stream",terminal([call()])) }
        do { _=try await driver.next(correction:nil);throw Failure.failed("repeated ID accepted") } catch ChatGPTError.invalidResponse {}
        var requests=0
        DriverProtocol.handler = { request in
            if request.url!.path == "/v1/models" { return ("application/json",data(["models":[["slug":"fixture-model","display_name":"Fixture","visibility":"list"]]])) }
            requests += 1;return ("text/event-stream",terminal([text("forbidden")]))
        }
        await account.selectAccount("fixture-client")
        do { _=try await driver.next(correction:nil);throw Failure.failed("account generation allowed continuation") } catch is CancellationError {}
        try check(requests==0,"no request after account generation changes")

        let oversized=try AskAIChatGPTDriver(configuration:configuration,account:account,toolDefinitions:[])
        try oversized.start(instruction:"bounded",content:String(repeating:"中",count:5000))
        do { _=try await oversized.next(correction:nil);throw Failure.failed("model input budget bypassed below transport byte cap") } catch AskAIRuntime.Failure.contextOverflow {}
        try check(requests==0,"model budget overflow rejected before inference")
        // Exercise the production runtime provider branch and consent/evidence finalization.
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("ask-ai-chatgpt-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:directory) }
        let day=Date(timeIntervalSince1970:1_790_000_000)
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let records=[DayRecord(id:UUID(),capturedAt:day,kind:.voice,title:"Project",text:"project evidence")]
        var retrieval=DaybookRetrieval();retrieval.calendar=calendar
        let prepared=try retrieval.prepare(question:"project",records:records,selectedDate:day,allowedKinds:[.voice])
        let database=try DaybookDatabase(url:directory.appendingPathComponent("fixture.sqlite"))
        let conversations=DaybookConversationStore(url:directory.appendingPathComponent("history.json"),database:database)
        let store=AskAIRuntimeStore(conversationStore:conversations),id=UUID()
        try conversations.saveTurn(.init(id:id,question:"project",text:"",generated:false,provider:"",evidence:prepared.evidence,sources:[],scopeDescription:"",state:.pending),day:day)
        var previews:[String]=[],runtimeSteps=0
        let runtime=AskAIRuntime(prepared:prepared,records:records,configuration:configuration,configurationRevision:1,turnID:id,store:store,chatGPTAccount:account,isCurrent:{true},onStage:{_ in},authorizeAdditional:{previews.append($0)})
        DriverProtocol.handler = { request in
            if request.url!.path == "/v1/models" { return ("application/json",data(["models":[["slug":"fixture-model","display_name":"Fixture","visibility":"list"]]])) }
            runtimeSteps += 1
            if runtimeSteps==1 { return ("text/event-stream",terminal([call("runtime-call")])) }
            let input=body(request)["input"] as! [[String:Any]]
            let result=input.last!["output"] as! String
            try check(previews.contains(result),"exact tool output consent before continuation")
            return ("text/event-stream",terminal([text("Project verified [1]")]))
        }
        _=try await runtime.prepare();let answer=try await runtime.generate(apiKey:nil,fallback:NeverFallback())
        try check(answer.text=="Project verified [1]" && answer.sources.count==1 && runtimeSteps==2,"native ChatGPT runtime uses read tools and evidence")
        // History pressure uses the selected ChatGPT model for optional compaction, without tools.
        let historical = try retrieval.prepare(question:"之前回答的第一条是什么",records:[],selectedDate:day,allowedKinds:[.voice])
        var previousIDs:[UUID]=[]
        for index in 0..<8 {
            let previousID=UUID();previousIDs.append(previousID)
            let provenance=AgentRunProvenance(domains:[.conversation],sourceKinds:[.voice])
            try conversations.saveTurn(.init(id:previousID,question:"历史问题 \(index)",text:"1. 原始要点。"+String(repeating:"历史背景内容。",count:90),generated:true,provider:"fixture",evidence:historical.evidence,sources:[],scopeDescription:"",state:.completed,createdAt:Date(timeIntervalSinceReferenceDate:Double(index)),runProvenance:provenance),day:historical.dayStart)
        }
        let summaryID=UUID()
        try conversations.saveTurn(.init(id:summaryID,question:historical.question,text:"",generated:false,provider:"",evidence:historical.evidence,sources:[],scopeDescription:"",state:.pending),day:historical.dayStart)
        var summaryConsents:[String]=[],summarySteps=0
        DriverProtocol.handler = { request in
            let json=body(request),serialized=String(decoding:data(json),as:UTF8.self)
            summarySteps += 1
            try check(json["model"] as? String == "fixture-model","selected ChatGPT model used for summary and answer")
            if summarySteps==1 {
                try check(json["tools"] == nil && serialized.contains(previousIDs[0].uuidString) && !serialized.contains(previousIDs.last!.uuidString),"summary uses originals, excludes latest round and has no tools")
                let summary:[String:Any]=["topics":[["text":"用户讨论历史问题","turnIDs":[previousIDs[0].uuidString]]],"explicitDecisions":[],"corrections":[],"unresolved":[],"aiProposals":[],"entityRefs":[]]
                try check(summaryConsents.contains { $0.contains(previousIDs[0].uuidString) },"summary history disclosed only after consent")
                return ("text/event-stream",terminal([text(String(decoding:data(summary),as:UTF8.self))]))
            }
            try check(serialized.contains("HISTORICAL SUMMARY"),"validated ChatGPT summary included in answer input")
            return ("text/event-stream",terminal([text("保留历史问答作为背景。")]))
        }
        let compaction=AskAIRuntime(prepared:historical,records:[],configuration:configuration,configurationRevision:1,turnID:summaryID,store:store,chatGPTAccount:account,isCurrent:{true},onStage:{_ in},authorizeAdditional:{summaryConsents.append($0)})
        _=try await compaction.prepare();_=try await compaction.generate(apiKey:nil,fallback:NeverFallback())
        try check(summarySteps==2,"ChatGPT performs optional compaction then answering")
        let runModel=try database.query("SELECT model FROM ask_ai_runs WHERE turn_id=?",[.text(summaryID.uuidString)]).first?["model"]?.string
        try check(runModel=="fixture-model","run records actual selected ChatGPT model")
        print("Ask AI ChatGPT driver: passed (namespaced terminal tools, full stateless continuation, account generation, runtime consent/provenance)")
    }
}

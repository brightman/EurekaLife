import Foundation

/// One consent-scoped Responses conversation. Credentials remain owned by the account model.
@MainActor final class AskAIChatGPTDriver: AskAIDriving {
    private let account: ChatGPTAccountModel
    private let accountID: String
    private let model: String
    private let accountRevision: Int
    private let definitions: [ChatGPTResponseTool]
    private let budget: AskAIContextBudget
    private let check: @MainActor () async throws -> Void
    private var instruction = ""
    private var initial: [ChatGPTResponseInput] = []
    private var input: [ChatGPTResponseInput] = []
    private var pending: [String:AskAIToolCall] = [:]
    private var seen = Set<String>()
    private var requests = 0
    private var inFlight = false

    init(configuration: AIConfiguration, account: ChatGPTAccountModel? = nil,
         toolDefinitions: [[String:Any]], budget: AskAIContextBudget = AskAIContextBudget.policy(window:nil,isCustom:false).working,
         check: @escaping @MainActor () async throws -> Void = {}) throws {
        guard configuration.mode == .chatgpt, !configuration.chatGPTAccountID.isEmpty,
              !configuration.chatGPTModel.isEmpty else { throw ChatGPTError.unavailableConfiguration }
        let account = account ?? .shared
        self.account = account; accountID = configuration.chatGPTAccountID; model = configuration.chatGPTModel
        accountRevision = account.revision; self.check = check; self.budget = budget
        definitions = try toolDefinitions.map { definition in
            guard let name = definition["name"] as? String, let description = definition["description"] as? String,
                  let schema = definition["parameters"] as? [String:Any] else { throw ChatGPTError.invalidResponse }
            return .init(name:name,description:description,parameters:try JSONSerialization.data(withJSONObject:schema,options:.sortedKeys))
        }
    }
    func start(instruction: String, content: String) throws {
        guard !inFlight else { throw ChatGPTError.invalidResponse }
        self.instruction = instruction
        initial = [.message(role:.user,text:content)]; input = initial; pending = [:]
        // Request/call budgets and duplicate IDs span context rebuilds within this attempt.
    }
    func rebuild() throws {
        guard !inFlight else { throw ChatGPTError.invalidResponse }
        input = initial; pending = [:]
    }
    func next(correction: String?) async throws -> AskAIDriverReply {
        guard !initial.isEmpty, pending.isEmpty, !inFlight else { throw ChatGPTError.invalidResponse }
        guard requests < 8 else { throw AskAIRuntime.Failure.requestLimit }
        try await check(); try ensureAccount()
        var candidate = input
        if let correction { candidate.append(.message(role:.user,text:correction)) }
        let request = ChatGPTResponsesRequest(model:model,instruction:instruction,input:candidate,tools:definitions)
        // SIWC has no max_output_tokens/max_tool_calls. Enforce transport, time and call budgets locally.
        let encoded = try request.encodedBody()
        guard encoded.count <= 96 * 1024,
              budget.fits(instruction:"",content:String(decoding:encoded,as:UTF8.self)) else { throw AskAIRuntime.Failure.contextOverflow }
        requests += 1; inFlight = true; defer { inFlight = false }
        let result: ChatGPTResponsesResult
        do {
            result = try await account.respond(request,accountID:accountID,isCurrent:{ [weak self] in
                guard let self else { return false };return self.account.revision == self.accountRevision
            },sourceIsCurrent:{ [weak self] in
                guard let self else { throw CancellationError() }
                try await self.check(); try self.ensureAccount();return true
            })
        } catch ChatGPTError.cancelled { throw CancellationError() }
        try await check(); try ensureAccount()
        guard result.text.count <= 8000, seen.count + result.calls.count <= 6,
              result.calls.allSatisfy({ !seen.contains($0.id) }) else { throw ChatGPTError.invalidResponse }
        let calls = result.calls.map { AskAIToolCall(id:$0.id,name:$0.name,arguments:$0.arguments) }
        input = candidate + result.output.map(ChatGPTResponseInput.output)
        for call in calls { seen.insert(call.id);pending[call.id] = call }
        return .init(text:result.text,calls:calls)
    }
    func receive(call: AskAIToolCall, result: String) throws {
        try ensureAccount()
        guard let expected = pending[call.id], expected.name == call.name, expected.arguments == call.arguments,
              result.utf8.count <= 262_144 else { throw ChatGPTError.invalidResponse }
        pending[call.id] = nil
        input.append(.functionOutput(callID:call.id,text:result))
    }
    private func ensureAccount() throws {
        try Task.checkCancellation()
        guard account.revision == accountRevision, account.selectedID == accountID else { throw CancellationError() }
    }
}

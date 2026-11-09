import Foundation
import CryptoKit
import Security

struct ChatGPTModel: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
}

struct ChatGPTCredential: Codable, Equatable {
    let clientID: String
    let subject: String
    let email: String?
    let hostID: String
    let idToken: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scopes: Set<String>

    var canUsePlan: Bool { scopes.contains("chatgpt.tokens.use.direct") && scopes.contains("resource.invoke") }
}

enum ChatGPTError: Error, Equatable, LocalizedError {
    case unavailableConfiguration, cancelled, invalidCallback, invalidIdentity, permissionMissing
    case expired, usageLimit, notEligible, temporarilyUnavailable, network, invalidResponse
    case incompleteResponse, storage
    case http(status: Int, code: String?, requestID: String?)

    var errorDescription: String? {
        switch self {
        case .unavailableConfiguration: return NSLocalizedString("此版本尚未启用 ChatGPT 套餐连接。", comment: "")
        case .cancelled: return NSLocalizedString("已取消 ChatGPT 登录。", comment: "")
        case .invalidCallback: return NSLocalizedString("无法验证 ChatGPT 登录回调，请重新登录。", comment: "")
        case .invalidIdentity: return NSLocalizedString("无法验证 ChatGPT 账号身份，请重新登录。", comment: "")
        case .permissionMissing: return NSLocalizedString("请检查 ChatGPT 账号与套餐使用权限。", comment: "")
        case .expired: return NSLocalizedString("ChatGPT 登录已失效，请重新登录。", comment: "")
        case .usageLimit: return NSLocalizedString("已达到 ChatGPT 应用用量上限，请前往 ChatGPT 设置中的用量页面查看。", comment: "")
        case .notEligible: return NSLocalizedString("此账号或工作区暂时无法使用 ChatGPT 套餐。", comment: "")
        case .temporarilyUnavailable: return NSLocalizedString("ChatGPT 暂时不可用，请稍后重试。", comment: "")
        case .network: return NSLocalizedString("无法连接 ChatGPT，请检查网络后重试。", comment: "")
        case .invalidResponse: return NSLocalizedString("ChatGPT 返回了无效响应，请重试。", comment: "")
        case .incompleteResponse: return NSLocalizedString("ChatGPT 未完成回答，请重试。", comment: "")
        case .storage: return NSLocalizedString("无法安全保存 ChatGPT 账号，请重试。", comment: "")
        case let .http(status, code, requestID):
            return String(format: NSLocalizedString("ChatGPT 请求失败（HTTP %lld）。", comment: ""), Int64(status)) + (code.map { " [\($0)]" } ?? "") + (requestID.map { " [\($0)]" } ?? "")
        }
    }
}

struct ChatGPTAuthorizationAttempt {
    let callbackURL: URL
    let clientID: String?
    let hostID: String
    let state: String
    let nonce: String
    let verifier: String
    let idTokenHint: String?
    let loginHint: String?
    let expectedSubject: String?

    init(callbackURL: URL, clientID: String?, hostID: String, idTokenHint: String? = nil,
         loginHint: String? = nil, expectedSubject: String? = nil) throws {
        guard Self.validCallbackBase(callbackURL), Self.validIdentifier(hostID),
              clientID.map({ Self.validIdentifier($0) && $0 != "dynamic_agent_client" }) ?? true,
              clientID != nil || (idTokenHint == nil && loginHint == nil && expectedSubject == nil)
        else { throw ChatGPTError.invalidCallback }
        self.callbackURL = callbackURL
        self.clientID = clientID
        self.hostID = hostID
        self.idTokenHint = idTokenHint
        self.loginHint = loginHint
        self.expectedSubject = expectedSubject
        state = try Self.secret()
        nonce = try Self.secret()
        verifier = try Self.secret()
    }

    static func validCallbackBase(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return c.scheme == "http" && c.host == "127.0.0.1" && c.port.map({ (1...65535).contains($0) }) == true &&
            c.percentEncodedPath == "/auth/callback" && c.user == nil && c.password == nil && c.query == nil && c.fragment == nil
    }
    static func validIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 512 && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0) })
    }
    private static func secret() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw ChatGPTError.invalidIdentity }
        return Data(bytes).chatGPTBase64URL
    }
}

extension Data {
    var chatGPTBase64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    init?(chatGPTBase64URL string: String) {
        guard !string.isEmpty, string.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }), string.utf8.count % 4 != 1 else { return nil }
        let padded = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + String(repeating: "=", count: (4 - string.utf8.count % 4) % 4)
        guard let decoded = Data(base64Encoded: padded), decoded.chatGPTBase64URL == string else { return nil }
        self = decoded
    }
}

// Responses transport types intentionally have no AskAI dependency.
struct ChatGPTResponseTool: Sendable {
    let name: String
    let description: String
    let parameters: Data
}
struct ChatGPTResponseCall: Sendable {
    let id: String
    let name: String
    let arguments: Data
}
struct ChatGPTResponseOutput: Sendable {
    let json: Data
}
enum ChatGPTResponseInput: Sendable {
    enum Role: String, Sendable { case user, assistant, developer }
    case message(role: Role, text: String)
    case output(ChatGPTResponseOutput)
    case functionOutput(callID: String, text: String)

    func object() throws -> [String:Any] {
        switch self {
        case let .message(role,text): return ["role":role.rawValue,"content":text]
        case let .output(item):
            guard let object = try JSONSerialization.jsonObject(with:item.json) as? [String:Any],
                  ["message","function_call","reasoning"].contains(object["type"] as? String ?? "") else { throw ChatGPTError.invalidResponse }
            return object
        case let .functionOutput(id,text):
            guard !id.isEmpty, id.utf8.count <= 128, text.utf8.count <= 262_144 else { throw ChatGPTError.invalidResponse }
            return ["type":"function_call_output","call_id":id,"output":text]
        }
    }
}
struct ChatGPTResponsesRequest: Sendable {
    static let toolNamespace = "eurekalife"
    let model: String
    let instruction: String
    let input: [ChatGPTResponseInput]
    let tools: [ChatGPTResponseTool]

    func encodedBody() throws -> Data {
        guard !model.isEmpty, model.utf8.count <= 512, !input.isEmpty, input.count <= 256,
              tools.count <= 32, Set(tools.map(\.name)).count == tools.count else { throw ChatGPTError.invalidResponse }
        let definitions: [[String:Any]] = try tools.map { tool in
            guard !tool.name.isEmpty, tool.name.utf8.count <= 80,
                  tool.name.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }),
                  tool.description.utf8.count <= 8192, tool.parameters.count <= 32_768,
                  let schema = try JSONSerialization.jsonObject(with:tool.parameters) as? [String:Any], schema["type"] as? String == "object" else { throw ChatGPTError.invalidResponse }
            // Existing schemas contain optional fields; explicitly retain non-strict validation.
            return ["type":"function","name":tool.name,"description":tool.description,"parameters":schema,"strict":false]
        }
        var body: [String:Any] = ["model":model,"instructions":instruction,"input":try input.map { try $0.object() },"store":false,"stream":true,"include":["reasoning.encrypted_content"]]
        if !definitions.isEmpty { body["tools"] = [["type":"namespace","name":Self.toolNamespace,"description":"Read only, consent-scoped EurekaLife data tools","tools":definitions]] }
        let data = try JSONSerialization.data(withJSONObject:body,options:.sortedKeys)
        guard data.count <= 1_048_576 else { throw ChatGPTError.invalidResponse }
        return data
    }
}
struct ChatGPTResponsesResult: Sendable {
    let text: String
    let calls: [ChatGPTResponseCall]
    /// Complete output, including opaque encrypted reasoning, for stateless continuations.
    let output: [ChatGPTResponseOutput]

    static func completed(_ response: [String:Any], tools: [ChatGPTResponseTool]) throws -> Self {
        guard response["status"] as? String == "completed", response["error"] == nil || response["error"] is NSNull,
              let items = response["output"] as? [[String:Any]], items.count <= 128 else { throw ChatGPTError.invalidResponse }
        var texts:[String] = [], calls:[ChatGPTResponseCall] = [], output:[ChatGPTResponseOutput] = []
        let names = Set(tools.map(\.name))
        for item in items {
            if let status = item["status"] as? String, status != "completed" { throw ChatGPTError.incompleteResponse }
            switch item["type"] as? String {
            case "message":
                guard item["role"] as? String == "assistant", let content = item["content"] as? [[String:Any]] else { throw ChatGPTError.invalidResponse }
                for piece in content {
                    guard piece["type"] as? String == "output_text", let text = piece["text"] as? String else { throw ChatGPTError.invalidResponse }
                    texts.append(text)
                }
            case "function_call":
                guard item["namespace"] as? String == ChatGPTResponsesRequest.toolNamespace,
                      let name = item["name"] as? String, names.contains(name),
                      let id = item["call_id"] as? String, !id.isEmpty, id.utf8.count <= 128,
                      !calls.contains(where: { $0.id == id }), calls.count < 6,
                      let arguments = item["arguments"] as? String, arguments.utf8.count <= 2048,
                      (try? JSONSerialization.jsonObject(with:Data(arguments.utf8))) is [String:Any] else { throw ChatGPTError.invalidResponse }
                calls.append(.init(id:id,name:name,arguments:Data(arguments.utf8)))
            case "reasoning": break // Opaque model state, never displayed or interpreted as evidence.
            default: throw ChatGPTError.invalidResponse
            }
            output.append(.init(json:try JSONSerialization.data(withJSONObject:item,options:.sortedKeys)))
        }
        let text = texts.joined(separator:"\n")
        guard text.utf8.count <= 262_144, !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !calls.isEmpty else { throw ChatGPTError.invalidResponse }
        return .init(text:text,calls:calls,output:output)
    }
}

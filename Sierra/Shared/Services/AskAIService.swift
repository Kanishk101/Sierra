import Foundation
import Supabase

// MARK: - AskAI Request / Response Models

struct AskAIRequest: Encodable {
    let prompt: String
}

struct AskAIResponse: Decodable {
    let answer: String
    let sql: String?
    // Raw result rows are flexible JSON - decode as array of string-keyed dictionaries
    let result: [[String: AskAIValue]]?
}

/// A simple JSON-value type for the flexible `result` array rows.
enum AskAIValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()           { self = .null }
        else if let v = try? c.decode(Bool.self)   { self = .bool(v) }
        else if let v = try? c.decode(Int.self)    { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else                                        { self = .null }
    }

    var displayString: String {
        switch self {
        case .string(let s): return s
        case .int(let i):    return "\(i)"
        case .double(let d): return "\(d)"
        case .bool(let b):   return b ? "true" : "false"
        case .null:          return ""
        }
    }
}

// MARK: - AskAIService

enum AskAIService {

    /// Sends a natural-language prompt to the `ask_ai` Supabase edge function.
    /// Strict authenticated invoke for `ask_ai`:
    /// - requires an active session
    /// - verifies session user matches the logged-in app user
    /// - refreshes token proactively and retries once on 401
    /// This keeps gateway `verify_jwt` protections intact and avoids broader
    /// session-recovery fallback paths for chatbot calls.
    static func ask(prompt: String) async throws -> AskAIResponse {
        let request = AskAIRequest(prompt: prompt)

        try await validateExpectedUserSession()
        _ = try? await supabase.auth.refreshSession()
        try await validateExpectedUserSession()
        do {
            let options = try await SupabaseManager.functionOptions(body: request)
            return try await supabase.functions.invoke("ask_ai", options: options)
        } catch {
            guard SupabaseManager.isUnauthorizedEdgeError(error) else { throw error }
            _ = try await supabase.auth.refreshSession()
            try await validateExpectedUserSession()
            let retryOptions = try await SupabaseManager.functionOptions(body: request)
            return try await supabase.functions.invoke("ask_ai", options: retryOptions)
        }
    }

    private static func validateExpectedUserSession() async throws {
        guard let expectedUserId = AuthManager.shared.currentUser?.id else {
            throw AuthError.sessionExpired
        }
        let session = try await supabase.auth.session
        guard session.user.id == expectedUserId else {
            throw AuthError.sessionExpired
        }
    }
}

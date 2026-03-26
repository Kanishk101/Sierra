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
    ///
    /// Strategy (keeps the chatbot alive for the entire user session):
    /// 1. Proactively refresh the Supabase session so the access token is always
    ///    fresh before we call the edge function. The SDK handles re-issuing the
    ///    JWT seamlessly via its stored refresh token - no sign-in required.
    /// 2. Build `FunctionInvokeOptions` with the fresh bearer token and call the
    ///    edge function directly - skipping `ensureValidSession`'s server-side
    ///    JWT verification round-trip which incorrectly fails on expired access
    ///    tokens even when a valid refresh token is available.
    /// 3. On an unexpected 401, perform one explicit refresh + retry before
    ///    surfacing an error to the caller.
    static func ask(prompt: String) async throws -> AskAIResponse {
        let request = AskAIRequest(prompt: prompt)

        // Step 1 - proactive refresh (silently ignored if already fresh)
        _ = try? await supabase.auth.refreshSession()

        // Step 2 - first attempt with freshly-obtained token
        do {
            let options = try await SupabaseManager.functionOptions(body: request)
            return try await supabase.functions.invoke("ask_ai", options: options)
        } catch {
            // Step 3 - on 401, force a refresh and retry exactly once
            guard SupabaseManager.isUnauthorizedEdgeError(error) else { throw error }
            _ = try await supabase.auth.refreshSession()
            let retryOptions = try await SupabaseManager.functionOptions(body: request)
            return try await supabase.functions.invoke("ask_ai", options: retryOptions)
        }
    }
}

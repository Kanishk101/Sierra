import Supabase
import Foundation

// MARK: - Supabase Global Client
// Used by all service files as `supabase`

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://ldqcdngdlbbiojlnbnjg.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkcWNkbmdkbGJiaW9qbG5ibmpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzODUzMjMsImV4cCI6MjA4ODk2MTMyM30.gQm6e-Uafm5bXfpbNEDCbl6bFgi1Cweg-tHE58nNdRE",
    options: .init(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
)

// MARK: - SupabaseManager (Wrapper for legacy code compatibility)

final class SupabaseManager {

    static let shared = SupabaseManager()
    private init() {}

    /// The underlying SupabaseClient.
    var client: SupabaseClient { supabase }

    /// Convenience Auth accessor.
    var auth: AuthClient { supabase.auth }

    /// Convenience Storage accessor.
    var storage: SupabaseStorageClient { supabase.storage }

    /// Returns a query builder for the given table name.
    func from(_ table: String) -> PostgrestQueryBuilder {
        supabase.from(table)
    }
}

// MARK: - Edge Function Auth Helpers
//
// ROOT CAUSE OF ALL 401s:
// The Supabase Swift SDK's FunctionsClient computes headers using a synchronous
// _headers property. When the async session fetch can't be awaited synchronously,
// the SDK falls back to `Authorization: Bearer <anon_key>`. Supabase's gateway
// for functions with verify_jwt:true rejects anon keys immediately (~100-400ms),
// before the Deno runtime ever boots. This is confirmed by the edge function logs
// showing 127–392ms 401 responses (gateway-level) vs 1000ms+ for real function runs.
//
// THE FIX: Explicitly get the access token via `supabase.auth.session` (async, correct)
// and pass it as the Authorization header in every functions.invoke() call.

extension SupabaseManager {

    // MARK: - currentBearerToken
    //
    // Gets the current user session's access token as a "Bearer <token>" string.
    // Throws if there is no active session (user is not authenticated).
    //
    // USAGE: Every functions.invoke() call MUST use this.
    //   let opts = try await SupabaseManager.functionOptions(body: myPayload)
    //   let result: MyType = try await supabase.functions.invoke("fn-name", options: opts)

    static func currentBearerToken() async throws -> String {
        let session = try await supabase.auth.session

        #if DEBUG
        let token = session.accessToken
        let parts = token.split(separator: ".").map(String.init)
        print("🔑 [SupabaseManager.currentBearerToken]")
        print("🔑   Session user ID    : \(session.user.id)")
        print("🔑   Session user email : \(session.user.email ?? "<nil>")")
        print("🔑   Token valid parts  : \(parts.count) (expected 3)")
        print("🔑   Token prefix [0..29]: \(String(token.prefix(30)))...")
        if parts.count == 3 {
            let padded = parts[1].padding(toLength: ((parts[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            if let data = Data(base64Encoded: padded),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔑   JWT.sub  : \(json["sub"] ?? "<MISSING>")")
                print("🔑   JWT.role : \(json["role"] ?? "<MISSING>")")
                if let exp = json["exp"] as? Double {
                    let remaining = Int(exp - Date().timeIntervalSince1970)
                    print("🔑   JWT.exp  : expires in \(remaining)s (\(remaining > 0 ? "VALID" : "*** EXPIRED ***"))")
                }
            }
        }
        #endif

        return "Bearer \(session.accessToken)"
    }

    // MARK: - functionOptions (Encodable body)
    //
    // Creates FunctionInvokeOptions with:
    //   - Authorization: Bearer <user_access_token>  ← THE CRITICAL FIX
    //   - Content-Type:  application/json             ← explicit for clarity
    //   - body:          JSON-encoded payload

    static func functionOptions<T: Encodable>(body: T) async throws -> FunctionInvokeOptions {
        let bearerToken = try await currentBearerToken()
        return FunctionInvokeOptions(
            headers: [
                "Authorization": bearerToken,
                "Content-Type":  "application/json",
            ],
            body: body
        )
    }

    // MARK: - functionOptionsNoBody
    //
    // For edge functions that take no request body.

    static func functionOptionsNoBody() async throws -> FunctionInvokeOptions {
        let bearerToken = try await currentBearerToken()
        return FunctionInvokeOptions(
            headers: [
                "Authorization": bearerToken,
                "Content-Type":  "application/json",
            ]
        )
    }
}

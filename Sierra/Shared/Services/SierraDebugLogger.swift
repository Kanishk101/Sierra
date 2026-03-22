import Foundation
import Supabase

// MARK: - SierraDebugLogger
//
// Centralised, exhaustively detailed debug utility.
// ALL output is #if DEBUG only — zero overhead in release builds.
//
// USAGE:
//   await SierraDebugLogger.logSessionState(context: "VehicleService.addVehicle")
//   await SierraDebugLogger.logRLSRole(context: "VehicleService.addVehicle")
//   SierraDebugLogger.logPayload(label: "VehicleInsert", payload: myPayload)
//   SierraDebugLogger.logPostgRESTError(context: "addVehicle", error: err, table: "vehicles", operation: "INSERT")
//   SierraDebugLogger.logEdgeFunctionError(context: "create-staff-account", error: err)

enum SierraDebugLogger {

    // MARK: - Session State
    //
    // Dumps the COMPLETE current Supabase auth session to the console.
    // Call this before ANY Supabase operation that is failing.
    // Answers: "Is the session present? Is the token valid? Who is the user?"

    static func logSessionState(context: String) async {
        #if DEBUG
        print("")
        print("🔍 [SierraDebug.sessionState] ══════════════════════════════════")
        print("🔍 [SierraDebug.sessionState] Context: \(context)")
        print("🔍 [SierraDebug.sessionState] Timestamp: \(Date())")
        print("🔍 [SierraDebug.sessionState] ───────────────────────────────────")

        // Check AppDataStore auth user
        if let authUser = AuthManager.shared.currentUser {
            print("🔍 [SierraDebug.sessionState] AuthManager.currentUser:")
            print("🔍   ID    : \(authUser.id)")
            print("🔍   Email : \(authUser.email)")
            print("🔍   Role  : \(authUser.role.rawValue)")
            print("🔍   isAuthenticated: \(AuthManager.shared.isAuthenticated)")
            print("🔍   isApproved     : \(authUser.isApproved)")
            print("🔍   isProfileComplete: \(authUser.isProfileComplete)")
        } else {
            print("🔍 [SierraDebug.sessionState] ⚠️  AuthManager.currentUser = NIL")
            print("🔍   → User is not logged in OR AuthManager state was lost")
        }

        print("🔍 [SierraDebug.sessionState] ───────────────────────────────────")

        // Check Supabase SDK session
        do {
            let session = try await supabase.auth.session
            let token = session.accessToken
            let parts = token.split(separator: ".").map(String.init)

            print("🔍 [SierraDebug.sessionState] supabase.auth.session: ✅ EXISTS")
            print("🔍   SDK session userID    : \(session.user.id)")
            print("🔍   SDK session userEmail : \(session.user.email ?? "<nil>")")
            print("🔍   Token type            : \(session.tokenType)")
            print("🔍   Refresh token present : \(!session.refreshToken.isEmpty)")
            print("🔍   Access token length   : \(token.count) chars")
            print("🔍   Access token parts    : \(parts.count) (must be 3 for valid JWT)")
            print("🔍   Access token [0..39]  : \(String(token.prefix(40)))...")

            if parts.count == 3 {
                // Decode JWT payload
                let padded = parts[1].padding(
                    toLength: ((parts[1].count + 3) / 4) * 4,
                    withPad: "=", startingAt: 0
                )
                if let data = Data(base64Encoded: padded),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 [SierraDebug.sessionState] JWT Payload decode:")
                    print("🔍   JWT.sub  : \(json[\"sub\"] ?? \"<MISSING — CRITICAL BUG>\")")
                    print("🔍   JWT.role : \(json[\"role\"] ?? \"<MISSING>\")")
                    print("🔍   JWT.email: \(json[\"email\"] ?? \"<MISSING>\")")
                    print("🔍   JWT.iss  : \(json[\"iss\"] ?? \"<MISSING>\")")
                    if let exp = json["exp"] as? Double {
                        let remaining = Int(exp - Date().timeIntervalSince1970)
                        let status = remaining > 0 ? "✅ VALID (\(remaining)s left)" : "❌ *** EXPIRED *** (\(abs(remaining))s ago)"
                        print("🔍   JWT.exp  : \(status)")
                    }
                    if let iat = json["iat"] as? Double {
                        let age = Int(Date().timeIntervalSince1970 - iat)
                        print("🔍   JWT.iat  : issued \(age)s ago")
                    }
                } else {
                    print("🔍   ⚠️ Could not decode JWT payload — token may be malformed")
                }
            } else {
                print("🔍   ❌ INVALID JWT — expected 3 parts, got \(parts.count)")
                print("🔍   This means the SDK is sending the ANON KEY, not a user JWT!")
                print("🔍   This is the root cause of all 401 errors on edge functions.")
            }

            // Cross-check: does SDK user ID match AuthManager user ID?
            if let authUID = AuthManager.shared.currentUser?.id {
                if session.user.id == authUID {
                    print("🔍 [SierraDebug.sessionState] ✅ SDK userID matches AuthManager userID")
                } else {
                    print("🔍 [SierraDebug.sessionState] ❌ MISMATCH: SDK userID=\(session.user.id) vs AuthManager userID=\(authUID)")
                    print("🔍   This indicates a stale session in one of the two systems.")
                }
            }
        } catch {
            print("🔍 [SierraDebug.sessionState] ❌ supabase.auth.session THREW an error:")
            print("🔍   Error type  : \(type(of: error))")
            print("🔍   Error detail: \(error)")
            print("🔍   Localized   : \(error.localizedDescription)")
            print("🔍   ⚠️  NO VALID SESSION — all authenticated Supabase calls WILL fail")
            print("🔍   → This is why PostgREST calls and edge functions return 401")
        }

        print("🔍 [SierraDebug.sessionState] ══════════════════════════════════")
        print("")
        #endif
    }

    // MARK: - RLS Role Check
    //
    // Runs SELECT get_my_role() against Supabase to verify the current
    // JWT resolves to the expected role in the DB. If this returns NULL or
    // wrong value, ALL role-gated RLS policies will deny writes.

    static func logRLSRole(context: String) async {
        #if DEBUG
        print("")
        print("🛡️  [SierraDebug.RLSRole] ══════════════════════════════════")
        print("🛡️  [SierraDebug.RLSRole] Context: \(context)")

        struct RoleRow: Decodable { let get_my_role: String? }
        do {
            let rows: [RoleRow] = try await supabase
                .from("staff_members")   // dummy table — rpc fallback
                .select("id")
                .limit(0)
                .execute()
                .value
            _ = rows // suppress unused warning

            // Direct RPC call to get_my_role()
            struct RPCResult: Decodable { let result: String? }
            let rawResult = try await supabase
                .rpc("get_my_role")
                .execute()
            let bodyStr = String(data: rawResult.data, encoding: .utf8) ?? "<binary>"
            print("🛡️  [SierraDebug.RLSRole] get_my_role() raw response: \(bodyStr)")

            // Parse the role string out of "fleetManager" or null
            if bodyStr.contains("fleetManager") {
                print("🛡️  [SierraDebug.RLSRole] ✅ Role = 'fleetManager' — INSERT/UPDATE RLS will PASS")
            } else if bodyStr.contains("driver") {
                print("🛡️  [SierraDebug.RLSRole] ℹ️  Role = 'driver'")
            } else if bodyStr.contains("maintenancePersonnel") {
                print("🛡️  [SierraDebug.RLSRole] ℹ️  Role = 'maintenancePersonnel'")
            } else if bodyStr == "null" || bodyStr.isEmpty {
                print("🛡️  [SierraDebug.RLSRole] ❌ Role = NULL")
                print("🛡️  → get_my_role() returned NULL — user has NO role in staff_members!")
                print("🛡️  → ALL role-gated RLS policies will DENY this user's writes")
                print("🛡️  → Check that staff_members row exists for UID=\(AuthManager.shared.currentUser?.id.uuidString ?? "unknown")")
            } else {
                print("🛡️  [SierraDebug.RLSRole] ⚠️  Unexpected role value: \(bodyStr)")
            }
        } catch {
            print("🛡️  [SierraDebug.RLSRole] ❌ RPC get_my_role() FAILED:")
            print("🛡️  Error: \(error)")
            print("🛡️  → This likely means the session JWT is invalid/missing")
        }

        print("🛡️  [SierraDebug.RLSRole] ══════════════════════════════════")
        print("")
        #endif
    }

    // MARK: - Payload Logger
    //
    // Encodes an Encodable to JSON and pretty-prints every field.
    // Use before insert/update calls to verify the exact payload being sent.

    static func logPayload<T: Encodable>(label: String, payload: T) {
        #if DEBUG
        print("")
        print("📦 [SierraDebug.payload] \(label) ══════════════════")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload),
           let str  = String(data: data, encoding: .utf8) {
            print(str)
        } else {
            print("  ⚠️  Could not encode payload to JSON")
        }
        print("📦 [SierraDebug.payload] ══════════════════")
        print("")
        #endif
    }

    // MARK: - PostgREST Error Logger
    //
    // Extracts and prints everything knowable about a PostgREST error.
    // Distinguishes 401 (no/bad JWT), 403 (RLS denial), 400 (bad request),
    // 404 (table not found / no rows matched), 409 (conflict/unique violation).

    static func logPostgRESTError(
        context:   String,
        error:     Error,
        table:     String,
        operation: String    // "INSERT", "UPDATE", "SELECT", "DELETE"
    ) {
        #if DEBUG
        print("")
        print("❌ [SierraDebug.PostgRESTError] ══════════════════════════════════")
        print("❌ Context   : \(context)")
        print("❌ Table     : \(table)")
        print("❌ Operation : \(operation)")
        print("❌ Error type: \(type(of: error))")
        print("❌ Localized : \(error.localizedDescription)")
        print("❌ Full error: \(error)")

        // Mirror the error to extract HTTP status code and PostgREST error body
        let mirror = Mirror(reflecting: error)
        for child in mirror.children {
            print("❌ Field [\(child.label ?? "?")] = \(child.value)")
        }

        // Pattern-match on description to give actionable advice
        let desc = error.localizedDescription.lowercased()
        let full = String(describing: error).lowercased()
        if desc.contains("401") || full.contains("401") || full.contains("jwt") || full.contains("unauthorized") {
            print("")
            print("❌ ╔════════════════════════════════════════════════════╗")
            print("❌ ║ DIAGNOSIS: 401 Unauthorized                       ║")
            print("❌ ║ The JWT is missing, expired, or invalid.          ║")
            print("❌ ║ PostgREST received either the anon key or nothing. ║")
            print("❌ ║ → Check SierraDebug.logSessionState() output      ║")
            print("❌ ║ → Ensure supabase.auth.session has an active JWT  ║")
            print("❌ ╚════════════════════════════════════════════════════╝")
        } else if desc.contains("403") || full.contains("403") || full.contains("rls") || full.contains("policy") || full.contains("permission") {
            print("")
            print("❌ ╔════════════════════════════════════════════════════╗")
            print("❌ ║ DIAGNOSIS: 403 Forbidden (RLS Policy Violation)   ║")
            print("❌ ║ JWT is valid but the RLS policy denied the op.    ║")
            print("❌ ║ For \(operation) on \(table):                       ")
            print("❌ ║ → Check SierraDebug.logRLSRole() — get_my_role()  ║")
            print("❌ ║   must return 'fleetManager' for this operation   ║")
            print("❌ ╚════════════════════════════════════════════════════╝")
        } else if desc.contains("409") || full.contains("409") || full.contains("unique") || full.contains("duplicate") {
            print("")
            print("❌ ╔════════════════════════════════════════════════════╗")
            print("❌ ║ DIAGNOSIS: 409 Conflict (Unique Constraint)       ║")
            print("❌ ║ A row with the same unique key already exists.    ║")
            print("❌ ║ Check for duplicate VIN, license plate, email etc ║")
            print("❌ ╚════════════════════════════════════════════════════╝")
        } else if desc.contains("400") || full.contains("400") {
            print("")
            print("❌ ╔════════════════════════════════════════════════════╗")
            print("❌ ║ DIAGNOSIS: 400 Bad Request                        ║")
            print("❌ ║ The payload has a type mismatch, missing column,  ║")
            print("❌ ║ or enum value that doesn't match the DB schema.   ║")
            print("❌ ║ Compare logPayload() output vs DB column types.   ║")
            print("❌ ╚════════════════════════════════════════════════════╝")
        }

        print("❌ [SierraDebug.PostgRESTError] ══════════════════════════════════")
        print("")
        #endif
    }

    // MARK: - Edge Function Error Logger
    //
    // Extracts everything about an edge function invocation failure.
    // Distinguishes:
    //   127–392ms 401 = gateway-level rejection (anon key / missing JWT)
    //   1000ms+  401  = function code returned 401 (invalid caller session)
    //   500            = function crashed internally (check edge fn logs)

    static func logEdgeFunctionError(
        context:      String,
        functionName: String,
        error:        Error,
        elapsedMs:    Int? = nil
    ) {
        #if DEBUG
        print("")
        print("🔥 [SierraDebug.EdgeFnError] ══════════════════════════════════")
        print("🔥 Context      : \(context)")
        print("🔥 Function     : \(functionName)")
        if let ms = elapsedMs {
            print("🔥 Elapsed      : \(ms)ms")
            if ms < 500 {
                print("🔥 ⚡ Very fast failure (< 500ms) = Supabase GATEWAY rejection")
                print("🔥   The function Deno runtime was never started.")
                print("🔥   The JWT (Authorization header) is the anon key, not a user JWT.")
                print("🔥   ╔═══════════════════════════════════════════════════════╗")
                print("🔥   ║ ROOT CAUSE: SDK is sending anon key to edge function ║")
                print("🔥   ║ FIX: Use SupabaseManager.functionOptions(body:)      ║")
                print("🔥   ║ which explicitly injects the user access token.      ║")
                print("🔥   ╚═══════════════════════════════════════════════════════╝")
            } else {
                print("🔥 ⏱️  Slower failure (> 500ms) = function ran before failing")
                print("🔥   Check Supabase Dashboard → Edge Functions → Logs for detail")
            }
        }
        print("🔥 Error type   : \(type(of: error))")
        print("🔥 Localized    : \(error.localizedDescription)")
        print("🔥 Full error   : \(error)")

        let mirror = Mirror(reflecting: error)
        for child in mirror.children {
            print("🔥 Field [\(child.label ?? "?")] = \(child.value)")
        }

        let desc = String(describing: error).lowercased()
        if desc.contains("401") || desc.contains("unauthorized") {
            print("")
            print("🔥 ══ 401 ANALYSIS ══")
            print("🔥 The Authorization header is missing a valid USER JWT.")
            print("🔥 Confirmed pattern (from Supabase edge fn logs):")
            print("🔥   fast 401s = gateway rejection of anon key")
            print("🔥   slow 401s = function code rejecting an invalid session")
            print("🔥 Action: Ensure SupabaseManager.functionOptions(body:) is used")
            print("🔥   and that supabase.auth.session is not throwing at call time.")
        } else if desc.contains("500") {
            print("")
            print("🔥 ══ 500 ANALYSIS ══")
            print("🔥 The edge function ran but crashed.")
            print("🔥 For check-resource-overlap: may be overload ambiguity in SQL fn.")
            print("🔥 Check Supabase Dashboard → Edge Functions → Logs → console.error output.")
        }

        print("🔥 [SierraDebug.EdgeFnError] ══════════════════════════════════")
        print("")
        #endif
    }

    // MARK: - Operation Banner
    //
    // Prints a clear section banner so you can find the relevant
    // block in a busy Xcode console.

    static func banner(_ title: String) {
        #if DEBUG
        let line = String(repeating: "─", count: max(0, 60 - title.count))
        print("")
        print("━━ \(title) \(line)")
        #endif
    }
}

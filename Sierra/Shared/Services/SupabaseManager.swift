import Supabase
import Foundation
import Functions

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
// These helpers enforce a single, consistent path for edge calls:
// 1. Ensure session is valid and server-verifiable.
// 2. Attach explicit Bearer token in FunctionInvokeOptions.
// 3. Retry once on HTTP 401 after a forced refresh.

extension SupabaseManager {

    enum SessionRecoveryError: LocalizedError {
        case unableToValidateSession

        var errorDescription: String? {
            switch self {
            case .unableToValidateSession:
                return "Session could not be validated. Please sign in again."
            }
        }
    }

    // MARK: - currentBearerToken

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

    // MARK: - Session Preflight

    /// Ensures there is a valid, server-verifiable auth session.
    /// If validation fails, refreshes once and then attempts secure-store recovery.
    @discardableResult
    static func ensureValidSession(expectedUserId: UUID? = nil) async throws -> Session {
        do {
            let session = try await supabase.auth.session
            _ = try await supabase.auth.user(jwt: session.accessToken)
            await persistCurrentSessionSnapshot()
            return session
        } catch {
            if isLikelyConnectivityError(error) { throw error }
            do {
                _ = try await supabase.auth.refreshSession()
                let refreshed = try await supabase.auth.session
                _ = try await supabase.auth.user(jwt: refreshed.accessToken)
                await persistCurrentSessionSnapshot()
                return refreshed
            } catch let refreshError {
                if isLikelyConnectivityError(refreshError) { throw refreshError }
                do {
                    let restored = try await restoreSessionFromSecureStore(expectedUserId: expectedUserId)
                    return restored
                } catch let restoreError {
                    if isLikelyConnectivityError(restoreError) { throw restoreError }
                    throw SessionRecoveryError.unableToValidateSession
                }
            }
        }
    }

    static func isSessionRecoveryError(_ error: Error) -> Bool {
        error is SessionRecoveryError
    }

    static func isUnauthorizedEdgeError(_ error: Error) -> Bool {
        if let fnError = error as? FunctionsError,
           case .httpError(let code, _) = fnError {
            return code == 401
        }

        let description = String(describing: error).lowercased()
        return description.contains("non-2xx status code: 401")
            || description.contains("unauthorized")
    }

    static func isLikelyConnectivityError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }

        let description = String(describing: error).lowercased()
        return description.contains("internet connection appears to be offline")
            || description.contains("timed out")
            || description.contains("tls")
            || description.contains("network")
    }

    // MARK: - Secure Session Snapshot

    static func persistCurrentSessionSnapshot() async {
        do {
            let session = try await supabase.auth.session
            guard !session.accessToken.isEmpty, !session.refreshToken.isEmpty else { return }
            SecureSessionStore.shared.saveSupabaseSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                userId: session.user.id
            )
        } catch {
            // Best-effort persistence only.
        }
    }

    static func restoreSessionFromSecureStore(expectedUserId: UUID? = nil) async throws -> Session {
        guard let snapshot = SecureSessionStore.shared.loadSupabaseSession() else {
            throw SessionRecoveryError.unableToValidateSession
        }

        if let expectedUserId, snapshot.userId != expectedUserId {
            SecureSessionStore.shared.clearSupabaseSession()
            throw SessionRecoveryError.unableToValidateSession
        }

        do {
            try await supabase.auth.setSession(
                accessToken: snapshot.accessToken,
                refreshToken: snapshot.refreshToken
            )
            _ = try? await supabase.auth.refreshSession()
            let restored = try await supabase.auth.session
            _ = try await supabase.auth.user(jwt: restored.accessToken)

            if let expectedUserId, restored.user.id != expectedUserId {
                SecureSessionStore.shared.clearSupabaseSession()
                throw SessionRecoveryError.unableToValidateSession
            }

            await persistCurrentSessionSnapshot()
            return restored
        } catch {
            if !isLikelyConnectivityError(error) {
                SecureSessionStore.shared.clearSupabaseSession()
            }
            throw error
        }
    }

    // MARK: - functionOptions

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

    static func functionOptionsNoBody() async throws -> FunctionInvokeOptions {
        let bearerToken = try await currentBearerToken()
        return FunctionInvokeOptions(
            headers: [
                "Authorization": bearerToken,
                "Content-Type":  "application/json",
            ]
        )
    }

    // MARK: - invokeEdgeWithSessionRecovery

    static func invokeEdgeWithSessionRecovery<Response: Decodable, Body: Encodable>(
        _ functionName: String,
        body: Body,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Response {
        _ = try await ensureValidSession()

        do {
            let options = try await functionOptions(body: body)
            return try await supabase.functions.invoke(functionName, options: options, decoder: decoder)
        } catch {
            guard isUnauthorizedEdgeError(error) else { throw error }
            _ = try await ensureValidSession()
            let retryOptions = try await functionOptions(body: body)
            return try await supabase.functions.invoke(functionName, options: retryOptions, decoder: decoder)
        }
    }

    static func invokeEdgeWithSessionRecovery<Response: Decodable>(
        _ functionName: String,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Response {
        _ = try await ensureValidSession()

        do {
            let options = try await functionOptionsNoBody()
            return try await supabase.functions.invoke(functionName, options: options, decoder: decoder)
        } catch {
            guard isUnauthorizedEdgeError(error) else { throw error }
            _ = try await ensureValidSession()
            let retryOptions = try await functionOptionsNoBody()
            return try await supabase.functions.invoke(functionName, options: retryOptions, decoder: decoder)
        }
    }

}

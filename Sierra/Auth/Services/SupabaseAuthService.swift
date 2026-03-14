import Foundation
import Supabase

// MARK: - SupabaseAuthService
// Thin wrapper isolating all supabase.auth.* calls.
// AuthManager delegates here and never imports Supabase directly.

struct SupabaseAuthService {

    private static var auth: AuthClient { SupabaseManager.shared.client.auth }

    // MARK: - Sign In

    /// Authenticates with email + password. Returns the Supabase Session.
    static func signIn(email: String, password: String) async throws -> Session {
        do {
            let session = try await auth.signIn(email: email, password: password)
            return session
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Sign Out

    /// Invalidates the Supabase session server-side and clears local tokens.
    static func signOut() async throws {
        do {
            try await auth.signOut()
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Current Session

    /// Returns the current valid session, or nil if not signed in / expired.
    static func currentSession() async -> Session? {
        return try? await auth.session
    }

    // MARK: - OTP

    /// Sends a 6-digit OTP to the user's email via Supabase Auth.
    /// Uses signInWithOTP which Supabase emails automatically.
    static func sendOTP(email: String) async throws {
        do {
            try await auth.signInWithOTP(email: email, shouldCreateUser: false)
        } catch {
            throw mapError(error)
        }
    }

    /// Verifies a 6-digit OTP token submitted by the user for email-type verification.
    static func verifyOTP(email: String, token: String) async throws {
        do {
            try await auth.verifyOTP(email: email, token: token, type: .email)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Password Management

    /// Updates the authenticated user's password. Requires an active session.
    static func updatePassword(_ newPassword: String) async throws {
        do {
            try await auth.update(user: UserAttributes(password: newPassword))
        } catch {
            throw mapError(error)
        }
    }

    /// Sends a password reset email. The link in the email handles the reset.
    static func requestPasswordReset(email: String) async throws {
        do {
            try await auth.resetPasswordForEmail(email)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Error Mapping

    /// Maps raw Supabase / URLSession errors into typed AuthError cases.
    private static func mapError(_ error: Error) -> AuthError {
        let message     = error.localizedDescription.lowercased()
        let description = String(describing: error).lowercased()
        let combined    = message + " " + description

        if combined.contains("invalid login credentials")
            || combined.contains("invalid email or password")
            || combined.contains("invalid credentials") {
            return .invalidCredentials
        }
        if combined.contains("otp expired")
            || combined.contains("token has expired")
            || combined.contains("expired") {
            return .otpExpired
        }
        if combined.contains("otp")
            || combined.contains("token is invalid")
            || combined.contains("invalid token") {
            return .otpInvalid
        }
        if combined.contains("email") && combined.contains("invalid") {
            return .networkError("Email address is invalid. Please use a real email address.")
        }
        if combined.contains("network")
            || combined.contains("could not connect")
            || combined.contains("connection")
            || combined.contains("url session") {
            return .networkError(error.localizedDescription)
        }
        // Default — return with full description for debugging
        return .networkError(error.localizedDescription)
    }
}

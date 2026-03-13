import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - TwoFactorSessionPayload

struct TwoFactorSessionPayload: Encodable {
    let userId: String
    let method: String
    let destination: String
    let otpHash: String
    let expiresAt: String
    let attemptCount: Int
    let maxAttempts: Int
    let isVerified: Bool
    let isLocked: Bool
    let lockedUntil: String?
    let verifiedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case method
        case destination
        case otpHash      = "otp_hash"
        case expiresAt    = "expires_at"
        case attemptCount = "attempt_count"
        case maxAttempts  = "max_attempts"
        case isVerified   = "is_verified"
        case isLocked     = "is_locked"
        case lockedUntil  = "locked_until"
        case verifiedAt   = "verified_at"
    }

    init(from session: TwoFactorSession) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.userId       = session.userId.uuidString
        self.method       = session.method.rawValue
        self.destination  = session.destination
        self.otpHash      = session.otpHash
        self.expiresAt    = fmt.string(from: session.expiresAt)
        self.attemptCount = session.attemptCount
        self.maxAttempts  = session.maxAttempts
        self.isVerified   = session.isVerified
        self.isLocked     = session.isLocked
        self.lockedUntil  = session.lockedUntil.map { fmt.string(from: $0) }
        self.verifiedAt   = session.verifiedAt.map { fmt.string(from: $0) }
    }
}

// MARK: - TwoFactorSessionService

struct TwoFactorSessionService {

    /// Returns the most recent active (non-verified) session for a user.
    static func fetchSession(userId: UUID) async throws -> TwoFactorSession {
        return try await supabase
            .from("two_factor_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_verified", value: false)
            .order("created_at", ascending: false)
            .limit(1)
            .single()
            .execute()
            .value
    }

    static func fetchAllSessions(userId: UUID) async throws -> [TwoFactorSession] {
        return try await supabase
            .from("two_factor_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Creates a new 2FA session (OTP sent to user).
    static func createSession(_ session: TwoFactorSession) async throws {
        let payload = TwoFactorSessionPayload(from: session)
        try await supabase
            .from("two_factor_sessions")
            .insert(payload)
            .execute()
    }

    /// Updates an existing session (e.g. increment attempt_count, mark is_verified).
    static func updateSession(_ session: TwoFactorSession) async throws {
        let payload = TwoFactorSessionPayload(from: session)
        try await supabase
            .from("two_factor_sessions")
            .update(payload)
            .eq("id", value: session.id.uuidString)
            .execute()
    }

    /// Deletes all 2FA sessions for a user (called after successful login or lockout reset).
    static func invalidateSessions(userId: UUID) async throws {
        try await supabase
            .from("two_factor_sessions")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Deletes a single session by its ID.
    static func deleteSession(id: UUID) async throws {
        try await supabase
            .from("two_factor_sessions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

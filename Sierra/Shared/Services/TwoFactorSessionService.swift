import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - TwoFactorSessionInsertPayload
// Excludes: id, verified_at, locked_until, is_locked, is_verified, attempt_count, created_at

struct TwoFactorSessionInsertPayload: Encodable {
    let userId: String
    let method: String
    let destination: String
    let otpHash: String
    let expiresAt: String
    let maxAttempts: Int

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case method, destination
        case otpHash     = "otp_hash"
        case expiresAt   = "expires_at"
        case maxAttempts = "max_attempts"
    }
}

// MARK: - TwoFactorSessionService

struct TwoFactorSessionService {

    // MARK: Create

    static func createSession(
        userId: UUID,
        method: TwoFactorMethod,
        destination: String,
        otpHash: String,
        expiresAt: Date
    ) async throws -> TwoFactorSession {
        let payload = TwoFactorSessionInsertPayload(
            userId:      userId.uuidString,
            method:      method.rawValue,
            destination: destination,
            otpHash:     otpHash,
            expiresAt:   iso.string(from: expiresAt),
            maxAttempts: 5
        )
        let sessions: [TwoFactorSession] = try await supabase
            .from("two_factor_sessions")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let session = sessions.first else {
            throw NSError(
                domain: "TwoFactorSessionService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Session not returned after insert"]
            )
        }
        return session
    }

    // MARK: Fetch

    static func fetchActiveSession(userId: UUID) async throws -> TwoFactorSession? {
        let rows: [TwoFactorSession] = try await supabase
            .from("two_factor_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_verified", value: false)
            .eq("is_locked", value: false)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: Increment Attempt

    static func incrementAttempt(sessionId: UUID) async throws -> TwoFactorSession? {
        // Use RPC or raw SQL increment to avoid race conditions.
        // Supabase Swift SDK doesn't expose rpc for increment, so we fetch and update.
        let rows: [TwoFactorSession] = try await supabase
            .from("two_factor_sessions")
            .select()
            .eq("id", value: sessionId.uuidString)
            .execute()
            .value
        guard var session = rows.first else { return nil }
        struct Payload: Encodable { let attempt_count: Int }
        try await supabase
            .from("two_factor_sessions")
            .update(Payload(attempt_count: session.attemptCount + 1))
            .eq("id", value: sessionId.uuidString)
            .execute()
        session.attemptCount += 1
        return session
    }

    // MARK: Mark Verified

    static func markVerified(sessionId: UUID) async throws {
        struct Payload: Encodable {
            let is_verified: Bool
            let verified_at: String
        }
        try await supabase
            .from("two_factor_sessions")
            .update(Payload(is_verified: true, verified_at: iso.string(from: Date())))
            .eq("id", value: sessionId.uuidString)
            .execute()
    }

    // MARK: Lock Session

    static func lockSession(sessionId: UUID, lockedUntil: Date) async throws {
        struct Payload: Encodable {
            let is_locked: Bool
            let locked_until: String
        }
        try await supabase
            .from("two_factor_sessions")
            .update(Payload(is_locked: true, locked_until: iso.string(from: lockedUntil)))
            .eq("id", value: sessionId.uuidString)
            .execute()
    }
}

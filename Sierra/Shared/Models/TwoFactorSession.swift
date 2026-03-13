import Foundation


// MARK: - TwoFactorSession
// Maps to table: two_factor_sessions

struct TwoFactorSession: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign key
    var userId: UUID                    // user_id (FK → auth.users.id)

    // MARK: Session details
    var method: TwoFactorMethod         // method (default 'email')
    var destination: String             // destination (email address or phone number)
    var otpHash: String                 // otp_hash (server-side hashed OTP)

    // MARK: Expiry and rate limiting
    var expiresAt: Date                 // expires_at
    var attemptCount: Int               // attempt_count (default 0)
    var maxAttempts: Int                // max_attempts (default 5)

    // MARK: State flags
    var isVerified: Bool                // is_verified (default false)
    var isLocked: Bool                  // is_locked (default false)
    var lockedUntil: Date?              // locked_until
    var verifiedAt: Date?               // verified_at

    // MARK: Timestamps
    var createdAt: Date                 // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case method
        case destination
        case otpHash       = "otp_hash"
        case expiresAt     = "expires_at"
        case attemptCount  = "attempt_count"
        case maxAttempts   = "max_attempts"
        case isVerified    = "is_verified"
        case isLocked      = "is_locked"
        case lockedUntil   = "locked_until"
        case verifiedAt    = "verified_at"
        case createdAt     = "created_at"
    }

    // MARK: - Computed

    var isExpired: Bool {
        expiresAt < Date()
    }

    var attemptsRemaining: Int {
        max(0, maxAttempts - attemptCount)
    }
}

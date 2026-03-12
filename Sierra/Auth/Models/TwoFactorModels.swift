import Foundation

// MARK: - 2FA Method Enum (extensible)

/// Supported 2FA verification methods.
/// v1 implements `.email` only. `.sms` and `.authenticator` are architected
/// but not wired — adding them requires only a new `OTPVerificationServiceProtocol`
/// conformance and no UI changes.
enum TwoFactorMethod: String, Codable, CaseIterable {
    case email         // v1 — implemented
    case sms           // future
    case authenticator // future (TOTP)

    var displayName: String {
        switch self {
        case .email:         "Email"
        case .sms:           "SMS"
        case .authenticator: "Authenticator App"
        }
    }

    var instructionText: String {
        switch self {
        case .email:
            "Enter the 6-digit code sent to your email address. The code expires in 10 minutes."
        case .sms:
            "Enter the 6-digit code sent to your phone number."
        case .authenticator:
            "Enter the 6-digit code from your authenticator app."
        }
    }

    var icon: String {
        switch self {
        case .email:         "envelope.fill"
        case .sms:           "message.fill"
        case .authenticator: "lock.app.dashed"
        }
    }
}

// MARK: - 2FA State

enum TwoFactorState: Equatable {
    case idle
    case sending
    case awaitingEntry
    case verifying
    case success
    case failed(attemptsRemaining: Int)
    case locked(unlockAt: Date)
    case expired
}

// MARK: - 2FA Session Context

struct TwoFactorContext {
    let userID: String
    let role: UserRole
    let method: TwoFactorMethod
    let maskedDestination: String
    let sessionToken: String
    /// The `AuthDestination` resolved from the user's profile state.
    let authDestination: AuthDestination
}

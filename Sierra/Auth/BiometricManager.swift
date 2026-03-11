import Foundation
import LocalAuthentication

// MARK: - Biometric Error

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case authFailed
    case userCancelled
    case lockedOut

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Biometric authentication is not available on this device."
        case .notEnrolled:
            "No biometric credentials enrolled. Set up Face ID or Touch ID in Settings."
        case .authFailed:
            "Biometric authentication failed. Please try again."
        case .userCancelled:
            "Authentication was cancelled."
        case .lockedOut:
            "Biometric authentication is locked. Please use your password."
        }
    }
}

// MARK: - Biometric Manager

/// Thread-safe biometric authentication manager using `actor` isolation.
actor BiometricManager {

    static let shared = BiometricManager()

    // MARK: - Availability

    /// Returns `true` if hardware supports and user has enrolled biometrics.
    nonisolated func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Returns the specific biometric type (.faceID / .touchID / .none).
    nonisolated func biometricType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error)
        else { return .none }
        return context.biometryType
    }

    /// Human-readable name for the current biometric type.
    nonisolated var biometricDisplayName: String {
        switch biometricType() {
        case .faceID:     "Face ID"
        case .touchID:    "Touch ID"
        case .opticID:    "Optic ID"
        case .none:       "Biometrics"
        @unknown default: "Biometrics"
        }
    }

    /// SF Symbol name for the current biometric type.
    nonisolated var biometricIconName: String {
        switch biometricType() {
        case .faceID:     "faceid"
        case .touchID:    "touchid"
        case .opticID:    "opticid"
        case .none:       "lock.fill"
        @unknown default: "lock.fill"
        }
    }

    // MARK: - Authenticate

    /// Presents the biometric prompt. Throws `BiometricError` on failure.
    func authenticate(reason: String = "Authenticate to access FleetOS") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"

        var nsError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &nsError) else {
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason)
            if !success { throw BiometricError.authFailed }
        } catch let laError as LAError {
            switch laError.code {
            case .biometryNotAvailable:  throw BiometricError.notAvailable
            case .biometryNotEnrolled:   throw BiometricError.notEnrolled
            case .userCancel:            throw BiometricError.userCancelled
            case .biometryLockout:       throw BiometricError.lockedOut
            default:                     throw BiometricError.authFailed
            }
        }
    }
}

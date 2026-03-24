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
    func authenticate(reason: String = "Authenticate to access Sierra") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"

        var nsError: NSError?
        let canUseBiometricOnly = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &nsError)

        if canUseBiometricOnly {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason)
                if !success { throw BiometricError.authFailed }
                return
            } catch let laError as LAError {
                throw mapLAError(laError)
            }
        }

        // If biometrics are temporarily locked out, allow passcode fallback.
        if let laError = nsError as? LAError, laError.code == .biometryLockout {
            var fallbackError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fallbackError) else {
                throw BiometricError.lockedOut
            }
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason)
                if !success { throw BiometricError.authFailed }
                return
            } catch let passcodeError as LAError {
                throw mapLAError(passcodeError)
            }
        }

        if let laError = nsError as? LAError {
            throw mapLAError(laError)
        }
        throw BiometricError.notAvailable
    }

    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:  return .notAvailable
        case .biometryNotEnrolled:   return .notEnrolled
        case .userCancel:            return .userCancelled
        case .biometryLockout:       return .lockedOut
        default:                     return .authFailed
        }
    }
}

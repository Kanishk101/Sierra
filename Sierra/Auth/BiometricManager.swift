import Foundation
import LocalAuthentication

/// Manages Face ID / Touch ID biometric authentication.
final class BiometricManager {

    static let shared = BiometricManager()
    private init() {}

    // MARK: - Error

    enum BiometricError: LocalizedError {
        case notAvailable
        case notEnrolled
        case authFailed
        case userCancelled
        case lockedOut
        case systemError(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                "Biometric authentication is not available on this device."
            case .notEnrolled:
                "No biometric credentials are enrolled. Please set up Face ID or Touch ID in Settings."
            case .authFailed:
                "Biometric authentication failed. Please try again."
            case .userCancelled:
                "Biometric authentication was cancelled."
            case .lockedOut:
                "Biometric authentication is locked. Please use your password."
            case .systemError(let message):
                message
            }
        }
    }

    // MARK: - Biometric Info

    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func biometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometricDisplayName: String {
        switch biometricType() {
        case .faceID:         "Face ID"
        case .touchID:        "Touch ID"
        case .opticID:        "Optic ID"
        case .none:           "Biometrics"
        @unknown default:     "Biometrics"
        }
    }

    var biometricIconName: String {
        switch biometricType() {
        case .faceID:         "faceid"
        case .touchID:        "touchid"
        case .opticID:        "opticid"
        case .none:           "lock.fill"
        @unknown default:     "lock.fill"
        }
    }

    // MARK: - Authenticate

    func authenticate(reason: String = "Sign in to FleetOS") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error as? LAError {
                throw mapError(laError)
            }
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !success {
                throw BiometricError.authFailed
            }
        } catch let laError as LAError {
            throw mapError(laError)
        }
    }

    // MARK: - Private

    private func mapError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockedOut
        case .userCancel, .appCancel, .systemCancel:
            return .userCancelled
        case .authenticationFailed:
            return .authFailed
        default:
            return .systemError(error.localizedDescription)
        }
    }
}

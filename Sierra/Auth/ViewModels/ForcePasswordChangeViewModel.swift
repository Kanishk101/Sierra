import Foundation
import SwiftUI

enum PasswordStrength: Int, Comparable {
    case weak = 0
    case fair = 1
    case strong = 2

    static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .weak:   "Weak"
        case .fair:   "Fair"
        case .strong: "Strong"
        }
    }

    var color: Color {
        switch self {
        case .weak:   .red
        case .fair:   SierraTheme.Colors.warning
        case .strong: .green
        }
    }

    /// Evaluate password strength from a plain-text password string.
    static func evaluate(_ password: String) -> PasswordStrength {
        guard password.count >= 8 else { return .weak }
        let hasUpper   = password.range(of: "[A-Z]",       options: .regularExpression) != nil
        let hasDigit   = password.range(of: "[0-9]",       options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        if hasUpper && hasDigit && hasSpecial { return .strong }
        return .fair
    }
}

@Observable
final class ForcePasswordChangeViewModel {

    // MARK: - Fields

    var currentPassword: String = ""
    var newPassword: String = ""
    var confirmPassword: String = ""

    var isCurrentPasswordVisible: Bool = false
    var isNewPasswordVisible: Bool = false
    var isConfirmPasswordVisible: Bool = false

    // MARK: - UI State

    var isLoading: Bool = false
    var errorMessage: String?
    var currentPasswordError: String?
    var passwordChanged: Bool = false
    var nextDestination: AuthDestination?
    var completed: Bool = false       // true once biometric sheet is dismissed
    var readyToNavigate: Bool = false // true right after password change — triggers biometric prompt

    // MARK: - Strength

    var strength: PasswordStrength {
        validatePasswordStrength(newPassword)
    }

    // MARK: - Requirement Checks

    var hasMinLength: Bool { newPassword.count >= 8 }

    var hasUppercase: Bool {
        newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
    }

    var hasNumber: Bool {
        newPassword.range(of: "[0-9]", options: .regularExpression) != nil
    }

    var hasSpecialChar: Bool {
        newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }

    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    var allRequirementsMet: Bool {
        hasMinLength && hasUppercase && hasNumber && hasSpecialChar && passwordsMatch
    }

    var canSubmit: Bool {
        !currentPassword.isEmpty && allRequirementsMet && !isLoading
    }

    var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return passwordsMatch ? nil : "Passwords don't match"
    }

    // MARK: - Actions

    func validatePasswordStrength(_ password: String) -> PasswordStrength {
        PasswordStrength.evaluate(password)
    }

    @MainActor
    func setNewPassword() async {
        guard canSubmit else { return }

        currentPasswordError = nil
        errorMessage = nil
        isLoading = true

        // 1. Verify current password against Keychain-stored hash (persisted at signIn time).
        guard verifyCurrentPassword() else {
            isLoading = false
            currentPasswordError = "Current password is incorrect"
            return
        }

        // 2. New password must differ from current.
        guard newPassword != currentPassword else {
            isLoading = false
            errorMessage = "New password must be different from your current password"
            return
        }

        do {
            // 3. Update via Supabase Auth + mark isFirstLogin = false in staff_members.
            try await AuthManager.shared.updatePassword(newPassword)

            // 4. Update stored hashed credential so biometric re-verify still works.
            let hashed = CryptoService.hash(password: newPassword)
            _ = KeychainService.save(hashed, forKey: "com.fleetOS.hashedCredential")

            // 5. Determine next destination.
            if let user = AuthManager.shared.currentUser {
                switch user.role {
                case .driver:               nextDestination = .driverOnboarding
                case .maintenancePersonnel: nextDestination = .maintenanceOnboarding
                case .fleetManager:         nextDestination = .fleetManagerDashboard
                }
            }

            // 6. Complete auth. Fleet manager gets a session token now;
            //    drivers/maintenance only after onboarding fully completes.
            let saveToken = AuthManager.shared.currentUser?.role == .fleetManager
            AuthManager.shared.completeAuthentication(saveToken: saveToken)

            isLoading = false
            readyToNavigate = true

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    /// Re-verifies the current password against the locally stored CryptoService hash.
    private func verifyCurrentPassword() -> Bool {
        guard let credential = KeychainService.load(
            key: "com.fleetOS.hashedCredential",
            as: CryptoService.HashedCredential.self
        ) else { return false }
        return CryptoService.verify(password: currentPassword, credential: credential)
    }
}

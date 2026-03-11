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
        case .fair:   .orange
        case .strong: .green
        }
    }

    /// Evaluate password strength from a plain-text password string.
    static func evaluate(_ password: String) -> PasswordStrength {
        guard password.count >= 8 else { return .weak }
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
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
    var awaitingOTP: Bool = false

    // MARK: - Strength

    var strength: PasswordStrength {
        validatePasswordStrength(newPassword)
    }

    // MARK: - Requirement Checks

    var hasMinLength: Bool {
        newPassword.count >= 8
    }

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

        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(1000))

        // Verify current password: check against this user's demo credential
        // or against the stored hashed credential (for production use)
        let isValidCurrent = AuthManager.shared.verifyDemoPassword(currentPassword) || verifyCurrentPassword()
        guard isValidCurrent else {
            isLoading = false
            currentPasswordError = "Current password is incorrect"
            return
        }

        // Hash and store the new password
        let hashed = CryptoService.hash(password: newPassword)
        _ = KeychainService.save(hashed, forKey: "com.fleetOS.hashedCredential")

        // Update user record
        if var user = AuthManager.shared.currentUser {
            user.isFirstLogin = false
            AuthManager.shared.currentUser = user
            _ = KeychainService.save(user, forKey: "com.fleetOS.currentUser")

            // Determine next destination based on role (used after OTP verification)
            switch user.role {
            case .driver:
                nextDestination = .driverOnboarding
            case .maintenancePersonnel:
                nextDestination = .maintenanceOnboarding
            case .fleetManager:
                nextDestination = .fleetManagerDashboard
            }
        }

        // Gap 1: Generate OTP for identity re-verification after password change
        AuthManager.shared.generateOTP()

        isLoading = false
        // Trigger the TwoFactorView fullScreenCover
        awaitingOTP = true
    }

    // MARK: - Private

    private func verifyCurrentPassword() -> Bool {
        guard let credential = KeychainService.load(
            key: "com.fleetOS.hashedCredential",
            as: CryptoService.HashedCredential.self
        ) else { return false }
        return CryptoService.verify(password: currentPassword, credential: credential)
    }
}

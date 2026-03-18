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

    static func evaluate(_ password: String) -> PasswordStrength {
        guard password.count >= 8 else { return .weak }
        let hasUpper   = password.range(of: "[A-Z]",        options: .regularExpression) != nil
        let hasDigit   = password.range(of: "[0-9]",        options: .regularExpression) != nil
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
    var showErrorAlert: Bool = false
    var currentPasswordError: String?
    // awaitingOTP triggers the 2FA fullScreenCover in ForcePasswordChangeView
    var awaitingOTP: Bool = false

    // MARK: - Strength

    var strength: PasswordStrength { PasswordStrength.evaluate(newPassword) }

    // MARK: - Requirement Checks

    var hasMinLength:   Bool { newPassword.count >= 8 }
    var hasUppercase:   Bool { newPassword.range(of: "[A-Z]", options: .regularExpression) != nil }
    var hasNumber:      Bool { newPassword.range(of: "[0-9]", options: .regularExpression) != nil }
    var hasSpecialChar: Bool { newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil }

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
        return passwordsMatch ? nil : "Passwords don\u{2019}t match"
    }

    // MARK: - Actions

    @MainActor
    func setNewPassword() async {
        guard canSubmit else { return }
        currentPasswordError = nil
        errorMessage = nil
        showErrorAlert = false
        isLoading = true

        // 1. Verify current password locally against the stored credential hash.
        let isValidCurrent = await verifyCurrentPasswordDirectly()
        guard isValidCurrent else {
            isLoading = false
            currentPasswordError = "Current password is incorrect"
            return
        }

        // 2. New password must differ from current
        guard newPassword != currentPassword else {
            isLoading = false
            errorMessage = "New password must be different from your current password"
            return
        }

        do {
            // 3. Update is_first_login flag and Supabase Auth password.
            try await AuthManager.shared.updatePasswordAndFirstLogin(newPassword: newPassword)

            // 4. Generate OTP and fire SwiftSMTP in background
            AuthManager.shared.generateOTP()
            isLoading = false
            awaitingOTP = true

        } catch {
            isLoading = false
            errorMessage = "Failed to update password. Please try again."
            showErrorAlert = true
        }
    }

    // MARK: - Private

    /// Verifies the entered current password using the last signed-in
    /// credential hash stored in Keychain.
    private func verifyCurrentPasswordDirectly() async -> Bool {
        guard let stored = KeychainService.load(
            key: "com.fleetOS.hashedCredential",
            as: CryptoService.HashedCredential.self
        ) else {
            return false
        }
        return CryptoService.verify(password: currentPassword, credential: stored)
    }
}

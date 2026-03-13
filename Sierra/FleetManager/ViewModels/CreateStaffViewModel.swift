import Foundation
import SwiftUI

@Observable
final class CreateStaffViewModel {

    // MARK: - Step 1: Role Selection

    var selectedRole: UserRole?

    var isRoleSelected: Bool {
        selectedRole != nil
    }

    // MARK: - Step 2: Details

    var fullName: String = ""
    var email: String = ""

    // MARK: - UI State

    var isLoading: Bool = false
    var successMessage: String?
    var errorMessage: String?
    var showSuccess: Bool = false
    var createdStaffName: String = ""

    // MARK: - Validation

    var nameError: String? {
        guard !fullName.isEmpty else { return nil }
        return fullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ? "Name too short" : nil
    }

    var emailError: String? {
        guard !email.isEmpty else { return nil }
        return isValidEmail(email) ? nil : "Enter a valid email address"
    }

    var canSubmit: Bool {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && trimmedName.count >= 2
            && !email.isEmpty
            && isValidEmail(email)
            && selectedRole != nil
    }

    // MARK: - Actions

    @MainActor
    func createStaff() async {
        guard canSubmit, let role = selectedRole else { return }

        isLoading = true
        errorMessage = nil

        let tempPassword = generateTemporaryPassword()
        let trimmedName  = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // 1. Create staff account via Edge Function (AuthManager handles service_role logic)
            try await AuthManager.shared.createStaffAccount(
                email: trimmedEmail,
                name: trimmedName,
                role: role,
                tempPassword: tempPassword
            )

            // 2. Send credentials email
            try await EmailService.sendCredentials(
                to: trimmedEmail,
                name: trimmedName,
                password: tempPassword,
                role: role
            )

            isLoading = false
            createdStaffName = trimmedName
            showSuccess = true
            successMessage = "Account created for \(trimmedName)"

            NotificationCenter.default.post(
                name: .staffCreated,
                object: nil,
                userInfo: [
                    "name":  trimmedName,
                    "email": trimmedEmail,
                    "role":  role.rawValue
                ]
            )
        } catch {
            isLoading = false
            if let authErr = error as? AuthError, authErr == .createStaffFailed {
                errorMessage = authErr.errorDescription
            } else {
                errorMessage = "Failed to create staff account. Please try again."
            }
        }
    }

    func reset() {
        selectedRole = nil
        fullName = ""
        email = ""
        isLoading = false
        successMessage = nil
        errorMessage = nil
        showSuccess = false
        createdStaffName = ""
    }

    // MARK: - Private

    private func generateTemporaryPassword() -> String {
        let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let digits    = "0123456789"
        let all       = uppercase + lowercase + digits

        var password = ""
        password += String(uppercase.randomElement()!)
        password += String(lowercase.randomElement()!)
        password += String(digits.randomElement()!)
        for _ in 0..<7 { password += String(all.randomElement()!) }
        return String(password.shuffled())
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Notification

extension Notification.Name {
    static let staffCreated = Notification.Name("staffCreated")
}

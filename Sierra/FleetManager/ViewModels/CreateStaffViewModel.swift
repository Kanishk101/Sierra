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
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await EmailService.sendCredentials(
                to: email.trimmingCharacters(in: .whitespacesAndNewlines),
                name: trimmedName,
                password: tempPassword,
                role: role
            )

            isLoading = false
            createdStaffName = trimmedName
            showSuccess = true
            successMessage = "Account created for \(trimmedName)"

            // Post notification so lists can refresh
            NotificationCenter.default.post(
                name: .staffCreated,
                object: nil,
                userInfo: [
                    "name": trimmedName,
                    "email": email,
                    "role": role.rawValue
                ]
            )
        } catch {
            isLoading = false
            errorMessage = "Failed to send credentials. Please try again."
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
        let digits = "0123456789"
        let all = uppercase + lowercase + digits

        // Guarantee at least one of each category
        var password = ""
        password += String(uppercase.randomElement()!)
        password += String(lowercase.randomElement()!)
        password += String(digits.randomElement()!)

        // Fill remaining 7 characters
        for _ in 0..<7 {
            password += String(all.randomElement()!)
        }

        // Shuffle to avoid predictable positions
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

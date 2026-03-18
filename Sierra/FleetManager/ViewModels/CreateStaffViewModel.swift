import Foundation
import SwiftUI
import Supabase

@Observable
final class CreateStaffViewModel {
    private struct CreateStaffAccountPayload: Encodable {
        let email: String
        let password: String
        let name: String
        let role: String
    }

    private struct CreateStaffAccountResponse: Decodable {
        let id: String
        let email: String
    }

    // MARK: - Step 1: Role Selection

    var selectedRole: UserRole?

    var isRoleSelected: Bool {
        selectedRole != nil
    }

    // MARK: - Step 2: Details

    var fullName: String = ""
    var email: String    = ""

    // MARK: - UI State

    var isLoading:        Bool    = false
    var errorMessage:     String?
    var showSuccess:      Bool    = false
    var createdStaffName: String  = ""
    var successMessage:   String  = ""

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
        guard role == .driver || role == .maintenancePersonnel else {
            errorMessage = "Only Driver or Maintenance accounts can be created here."
            return
        }

        isLoading = true
        errorMessage = nil

        let tempPassword = generateTemporaryPassword()
        let trimmedName  = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Step 1: Provision Supabase Auth user + staff_members row via edge function.
            let payload = CreateStaffAccountPayload(
                email: trimmedEmail,
                password: tempPassword,
                name: trimmedName,
                role: role.rawValue
            )
            let created: CreateStaffAccountResponse = try await supabase.functions.invoke(
                "create-staff-account",
                options: FunctionInvokeOptions(body: payload)
            )
            guard UUID(uuidString: created.id) != nil else {
                throw URLError(.badServerResponse)
            }

            // Step 2: Email credentials via SwiftSMTP
            try await EmailService.sendCredentials(
                to:       trimmedEmail,
                name:     trimmedName,
                password: tempPassword,
                role:     role
            )

            isLoading        = false
            createdStaffName = trimmedName
            showSuccess      = true
            successMessage   = "Account created for \(trimmedName)"

            NotificationCenter.default.post(
                name: .staffCreated,
                object: nil,
                userInfo: ["name": trimmedName, "email": trimmedEmail, "role": role.rawValue]
            )
        } catch {
            isLoading    = false
            errorMessage = "Failed to create staff account. Please try again."
        }
    }

    func reset() {
        selectedRole     = nil
        fullName         = ""
        email            = ""
        isLoading        = false
        errorMessage     = nil
        showSuccess      = false
        createdStaffName = ""
        successMessage   = ""
    }

    // MARK: - Private

    private func generateTemporaryPassword() -> String {
        let chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$"
        return String((0..<12).compactMap { _ in chars.randomElement() })
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

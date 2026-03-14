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
    var email: String    = ""

    // MARK: - UI State

    var isLoading:        Bool    = false
    var errorMessage:     String?
    var showSuccess:      Bool    = false
    var createdStaffName: String  = ""

    // Temp-password alert (shown after account creation so admin can copy it)
    var showTempPasswordAlert: Bool   = false
    var generatedTempPassword: String = ""

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

        isLoading    = true
        errorMessage = nil

        let tempPassword = generateTempPassword()
        let trimmedName  = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // 1. Create the account via Postgres RPC (no Edge Function needed)
            _ = try await AuthManager.shared.createStaffAccount(
                email:        trimmedEmail,
                name:         trimmedName,
                role:         role,
                tempPassword: tempPassword
            )

            // 2. Refresh the store so the new staff member appears immediately
            await AppDataStore.shared.loadAll()

            isLoading             = false
            createdStaffName      = trimmedName
            generatedTempPassword = tempPassword
            showTempPasswordAlert = true
            showSuccess           = true

            // 3. Open Mail app pre-filled with credentials (fire-and-forget)
            // If Mail app isn’t configured, the error is swallowed —
            // admin can still copy the password from the alert.
            Task { @MainActor in
                try? await EmailService.sendCredentials(
                    to:       trimmedEmail,
                    name:     trimmedName,
                    password: tempPassword,
                    role:     role
                )
            }

            NotificationCenter.default.post(
                name: .staffCreated,
                object: nil,
                userInfo: [
                    "name":  trimmedName,
                    "email": trimmedEmail,
                    "role":  role.rawValue
                ]
            )

        } catch let authErr as AuthError {
            isLoading    = false
            errorMessage = authErr.errorDescription ?? "Failed to create staff account."
        } catch {
            isLoading    = false
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        selectedRole          = nil
        fullName              = ""
        email                 = ""
        isLoading             = false
        errorMessage          = nil
        showSuccess           = false
        createdStaffName      = ""
        showTempPasswordAlert = false
        generatedTempPassword = ""
    }

    // MARK: - Private

    private func generateTempPassword() -> String {
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

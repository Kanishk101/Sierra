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

        isLoading = true
        errorMessage = nil

        let tempPassword = generateTemporaryPassword()
        let trimmedName  = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let newId        = UUID()
        let now          = Date()

        do {
            // Step 1: Build StaffMember with all v2 fields
            let newStaff = StaffMember(
                id:                    newId,
                name:                  trimmedName,
                role:                  role,
                status:                .pendingApproval,
                email:                 trimmedEmail,
                phone:                 nil,
                availability:          .unavailable,
                dateOfBirth:           nil,
                gender:                nil,
                address:               nil,
                emergencyContactName:  nil,
                emergencyContactPhone: nil,
                aadhaarNumber:         nil,
                profilePhotoUrl:       nil,
                isFirstLogin:          true,
                isProfileComplete:     false,
                isApproved:            false,
                rejectionReason:       nil,
                joinedDate:            now,
                createdAt:             now,
                updatedAt:             now
            )

            // Step 2: Insert into staff_members with password column
            try await StaffMemberService.addStaffMember(newStaff, password: tempPassword)

            // Step 3: Email credentials via SwiftSMTP
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

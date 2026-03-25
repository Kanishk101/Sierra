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

    var isLoading:           Bool    = false
    var errorMessage:        String?
    var showSuccess:         Bool    = false
    var createdStaffName:    String  = ""
    var createdStaffEmail:   String  = ""       // shown in confirmation
    var createdTempPassword: String? = nil      // non-nil only if email delivery failed
    var emailDelivered:      Bool    = true     // false → show password fallback

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

        // ─────────────────────────────────────────────────────────────────────
        // ── Phase 1: Create account (atomic — auth user + staff_members row) ──
        //
        // FIX: The 401 was caused by the Supabase Swift SDK sending the anon key
        // (not the user session JWT) to functions.invoke(). Supabase's gateway
        // rejects this in ~100-400ms before Deno even starts.
        //
        // Confirmed from edge function logs:
        //   create-staff-account v4: all 127-392ms 401s = gateway-level rejections
        //   create-staff-account v5: 2644ms 401 = function ran but callerClient.auth.getUser() failed
        //
        // SOLUTION: Explicitly get the user access token via supabase.auth.session
        // (async, correct) and pass it as the Authorization header directly.
        // ─────────────────────────────────────────────────────────────────────

        do {
            let payload = CreateStaffAccountPayload(
                email: trimmedEmail,
                password: tempPassword,
                name: trimmedName,
                role: role.rawValue
            )

            // CRITICAL FIX: inject the real user JWT, not the anon key
            let options = try await SupabaseManager.functionOptions(body: payload)

            let created: CreateStaffAccountResponse = try await supabase.functions.invoke(
                "create-staff-account",
                options: options
            )

            guard UUID(uuidString: created.id) != nil else {
                throw URLError(.badServerResponse)
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription.contains("already registered")
                ? "An account with this email already exists."
                : "Failed to create account: \(error.localizedDescription)"
            return
        }

        // ── Phase 2: Send credentials (non-fatal — account IS already created) ──
        var emailSent = false
        do {
            try await EmailService.sendCredentials(
                to:       trimmedEmail,
                name:     trimmedName,
                password: tempPassword,
                role:     role
            )
            emailSent = true
            #if DEBUG
            print("👤 [CreateStaff] ✅ Credential email sent to \(trimmedEmail)")
            #endif
        } catch {
            #if DEBUG
            print("👤 [CreateStaff] ⚠️  Email delivery failed (non-fatal): \(error)")
            #endif
        }

        isLoading            = false
        createdStaffName     = trimmedName
        createdStaffEmail    = trimmedEmail
        createdTempPassword  = emailSent ? nil : tempPassword
        emailDelivered       = emailSent
        showSuccess          = true

        NotificationCenter.default.post(
            name: .staffCreated,
            object: nil,
            userInfo: ["name": trimmedName, "email": trimmedEmail, "role": role.rawValue]
        )
    }

    func reset() {
        selectedRole         = nil
        fullName             = ""
        email                = ""
        isLoading            = false
        errorMessage         = nil
        showSuccess          = false
        createdStaffName     = ""
        createdStaffEmail    = ""
        createdTempPassword  = nil
        emailDelivered       = true
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

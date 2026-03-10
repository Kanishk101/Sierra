import Foundation

/// Simulates sending credential emails to newly created staff members.
/// In production this would call a real email API.
struct EmailService {

    struct EmailContent {
        let to: String
        let subject: String
        let body: String
    }

    /// Simulates sending login credentials to a new staff member.
    /// Prints the email content to console and returns after a 1.5s delay.
    static func sendCredentials(
        to email: String,
        name: String,
        password: String,
        role: UserRole
    ) async throws {

        let content = EmailContent(
            to: email,
            subject: "Welcome to FleetOS — Your Login Credentials",
            body: """
            ─────────────────────────────────────
            FleetOS — Staff Credential Notification
            ─────────────────────────────────────

            Hello \(name),

            Your FleetOS account has been created by a Fleet Administrator.
            Below are your login credentials:

            ┌──────────────────────────────────┐
            │  Email:    \(email)
            │  Password: \(password)
            │  Role:     \(role.displayName)
            └──────────────────────────────────┘

            ⚠️  IMPORTANT:
            You will be required to change your password on first login.
            After changing your password, please complete your profile
            to gain full access to the platform.

            If you did not expect this email, please contact your
            fleet administrator immediately.

            — The FleetOS Team
            ─────────────────────────────────────
            """
        )

        // Simulate network latency
        try await Task.sleep(for: .milliseconds(1500))

        // Print to console (dev simulation)
        print("\n📧 EMAIL SENT ────────────────────")
        print("To: \(content.to)")
        print("Subject: \(content.subject)")
        print(content.body)
        print("──────────────────────────────────\n")
    }
}

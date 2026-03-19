import Foundation
import Supabase

// MARK: - EmailService
//
// All emails are sent via the `send-email` Supabase Edge Function, which uses
// Gmail SMTP (credentials stored as Supabase secrets — never in source code).
//
// Supabase Auth built-in emails (confirmation, magic links) use the project's
// Custom SMTP setting in Auth > Settings, also pointed at Gmail.
//
// Three entry points:
//   sendCredentials  — async throws (fleet manager awaits confirmation)
//   sendLoginOTP     — fire-and-forget (called mid-login, failure is logged)
//   sendResetOTP     — fire-and-forget (called during reset flow)

struct EmailService {

    // MARK: - Private payload

    private struct Payload: Encodable {
        let to: String
        let subject: String
        let text: String
    }

    private struct SendResult: Decodable {
        let sent: Bool
    }

    // MARK: - Internal send (fire-and-forget)

    private static func send(to: String, subject: String, text: String) {
        Task {
            do {
                let _: SendResult = try await supabase.functions.invoke(
                    "send-email",
                    options: FunctionInvokeOptions(body: Payload(to: to, subject: subject, text: text))
                )
                print("[EmailService] ✅ sent to \(to)")
            } catch {
                // Non-fatal — log and continue. OTP is still valid in AuthManager.
                print("[EmailService] ⚠️ send failed to \(to): \(error)")
            }
        }
    }

    // MARK: - Send Credentials (async throws — fleet manager waits for confirmation)

    static func sendCredentials(
        to email: String,
        name: String,
        password: String,
        role: UserRole
    ) async throws {
        let subject = "Welcome to Sierra FMS — Your Login Credentials"
        let text = """
            ─────────────────────────────────────────
            Sierra Fleet Manager — New Account
            ─────────────────────────────────────────

            Hello \(name),

            Your Sierra FMS account has been created by a Fleet Administrator.

            Email:    \(email)
            Password: \(password)
            Role:     \(role.displayName)

            IMPORTANT: You must change your password on first login.
            After that, complete your profile to get full platform access.

            If you did not expect this, contact your fleet administrator immediately.

            — The Sierra FMS Team
            ─────────────────────────────────────────
            """

        let _: SendResult = try await supabase.functions.invoke(
            "send-email",
            options: FunctionInvokeOptions(body: Payload(to: email, subject: subject, text: text))
        )
    }

    // MARK: - Send 2FA Login OTP (fire-and-forget)

    static func sendLoginOTP(to email: String, otp: String) {
        send(
            to: email,
            subject: "Your Login Verification Code — Sierra FMS",
            text: """
                Sierra Fleet Manager — Login Verification
                ==========================================

                Your two-factor authentication code:

                \(otp)

                Valid for 10 minutes. Do not share it with anyone.

                If you did not attempt to sign in, contact your fleet administrator immediately.

                — Sierra FMS
                """
        )
    }

    // MARK: - Send Password Reset OTP (fire-and-forget)

    static func sendResetOTP(to email: String, otp: String) {
        send(
            to: email,
            subject: "Password Reset Code — Sierra FMS",
            text: """
                Sierra Fleet Manager — Password Reset
                =====================================

                Your password reset code:

                \(otp)

                Valid for 10 minutes.

                Did not request this? Ignore this email — your password is unchanged.

                — Sierra FMS
                """
        )
    }
}

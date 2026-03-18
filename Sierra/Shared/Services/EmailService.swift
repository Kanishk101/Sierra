import Foundation
import SwiftSMTP

// MARK: - EmailService
// Sends real emails via SwiftSMTP using Gmail SMTP.
// Used for: staff credential emails after account creation.

struct EmailService {

    private static let smtpHost     = "smtp.gmail.com"
    private static let smtpEmail    = "fleet.manager.system.infosys@gmail.com"
    private static let smtpPassword = "gnurohgfexvvemnn"
    private static let senderName   = "Fleet Manager System"

    // MARK: - Send Credentials

    /// Sends login credentials to a newly created staff member via Gmail SMTP.
    /// Called by CreateStaffViewModel after staff_members row is inserted.
    static func sendCredentials(
        to email: String,
        name: String,
        password: String,
        role: UserRole
    ) async throws {

        let subject = "Welcome to FleetOS \u{2014} Your Login Credentials"

        let body = """
            \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}
            FleetOS \u{2014} Staff Credential Notification
            \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

            Hello \(name),

            Your FleetOS account has been created by a Fleet Administrator.
            Below are your login credentials:

            Email:    \(email)
            Password: \(password)
            Role:     \(role.displayName)

            IMPORTANT:
            You will be required to change your password on first login.
            After changing your password, please complete your profile
            to gain full access to the platform.

            If you did not expect this email, please contact your
            fleet administrator immediately.

            \u{2014} The FleetOS Team
            \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}
            """

        let smtp = SMTP(
            hostname: smtpHost,
            email:    smtpEmail,
            password: smtpPassword
        )

        let mail = Mail(
            from: Mail.User(name: senderName, email: smtpEmail),
            to:   [Mail.User(name: name, email: email)],
            subject: subject,
            text:    body
        )

        // SwiftSMTP.send is callback-based - wrap in async continuation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            smtp.send(mail) { error in
                if let error = error {
                    print("[EmailService] ERROR sending credentials to \(email): \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("[EmailService] Credentials sent \u{2705} to \(email)")
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Send OTP (legacy helper - kept for reference; real 2FA now uses Supabase)

    static func sendOTP(to email: String, otp: String) {
        let smtp = SMTP(
            hostname: smtpHost,
            email:    smtpEmail,
            password: smtpPassword
        )

        let mail = Mail(
            from: Mail.User(name: senderName, email: smtpEmail),
            to:   [Mail.User(name: "User", email: email)],
            subject: "Your OTP Code",
            text: """
            Hello,

            Your One-Time Password (OTP) for verification is:

            OTP: \(otp)

            This OTP is valid for the next 5 minutes. Please do not share it with anyone.

            If you did not request this code, please ignore this email.

            Regards,
            Fleet Manager System
            """
        )

        smtp.send(mail) { error in
            if let error = error {
                print("[EmailService] OTP send error: \(error)")
            } else {
                print("[EmailService] OTP sent \u{2705} to \(email)")
            }
        }
    }

    // MARK: - 2FA Login OTP (migrated from sendEmail.swift)

    /// Sends a 2FA login verification OTP email.
    static func sendLoginOTP(to email: String, otp: String) {
        let smtp = SMTP(
            hostname: smtpHost,
            email:    smtpEmail,
            password: smtpPassword
        )

        let mail = Mail(
            from: Mail.User(name: senderName, email: smtpEmail),
            to:   [Mail.User(name: "User", email: email)],
            subject: "🔐 Your Login Verification Code - Sierra FMS",
            text: """
            Sierra Fleet Manager - Login Verification
            ==========================================

            Your two-factor authentication code:

            \(otp)

            This code is valid for 10 minutes.
            Do not share it with anyone.

            If you did not attempt to sign in to Sierra Fleet Manager,
            please contact your fleet administrator immediately.

            - Sierra Fleet Manager System
            """
        )

        smtp.send(mail) { error in
            if let error { print("[EmailService] 2FA email error: \(error)") }
            else          { print("[EmailService] 2FA OTP sent \u{2705} to \(email)") }
        }
    }

    // MARK: - Password Reset OTP (migrated from sendEmail.swift)

    /// Sends a password reset OTP email.
    static func sendResetOTP(to email: String, otp: String) {
        let smtp = SMTP(
            hostname: smtpHost,
            email:    smtpEmail,
            password: smtpPassword
        )

        let mail = Mail(
            from: Mail.User(name: senderName, email: smtpEmail),
            to:   [Mail.User(name: "User", email: email)],
            subject: "🔑 Password Reset Code - Sierra FMS",
            text: """
            Sierra Fleet Manager - Password Reset Request
            =============================================

            We received a request to reset your Sierra FMS account password.

            Your password reset code:

            \(otp)

            Enter this code in the app to set a new password.
            Valid for 10 minutes.

            ⚠️  Did not request this?
            If you did NOT ask for a password reset, ignore this email.
            Your password will remain unchanged and no action is needed.

            - Sierra Fleet Manager System
            """
        )

        smtp.send(mail) { error in
            if let error { print("[EmailService] Reset email error: \(error)") }
            else          { print("[EmailService] Reset OTP sent \u{2705} to \(email)") }
        }
    }
}


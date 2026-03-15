import Foundation
import SwiftSMTP

private let smtpClient = SMTP(
    hostname: "smtp.gmail.com",
    email:    "fleet.manager.system.infosys@gmail.com",
    password: "gnurohgfexvvemnn"
)

private let senderUser = Mail.User(
    name:  "Sierra Fleet Manager",
    email: "fleet.manager.system.infosys@gmail.com"
)

// MARK: - 2FA OTP Email

/// Sent during login 2FA — generic verification context.
func sendEmail(userEmail: String, otp: String) {
    let mail = Mail(
        from:    senderUser,
        to:      [Mail.User(name: "User", email: userEmail)],
        subject: "🔐 Your Login Verification Code — Sierra FMS",
        text: """
        Sierra Fleet Manager — Login Verification
        ==========================================

        Your two-factor authentication code:

        \(otp)

        This code is valid for 10 minutes.
        Do not share it with anyone.

        If you did not attempt to sign in to Sierra Fleet Manager,
        please contact your fleet administrator immediately.

        — Sierra Fleet Manager System
        """
    )

    smtpClient.send(mail) { error in
        if let error { print("2FA EMAIL ERROR: \(error)") }
        else          { print("2FA OTP SENT \u{2705}") }
    }
}

// MARK: - Password Reset OTP Email

/// Sent during Forgot Password — distinct template so users
/// can immediately tell this apart from a login verification code.
func sendResetEmail(userEmail: String, otp: String) {
    let mail = Mail(
        from:    senderUser,
        to:      [Mail.User(name: "User", email: userEmail)],
        subject: "🔑 Password Reset Code — Sierra FMS",
        text: """
        Sierra Fleet Manager — Password Reset Request
        =============================================

        We received a request to reset your Sierra FMS account password.

        Your password reset code:

        \(otp)

        Enter this code in the app to set a new password.
        Valid for 10 minutes.

        ⚠️  Did not request this?
        If you did NOT ask for a password reset, ignore this email.
        Your password will remain unchanged and no action is needed.

        — Sierra Fleet Manager System
        """
    )

    smtpClient.send(mail) { error in
        if let error { print("RESET EMAIL ERROR: \(error)") }
        else          { print("RESET OTP SENT \u{2705}") }
    }
}

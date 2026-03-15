import SwiftUI
import SwiftSMTP

/// Standalone helper used by legacy OTP flows.
/// Real 2FA now goes through Supabase signInWithOTP.
/// Kept for compatibility with any remaining callers.
func sendEmail(userEmail: String, otp: String) {
    let smtp = SMTP(
        hostname: "smtp.gmail.com",
        email:    "fleet.manager.system.infosys@gmail.com",
        password: "gnurohgfexvvemnn"
    )

    let mail = Mail(
        from: Mail.User(name: "Fleet Manager System", email: "fleet.manager.system.infosys@gmail.com"),
        to:   [Mail.User(name: "User", email: userEmail)],
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
            print("ERROR: \(error)")
        } else {
            print("OTP SENT \u{2705}")
        }
    }
}

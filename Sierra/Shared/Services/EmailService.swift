import Foundation
import UIKit

// MARK: - EmailService
// Sends staff credential emails via the iOS native Mail app (mailto: URL).
// The fleet manager's Mail app opens pre-filled with the credentials.
// They tap Send — done. No API keys, no backend, no Edge Function needed.

struct EmailService {

    // MARK: - Send Credentials

    /// Opens the native iOS Mail app pre-filled with the new staff member's credentials.
    /// Must be called on the MainActor so UIApplication.shared is accessible.
    @MainActor
    static func sendCredentials(
        to email: String,
        name: String,
        password: String,
        role: UserRole
    ) async throws {

        let subject = "Welcome to Sierra Fleet — Your Login Credentials"

        let body = """
        Hello \(name),

        Your Sierra Fleet account has been created by the Fleet Administrator.

        Your login credentials are below:

        Email:    \(email)
        Password: \(password)
        Role:     \(role.displayName)

        IMPORTANT: You will be required to change your password on first login.
        After changing your password, please complete your profile to gain full access.

        If you did not expect this email, please contact your fleet administrator immediately.

        — Sierra Fleet
        """

        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody    = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEmail   = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let mailURL = URL(string: "mailto:\(encodedEmail)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            throw EmailError.invalidEmail
        }

        guard UIApplication.shared.canOpenURL(mailURL) else {
            // Mail app not configured on this device — fall back to console
            print("[EmailService] Mail app not available. Credentials for \(email):")
            print("Password: \(password)")
            throw EmailError.mailAppUnavailable
        }

        await UIApplication.shared.open(mailURL)
    }
}

// MARK: - EmailError

enum EmailError: LocalizedError {
    case invalidEmail
    case mailAppUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Could not compose email — invalid address."
        case .mailAppUnavailable:
            return "Mail app is not configured on this device. Share the credentials manually."
        }
    }
}

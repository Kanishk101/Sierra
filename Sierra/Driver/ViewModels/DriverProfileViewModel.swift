import Foundation
import SwiftUI
import PhotosUI
import Supabase

// MARK: - Date formatter for Postgres DATE columns (yyyy-MM-dd)
private let pgDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

enum Gender: String, CaseIterable {
    case male = "Male"
    case female = "Female"
    case preferNotToSay = "Prefer not to say"
}

@Observable
final class DriverProfileViewModel {

    // ─────────────────────────────────
    // MARK: - Page 1: Personal Details
    // ─────────────────────────────────

    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var gender: Gender = .male
    var phoneNumber: String = ""
    var address: String = ""
    var emergencyContactName: String = ""
    var emergencyContactPhone: String = ""

    // ─────────────────────────────────
    // MARK: - Page 2: Documentation
    // ─────────────────────────────────

    // Aadhaar
    var aadhaarNumber: String = ""
    var aadhaarFrontImage: UIImage?
    var aadhaarBackImage: UIImage?

    // Driving License
    var licenseNumber: String = ""
    var licenseExpiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var licenseFrontImage: UIImage?
    var licenseBackImage: UIImage?

    // ─────────────────────────────────
    // MARK: - UI State
    // ─────────────────────────────────

    var currentStep: Int = 1
    var isLoading: Bool = false
    var errorMessage: String?
    var profileSubmitted: Bool = false

    var page1ValidationAttempted: Bool = false
    var page2ValidationAttempted: Bool = false

    // ─────────────────────────────────
    // MARK: - Max DOB (18+ years)
    // ─────────────────────────────────

    var maxDateOfBirth: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    // ─────────────────────────────────
    // MARK: - Address char limit
    // ─────────────────────────────────

    var addressCharCount: Int { address.count }
    let addressMaxChars = 200

    // ─────────────────────────────────
    // MARK: - Aadhaar formatter
    // ─────────────────────────────────

    // ISSUE-29 FIX: Display format adds spaces (UI only), storage format is raw 12 digits
    var formattedAadhaar: String {
        let digits = aadhaarNumber.filter(\.isNumber)
        var result = ""
        for (i, c) in digits.prefix(12).enumerated() {
            if i > 0, i % 4 == 0 { result += " " }
            result.append(c)
        }
        return result
    }

    /// Raw 12-digit Aadhaar for DB storage (no spaces)
    var rawAadhaar: String {
        String(aadhaarNumber.filter(\.isNumber).prefix(12))
    }

    func setAadhaarNumber(_ raw: String) {
        aadhaarNumber = String(raw.filter(\.isNumber).prefix(12))
    }

    // ─────────────────────────────────
    // MARK: - Page 1 Validation
    // ─────────────────────────────────

    var firstNameError: String? {
        guard page1ValidationAttempted else { return nil }
        return firstName.trimmingCharacters(in: .whitespaces).isEmpty ? "First name is required" : nil
    }

    var lastNameError: String? {
        guard page1ValidationAttempted else { return nil }
        return lastName.trimmingCharacters(in: .whitespaces).isEmpty ? "Last name is required" : nil
    }

    var phoneError: String? {
        guard page1ValidationAttempted else { return nil }
        let digits = phoneNumber.filter(\.isNumber)
        if digits.isEmpty { return "Phone number is required" }
        if digits.count < 10 { return "Enter a valid phone number" }
        return nil
    }

    var emergencyNameError: String? {
        guard page1ValidationAttempted else { return nil }
        return emergencyContactName.trimmingCharacters(in: .whitespaces).isEmpty ? "Emergency contact name is required" : nil
    }

    var emergencyPhoneError: String? {
        guard page1ValidationAttempted else { return nil }
        let digits = emergencyContactPhone.filter(\.isNumber)
        if digits.isEmpty { return "Emergency contact phone is required" }
        if digits.count < 10 { return "Enter a valid phone number" }
        return nil
    }

    var page1IsValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        && phoneNumber.filter(\.isNumber).count >= 10
        && !address.trimmingCharacters(in: .whitespaces).isEmpty  // ISSUE-16 FIX
        && !emergencyContactName.trimmingCharacters(in: .whitespaces).isEmpty
        && emergencyContactPhone.filter(\.isNumber).count >= 10
    }

    func validateAndAdvance() -> Bool {
        page1ValidationAttempted = true
        guard page1IsValid else { return false }
        currentStep = 2
        return true
    }

    // ─────────────────────────────────
    // MARK: - Page 2 Validation
    // ─────────────────────────────────

    var aadhaarError: String? {
        guard page2ValidationAttempted else { return nil }
        let digits = aadhaarNumber.filter(\.isNumber)
        if digits.isEmpty { return "Aadhaar number is required" }
        if digits.count != 12 { return "Must be 12 digits" }
        return nil
    }

    var licenseNumberError: String? {
        guard page2ValidationAttempted else { return nil }
        return licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty ? "License number is required" : nil
    }

    var aadhaarImagesError: String? {
        guard page2ValidationAttempted else { return nil }
        if aadhaarFrontImage == nil || aadhaarBackImage == nil {
            return "Both front and back images are required"
        }
        return nil
    }

    var licenseImagesError: String? {
        guard page2ValidationAttempted else { return nil }
        if licenseFrontImage == nil || licenseBackImage == nil {
            return "Both front and back images are required"
        }
        return nil
    }

    var page2IsValid: Bool {
        aadhaarNumber.filter(\.isNumber).count == 12
        && aadhaarFrontImage != nil
        && aadhaarBackImage != nil
        && !licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty
        && licenseFrontImage != nil
        && licenseBackImage != nil
    }

    // ─────────────────────────────────
    // MARK: - Submit
    // ─────────────────────────────────

    @MainActor
    func submitProfile() async {
        page2ValidationAttempted = true
        guard page2IsValid else { return }

        isLoading = true
        errorMessage = nil

        guard let user = AuthManager.shared.currentUser else {
            errorMessage = "No authenticated user found."
            isLoading = false
            return
        }

        let now = Date()
        let fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"

        // BUG-01 FIX: Upload KYC images to Supabase Storage before building the application
        var aadhaarDocUrl: String?
        var licenseDocUrl: String?

        do {
            let userId = user.id.uuidString
            let bucket = supabase.storage.from("kyc-documents")

            // Upload Aadhaar images (front + back) as a combined document entry
            if let frontData = aadhaarFrontImage?.jpegData(compressionQuality: 0.8) {
                let path = "\(userId)/aadhaar-front.jpg"
                try await bucket.upload(path, data: frontData, options: .init(contentType: "image/jpeg", upsert: true))
                let url = try bucket.getPublicURL(path: path)
                aadhaarDocUrl = url.absoluteString
            }
            if let backData = aadhaarBackImage?.jpegData(compressionQuality: 0.8) {
                let path = "\(userId)/aadhaar-back.jpg"
                try await bucket.upload(path, data: backData, options: .init(contentType: "image/jpeg", upsert: true))
                // Use front URL as the primary doc URL; back is stored separately
            }

            // Upload License images
            if let frontData = licenseFrontImage?.jpegData(compressionQuality: 0.8) {
                let path = "\(userId)/license-front.jpg"
                try await bucket.upload(path, data: frontData, options: .init(contentType: "image/jpeg", upsert: true))
                let url = try bucket.getPublicURL(path: path)
                licenseDocUrl = url.absoluteString
            }
            if let backData = licenseBackImage?.jpegData(compressionQuality: 0.8) {
                let path = "\(userId)/license-back.jpg"
                try await bucket.upload(path, data: backData, options: .init(contentType: "image/jpeg", upsert: true))
            }
        } catch {
            errorMessage = "Failed to upload documents: \(error.localizedDescription)"
            isLoading = false
            return
        }

        // Build the StaffApplication with real document URLs
        let application = StaffApplication(
            id: UUID(),
            staffMemberId: user.id,
            reviewedBy: nil,
            role: user.role,
            submittedDate: now,
            status: .pending,
            rejectionReason: nil,
            reviewedAt: nil,
            phone: phoneNumber,
            dateOfBirth: pgDateFormatter.string(from: dateOfBirth),
            gender: gender.rawValue,
            address: address,
            emergencyContactName: emergencyContactName,
            emergencyContactPhone: emergencyContactPhone,
            aadhaarNumber: rawAadhaar,  // ISSUE-29 FIX: store raw 12 digits
            aadhaarDocumentUrl: aadhaarDocUrl,
            profilePhotoUrl: nil,
            driverLicenseNumber: licenseNumber.trimmingCharacters(in: .whitespaces),
            driverLicenseExpiry: pgDateFormatter.string(from: licenseExpiryDate),
            driverLicenseClass: nil,
            driverLicenseIssuingState: nil,
            driverLicenseDocumentUrl: licenseDocUrl,
            maintCertificationType: nil,
            maintCertificationNumber: nil,
            maintIssuingAuthority: nil,
            maintCertificationExpiry: nil,
            maintCertificationDocumentUrl: nil,
            maintYearsOfExperience: nil,
            maintSpecializations: nil,
            createdAt: now
        )


        do {
            // Persist application to Supabase via AppDataStore
            try await AppDataStore.shared.addStaffApplication(application)



            // Also update the StaffMember record with the personal details collected
            if var member = AppDataStore.shared.staffMember(for: user.id) {
                member.name = fullName
                member.phone = phoneNumber
                member.dateOfBirth = pgDateFormatter.string(from: dateOfBirth)
                member.gender = gender.rawValue
                member.address = address
                member.emergencyContactName = emergencyContactName
                member.emergencyContactPhone = emergencyContactPhone
                member.aadhaarNumber = rawAadhaar  // ISSUE-29 FIX: consistent format
                member.isProfileComplete = true
                try await AppDataStore.shared.updateStaffMember(member)
            }

            // Mark profile complete in AuthManager / Keychain
            try await AuthManager.shared.markProfileComplete()

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        // Notify admin tab of the new pending approval
        NotificationCenter.default.post(
            name: .profileSubmitted,
            object: nil,
            userInfo: [
                "name": fullName,
                "role": user.role.rawValue
            ]
        )

        isLoading = false
        AuthManager.shared.saveSessionToken()
        profileSubmitted = true
    }

    func goBack() {
        currentStep = 1
    }
}

// MARK: - Notification

extension Notification.Name {
    static let profileSubmitted = Notification.Name("profileSubmitted")
}

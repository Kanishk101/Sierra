import Foundation
import SwiftUI
import PhotosUI
import Supabase

enum CertificationType: String, CaseIterable {
    case automotiveTechnician = "Automotive Technician"
    case dieselMechanic = "Diesel Mechanic"
    case electrician = "Electrician"
    case other = "Other"
}

enum Specialization: String, CaseIterable, Identifiable {
    case engineRepair = "Engine Repair"
    case transmission = "Transmission"
    case electrical = "Electrical"
    case tyres = "Tyres"
    case bodyWork = "Body Work"
    case other = "Other"

    var id: String { rawValue }
}

@Observable
final class MaintenanceProfileViewModel {

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

    // Technical Certification
    var certificationType: CertificationType = .automotiveTechnician
    var certificationNumber: String = ""
    var issuingAuthority: String = ""
    var certExpiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var certificateImage: UIImage?

    // Work Experience
    var yearsOfExperience: Int = 0
    var selectedSpecializations: Set<Specialization> = []

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
    // MARK: - Limits
    // ─────────────────────────────────

    var maxDateOfBirth: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    var addressCharCount: Int { address.count }
    let addressMaxChars = 200

    var formattedAadhaar: String {
        let digits = aadhaarNumber.filter(\.isNumber)
        var result = ""
        for (i, c) in digits.prefix(12).enumerated() {
            if i > 0, i % 4 == 0 { result += " " }
            result.append(c)
        }
        return result
    }

    func setAadhaarNumber(_ raw: String) {
        aadhaarNumber = String(raw.filter(\.isNumber).prefix(12))
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    func toggleSpecialization(_ spec: Specialization) {
        if selectedSpecializations.contains(spec) {
            selectedSpecializations.remove(spec)
        } else {
            selectedSpecializations.insert(spec)
        }
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

    var aadhaarImagesError: String? {
        guard page2ValidationAttempted else { return nil }
        if aadhaarFrontImage == nil || aadhaarBackImage == nil {
            return "Both front and back images are required"
        }
        return nil
    }

    var certNumberError: String? {
        guard page2ValidationAttempted else { return nil }
        return certificationNumber.trimmingCharacters(in: .whitespaces).isEmpty ? "Certification number is required" : nil
    }

    var authorityError: String? {
        guard page2ValidationAttempted else { return nil }
        return issuingAuthority.trimmingCharacters(in: .whitespaces).isEmpty ? "Issuing authority is required" : nil
    }

    var certImageError: String? {
        guard page2ValidationAttempted else { return nil }
        return certificateImage == nil ? "Certificate image is required" : nil
    }

    var page2IsValid: Bool {
        aadhaarNumber.filter(\.isNumber).count == 12
        && aadhaarFrontImage != nil
        && aadhaarBackImage != nil
        && !certificationNumber.trimmingCharacters(in: .whitespaces).isEmpty
        && !issuingAuthority.trimmingCharacters(in: .whitespaces).isEmpty
        && certificateImage != nil
    }

    // ─────────────────────────────────
    // MARK: - Submit
    // ─────────────────────────────────

    // MARK: - Image Upload Helper

    private func uploadImage(_ image: UIImage, path: String) async throws -> String {
        let resized = Self.resizeImage(image, maxDimension: 1200)
        guard let data = resized.jpegData(compressionQuality: 0.6) else {
            throw NSError(domain: "MaintenanceProfile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        try await supabase.storage
            .from("sierra-uploads")
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))
        let url = try supabase.storage
            .from("sierra-uploads")
            .getPublicURL(path: path)
        return url.absoluteString
    }

    /// Resize an image so its longest side is at most `maxDimension` points.
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

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

        // Upload document images to Supabase Storage
        var aadhaarUrl: String?
        var certUrl: String?

        do {
            if let front = aadhaarFrontImage {
                let frontUrl = try await uploadImage(front, path: "onboarding/\(user.id.uuidString)/aadhaar-front.jpg")
                if let back = aadhaarBackImage {
                    _ = try await uploadImage(back, path: "onboarding/\(user.id.uuidString)/aadhaar-back.jpg")
                    aadhaarUrl = frontUrl
                }
            }
            if let cert = certificateImage {
                certUrl = try await uploadImage(cert, path: "onboarding/\(user.id.uuidString)/certificate.jpg")
            }
        } catch {
            errorMessage = "Document upload failed: \(error.localizedDescription)"
            isLoading = false
            return
        }

        let application = StaffApplication(
            id: UUID(),
            staffMemberId: user.id,
            reviewedBy: nil,
            role: .maintenancePersonnel,
            submittedDate: now,
            status: .pending,
            rejectionReason: nil,
            reviewedAt: nil,
            phone: phoneNumber,
            dateOfBirth: dateFormatter.string(from: dateOfBirth),
            gender: gender.rawValue,
            address: address,
            emergencyContactName: emergencyContactName,
            emergencyContactPhone: emergencyContactPhone,
            aadhaarNumber: formattedAadhaar,
            aadhaarDocumentUrl: aadhaarUrl,
            profilePhotoUrl: nil,
            driverLicenseNumber: nil,
            driverLicenseExpiry: nil,
            driverLicenseClass: nil,
            driverLicenseIssuingState: nil,
            driverLicenseDocumentUrl: nil,
            maintCertificationType: certificationType.rawValue,
            maintCertificationNumber: certificationNumber.trimmingCharacters(in: .whitespaces),
            maintIssuingAuthority: issuingAuthority.trimmingCharacters(in: .whitespaces),
            maintCertificationExpiry: dateFormatter.string(from: certExpiryDate),
            maintCertificationDocumentUrl: certUrl,
            maintYearsOfExperience: yearsOfExperience,
            maintSpecializations: selectedSpecializations.map(\.rawValue),
            createdAt: now
        )


        do {
            try await AppDataStore.shared.addStaffApplication(application)



            if var member = AppDataStore.shared.staffMember(for: user.id) {
                member.name = fullName
                member.phone = phoneNumber
                member.dateOfBirth = dateFormatter.string(from: dateOfBirth)
                member.gender = gender.rawValue
                member.address = address
                member.emergencyContactName = emergencyContactName
                member.emergencyContactPhone = emergencyContactPhone
                member.aadhaarNumber = formattedAadhaar
                member.isProfileComplete = true
                try await AppDataStore.shared.updateStaffMember(member)
            }

            try await AuthManager.shared.markProfileComplete()

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        NotificationCenter.default.post(
            name: .profileSubmitted,
            object: nil,
            userInfo: [
                "name": fullName,
                "role": "maintenancePersonnel"
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

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
            aadhaarDocumentUrl: nil,
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
            maintCertificationDocumentUrl: nil,
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

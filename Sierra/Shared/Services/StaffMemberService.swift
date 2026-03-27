import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - StaffMemberServiceError

enum StaffMemberServiceError: LocalizedError {
    case availabilityTargetMissing(UUID)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .availabilityTargetMissing(let id):
            return "No staff_members row found for id \(id.uuidString.lowercased())"
        case .deleteFailed(let reason):
            return "Staff member deletion failed: \(reason)"
        }
    }
}

// MARK: - StaffMemberInsertPayload

struct StaffMemberInsertPayload: Encodable {
    let id: String
    let name: String?
    let role: String
    let status: String
    let email: String
    let phone: String?
    let availability: String
    let is_first_login: Bool
    let is_profile_complete: Bool
    let is_approved: Bool
    let rejection_reason: String?
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?
    let joined_date: String?

    init(from s: StaffMember) {
        self.id                      = s.id.uuidString
        self.name                    = s.name
        self.role                    = s.role.rawValue
        self.status                  = s.status.rawValue
        self.email                   = s.email
        self.phone                   = s.phone
        self.availability            = s.availability.rawValue
        self.is_first_login          = s.isFirstLogin
        self.is_profile_complete     = s.isProfileComplete
        self.is_approved             = s.isApproved
        self.rejection_reason        = s.rejectionReason
        self.date_of_birth           = s.dateOfBirth
        self.gender                  = s.gender
        self.address                 = s.address
        self.emergency_contact_name  = s.emergencyContactName
        self.emergency_contact_phone = s.emergencyContactPhone
        self.aadhaar_number          = s.aadhaarNumber
        self.profile_photo_url       = s.profilePhotoUrl
        self.joined_date             = s.joinedDate.map { iso.string(from: $0) }
    }
}

// MARK: - StaffMemberUpdatePayload
// Profile-only fields. Intentionally excludes `role` and `email`.

struct StaffMemberUpdatePayload: Encodable {
    let name: String?
    let phone: String?
    let availability: String
    let is_profile_complete: Bool
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?

    init(from s: StaffMember) {
        self.name                    = s.name
        self.phone                   = s.phone
        self.availability            = s.availability.rawValue
        self.is_profile_complete     = s.isProfileComplete
        self.date_of_birth           = s.dateOfBirth
        self.gender                  = s.gender
        self.address                 = s.address
        self.emergency_contact_name  = s.emergencyContactName
        self.emergency_contact_phone = s.emergencyContactPhone
        self.aadhaar_number          = s.aadhaarNumber
        self.profile_photo_url       = s.profilePhotoUrl
    }
}

// MARK: - StaffMemberDB

struct StaffMemberDB: Decodable {
    let id: UUID
    let name: String?
    let role: String
    let status: String
    let email: String
    let phone: String?
    let availability: String
    let is_first_login: Bool?
    let is_profile_complete: Bool?
    let is_approved: Bool?
    let rejection_reason: String?
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?
    let joined_date: String?
    let created_at: String?
    let updated_at: String?
}

// MARK: - StaffMemberDB Mappers

extension StaffMemberDB {
    func toStaffMember() -> StaffMember {
        StaffMember(
            id: id,
            name: name,
            role: UserRole(rawValue: role) ?? .driver,
            status: StaffStatus(rawValue: status) ?? .pendingApproval,
            email: email,
            phone: phone,
            availability: canonicalAvailability(availability),
            dateOfBirth: date_of_birth,
            gender: gender,
            address: address,
            emergencyContactName: emergency_contact_name,
            emergencyContactPhone: emergency_contact_phone,
            aadhaarNumber: aadhaar_number,
            profilePhotoUrl: profile_photo_url,
            isFirstLogin: is_first_login ?? true,
            isProfileComplete: is_profile_complete ?? false,
            isApproved: is_approved ?? false,
            rejectionReason: rejection_reason,
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
            joinedDate: joined_date.flatMap { iso.date(from: $0) },
            createdAt: created_at.flatMap { iso.date(from: $0) } ?? Date(),
            updatedAt: updated_at.flatMap { iso.date(from: $0) } ?? Date()
        )
    }

    func toAuthUser() -> AuthUser {
        AuthUser(
            id: id,
            email: email,
            role: UserRole(rawValue: role) ?? .driver,
            isFirstLogin: is_first_login ?? true,
            isProfileComplete: is_profile_complete ?? false,
            isApproved: is_approved ?? false,
            name: name,
            rejectionReason: rejection_reason,
            phone: phone,
            createdAt: created_at.flatMap { iso.date(from: $0) } ?? Date()
        )
    }

    // Collapse legacy "On Trip" / "On Task" → .busy so the UI never sees
    // fragmented states for what is semantically the same thing.
    private func canonicalAvailability(_ raw: String) -> StaffAvailability {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "available":
            return .available
        case "busy", "on trip", "on task":
            return .busy
        case "unavailable":
            return .unavailable
        default:
            return .unavailable
        }
    }
}

// MARK: - Edge function response types

private struct DeleteStaffResponse: Decodable {
    let success: Bool?
    let deletedId: String?
    let error: String?
}

// MARK: - StaffMemberService

struct StaffMemberService {

    // MARK: Fetch

    static func fetchAllStaffMembers() async throws -> [StaffMember] {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toStaffMember() }
    }

    static func fetchStaffMember(id: UUID) async throws -> StaffMember? {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
            .value
        return rows.first?.toStaffMember()
    }

    static func fetchStaffMembers(role: UserRole) async throws -> [StaffMember] {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: role.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
        return rows.map { $0.toStaffMember() }
    }

    static func fetchAvailableDrivers() async throws -> [StaffMember] {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("role", value: UserRole.driver.rawValue)
            .eq("status", value: StaffStatus.active.rawValue)
            .eq("availability", value: StaffAvailability.available.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
        return rows.map { $0.toStaffMember() }
    }

    // MARK: Insert (internal/test only — real creation goes through create-staff-account edge fn)

    static func addStaffMember(_ member: StaffMember) async throws {
        try await supabase
            .from("staff_members")
            .insert(StaffMemberInsertPayload(from: member))
            .execute()
    }

    // MARK: Update (profile fields only — role and email excluded intentionally)

    static func updateStaffMember(_ member: StaffMember) async throws {
        try await supabase
            .from("staff_members")
            .update(StaffMemberUpdatePayload(from: member))
            .eq("id", value: member.id.uuidString.lowercased())
            .execute()
    }

    // MARK: - setAvailability (explicit value, not just bool)
    //
    // Preferred API — callers pass the exact StaffAvailability they want.
    // Only writes Available, Unavailable, or Busy — never the legacy On Trip / On Task.

    static func setAvailability(staffId: UUID, availability: StaffAvailability) async throws -> StaffAvailability {
        let canonical: StaffAvailability = availability == .busy ? .busy : availability

        struct Payload: Encodable { let availability: String }
        struct Row:     Decodable { let id: UUID; let availability: String }

        let idLower = staffId.uuidString.lowercased()

        let rows: [Row] = try await supabase
            .from("staff_members")
            .update(Payload(availability: canonical.rawValue))
            .eq("id", value: idLower)
            .select("id, availability")
            .execute()
            .value

        if rows.isEmpty {
            throw StaffMemberServiceError.availabilityTargetMissing(staffId)
        }
        // Canonicalise the confirmed value the same way we do on read
        switch rows[0].availability {
        case "On Trip", "On Task", "Busy": return .busy
        default: return StaffAvailability(rawValue: rows[0].availability) ?? canonical
        }
    }

    // MARK: - updateAvailability (legacy Bool API — preserved for call sites that still use it)
    //
    // Internally delegates to setAvailability so the normalisation logic is shared.

    static func updateAvailability(staffId: UUID, available: Bool) async throws -> String {
        let target: StaffAvailability = available ? .available : .unavailable
        let confirmed = try await setAvailability(staffId: staffId, availability: target)
        return confirmed.rawValue
    }

    // MARK: - Delete (via edge function)

    static func deleteStaffMember(id: UUID) async throws {
        struct Payload: Encodable { let staffMemberId: String }

        let options = try await SupabaseManager.functionOptions(
            body: Payload(staffMemberId: id.uuidString)
        )
        let response: DeleteStaffResponse = try await supabase.functions.invoke(
            "delete-staff-member",
            options: options
        )

        if let errorMsg = response.error {
            throw StaffMemberServiceError.deleteFailed(errorMsg)
        }
    }

    // MARK: - Mark Profile Complete

    static func markProfileComplete(
        staffId: UUID,
        name: String,
        phone: String,
        gender: String,
        dateOfBirth: String,
        address: String,
        emergencyContactName: String,
        emergencyContactPhone: String,
        aadhaarNumber: String
    ) async throws {
        struct Payload: Encodable {
            let is_profile_complete: Bool
            let name: String
            let phone: String
            let gender: String
            let date_of_birth: String
            let address: String
            let emergency_contact_name: String
            let emergency_contact_phone: String
            let aadhaar_number: String
        }
        try await supabase
            .from("staff_members")
            .update(Payload(
                is_profile_complete:     true,
                name:                    name,
                phone:                   phone,
                gender:                  gender,
                date_of_birth:           dateOfBirth,
                address:                 address,
                emergency_contact_name:  emergencyContactName,
                emergency_contact_phone: emergencyContactPhone,
                aadhaar_number:          aadhaarNumber
            ))
            .eq("id", value: staffId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Set Approval Status
    //
    // When approving, sets is_approved=true, status=Active, availability=Available.
    // Separately call copyApplicationDataToProfile to migrate personal + role data.

    static func setApprovalStatus(
        staffId: UUID,
        approved: Bool,
        rejectionReason: String? = nil
    ) async throws {
        struct ApprovePayload: Encodable {
            let is_approved: Bool
            let status: String
            let rejection_reason: String?
        }
        struct AvailabilityPayload: Encodable { let availability: String }
        struct JoinedDatePayload: Encodable { let joined_date: String }
        struct RejectPayload: Encodable {
            let is_approved: Bool
            let status: String
            let rejection_reason: String?
        }

        if approved {
            try await supabase
                .from("staff_members")
                .update(ApprovePayload(
                    is_approved:      true,
                    status:           StaffStatus.active.rawValue,
                    rejection_reason: nil
                ))
                .eq("id", value: staffId.uuidString.lowercased())
                .execute()

            // Best-effort enrichments: do not fail approval if these optional writes fail.
            _ = try? await supabase
                .from("staff_members")
                .update(AvailabilityPayload(availability: StaffAvailability.available.rawValue))
                .eq("id", value: staffId.uuidString.lowercased())
                .execute()

            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            let joinedDate = df.string(from: Date())

            _ = try? await supabase
                .from("staff_members")
                .update(JoinedDatePayload(joined_date: joinedDate))
                .eq("id", value: staffId.uuidString.lowercased())
                .execute()
        } else {
            try await supabase
                .from("staff_members")
                .update(RejectPayload(
                    is_approved:      false,
                    status:           StaffStatus.suspended.rawValue,
                    rejection_reason: rejectionReason
                ))
                .eq("id", value: staffId.uuidString.lowercased())
                .execute()
        }
    }

    // MARK: - copyApplicationDataToProfile
    //
    // Copies personal fields from a StaffApplication into the staff_members row
    // and creates the appropriate driver_profiles or maintenance_profiles row.
    // Called by AppDataStore.approveStaffApplication after setApprovalStatus.

    static func copyApplicationDataToProfile(_ app: StaffApplication) async throws {
        // --- 1. Copy personal fields to staff_members ---
        struct PersonalPayload: Encodable {
            let phone: String
            let date_of_birth: String
            let gender: String
            let address: String
            let emergency_contact_name: String
            let emergency_contact_phone: String
            let aadhaar_number: String
            let profile_photo_url: String?
            let is_profile_complete: Bool
        }
        try await supabase
            .from("staff_members")
            .update(PersonalPayload(
                phone:                   app.phone,
                date_of_birth:           app.dateOfBirth,
                gender:                  app.gender,
                address:                 app.address,
                emergency_contact_name:  app.emergencyContactName,
                emergency_contact_phone: app.emergencyContactPhone,
                aadhaar_number:          app.aadhaarNumber,
                profile_photo_url:       app.profilePhotoUrl,
                is_profile_complete:     true
            ))
            .eq("id", value: app.staffMemberId.uuidString.lowercased())
            .execute()

        // --- 2. Create role-specific profile row if it doesn't exist ---
        switch app.role {
        case .driver:
            // Check if a driver_profiles row already exists
            struct ExistRow: Decodable { let id: UUID }
            let existing: [ExistRow] = try await supabase
                .from("driver_profiles")
                .select("id")
                .eq("staff_member_id", value: app.staffMemberId.uuidString.lowercased())
                .execute()
                .value
            guard existing.isEmpty else { return }

            struct DriverProfileInsert: Encodable {
                let staff_member_id: String
                let license_number: String
                let license_expiry: String
                let license_class: String
                let license_issuing_state: String
                let license_document_url: String?
                let aadhaar_document_url: String?
                let total_trips_completed: Int
                let total_distance_km: Double
            }
            try await supabase
                .from("driver_profiles")
                .insert(DriverProfileInsert(
                    staff_member_id:      app.staffMemberId.uuidString,
                    license_number:       app.driverLicenseNumber ?? "",
                    license_expiry:       app.driverLicenseExpiry ?? "2030-01-01",
                    license_class:        app.driverLicenseClass ?? "LMV",
                    license_issuing_state: app.driverLicenseIssuingState ?? "",
                    license_document_url: app.driverLicenseDocumentUrl,
                    aadhaar_document_url: app.aadhaarDocumentUrl,
                    total_trips_completed: 0,
                    total_distance_km:    0.0
                ))
                .execute()

        case .maintenancePersonnel:
            struct ExistRow: Decodable { let id: UUID }
            let existing: [ExistRow] = try await supabase
                .from("maintenance_profiles")
                .select("id")
                .eq("staff_member_id", value: app.staffMemberId.uuidString.lowercased())
                .execute()
                .value
            guard existing.isEmpty else { return }

            struct MaintProfileInsert: Encodable {
                let staff_member_id: String
                let certification_type: String
                let certification_number: String
                let issuing_authority: String
                let certification_expiry: String
                let certification_document_url: String?
                let years_of_experience: Int
                let specializations: [String]
                let aadhaar_document_url: String?
            }
            try await supabase
                .from("maintenance_profiles")
                .insert(MaintProfileInsert(
                    staff_member_id:           app.staffMemberId.uuidString,
                    certification_type:        app.maintCertificationType ?? "General",
                    certification_number:      app.maintCertificationNumber ?? "",
                    issuing_authority:         app.maintIssuingAuthority ?? "",
                    certification_expiry:      app.maintCertificationExpiry ?? "2030-01-01",
                    certification_document_url: app.maintCertificationDocumentUrl,
                    years_of_experience:       app.maintYearsOfExperience ?? 0,
                    specializations:           app.maintSpecializations ?? [],
                    aadhaar_document_url:      app.aadhaarDocumentUrl
                ))
                .execute()

        case .fleetManager:
            break // Fleet managers have no separate profile table
        }
    }

    // MARK: - Set Status (admin-only: suspend / reactivate)

    static func setStatus(staffId: UUID, status: StaffStatus) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase
            .from("staff_members")
            .update(Payload(status: status.rawValue))
            .eq("id", value: staffId.uuidString.lowercased())
            .execute()
    }
}

// MARK: - StaffMember → AuthUser Mapper

extension StaffMember {
    func toAuthUser() -> AuthUser {
        AuthUser(
            id:                id,
            email:             email,
            role:              role,
            isFirstLogin:      isFirstLogin,
            isProfileComplete: isProfileComplete,
            isApproved:        isApproved,
            name:              name,
            rejectionReason:   rejectionReason,
            phone:             phone,
            createdAt:         createdAt
        )
    }
}

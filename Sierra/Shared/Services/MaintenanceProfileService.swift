import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - MaintenanceProfilePayload

struct MaintenanceProfilePayload: Encodable {
    let staffMemberId: String
    let certificationType: String
    let certificationNumber: String
    let issuingAuthority: String
    let certificationExpiry: String
    let certificationDocumentUrl: String?
    let yearsOfExperience: Int
    let specializations: [String]
    let totalTasksAssigned: Int
    let totalTasksCompleted: Int
    let aadhaarDocumentUrl: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case staffMemberId             = "staff_member_id"
        case certificationType         = "certification_type"
        case certificationNumber       = "certification_number"
        case issuingAuthority          = "issuing_authority"
        case certificationExpiry       = "certification_expiry"
        case certificationDocumentUrl  = "certification_document_url"
        case yearsOfExperience         = "years_of_experience"
        case specializations
        case totalTasksAssigned        = "total_tasks_assigned"
        case totalTasksCompleted       = "total_tasks_completed"
        case aadhaarDocumentUrl        = "aadhaar_document_url"
        case notes
    }

    init(from profile: MaintenanceProfile) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.staffMemberId             = profile.staffMemberId.uuidString
        self.certificationType         = profile.certificationType
        self.certificationNumber       = profile.certificationNumber
        self.issuingAuthority         = profile.issuingAuthority
        self.certificationExpiry       = fmt.string(from: profile.certificationExpiry)
        self.certificationDocumentUrl  = profile.certificationDocumentUrl
        self.yearsOfExperience         = profile.yearsOfExperience
        self.specializations           = profile.specializations
        self.totalTasksAssigned        = profile.totalTasksAssigned
        self.totalTasksCompleted       = profile.totalTasksCompleted
        self.aadhaarDocumentUrl        = profile.aadhaarDocumentUrl
        self.notes                     = profile.notes
    }
}

// MARK: - MaintenanceProfileService

struct MaintenanceProfileService {

    static func fetchAllMaintenanceProfiles() async throws -> [MaintenanceProfile] {
        return try await supabase
            .from("maintenance_profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchMaintenanceProfile(staffMemberId: UUID) async throws -> MaintenanceProfile {
        return try await supabase
            .from("maintenance_profiles")
            .select()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .single()
            .execute()
            .value
    }

    static func addMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        let payload = MaintenanceProfilePayload(from: profile)
        try await supabase
            .from("maintenance_profiles")
            .insert(payload)
            .execute()
    }

    static func updateMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        let payload = MaintenanceProfilePayload(from: profile)
        try await supabase
            .from("maintenance_profiles")
            .update(payload)
            .eq("id", value: profile.id.uuidString)
            .execute()
    }

    static func deleteMaintenanceProfile(id: UUID) async throws {
        try await supabase
            .from("maintenance_profiles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

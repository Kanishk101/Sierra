import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - MaintenanceProfileInsertPayload
// Excludes: id, created_at, updated_at

struct MaintenanceProfileInsertPayload: Encodable {
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

    init(from p: MaintenanceProfile) {
        staffMemberId            = p.staffMemberId.uuidString
        certificationType        = p.certificationType
        certificationNumber      = p.certificationNumber
        issuingAuthority         = p.issuingAuthority
        certificationExpiry = p.certificationExpiry
        certificationDocumentUrl = p.certificationDocumentUrl
        yearsOfExperience        = p.yearsOfExperience
        specializations          = p.specializations
        totalTasksAssigned       = p.totalTasksAssigned
        totalTasksCompleted      = p.totalTasksCompleted
        aadhaarDocumentUrl       = p.aadhaarDocumentUrl
        notes                    = p.notes
    }
}

// MARK: - MaintenanceProfileUpdatePayload
// Excludes: id, staff_member_id, created_at, updated_at

struct MaintenanceProfileUpdatePayload: Encodable {
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

    init(from p: MaintenanceProfile) {
        certificationType        = p.certificationType
        certificationNumber      = p.certificationNumber
        issuingAuthority         = p.issuingAuthority
        certificationExpiry = p.certificationExpiry
        certificationDocumentUrl = p.certificationDocumentUrl
        yearsOfExperience        = p.yearsOfExperience
        specializations          = p.specializations
        totalTasksAssigned       = p.totalTasksAssigned
        totalTasksCompleted      = p.totalTasksCompleted
        aadhaarDocumentUrl       = p.aadhaarDocumentUrl
        notes                    = p.notes
    }
}

// MARK: - MaintenanceProfileService

struct MaintenanceProfileService {

    static func fetchAllMaintenanceProfiles() async throws -> [MaintenanceProfile] {
        try await supabase
            .from("maintenance_profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchMaintenanceProfile(staffMemberId: UUID) async throws -> MaintenanceProfile? {
        let rows: [MaintenanceProfile] = try await supabase
            .from("maintenance_profiles")
            .select()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func addMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        try await supabase
            .from("maintenance_profiles")
            .insert(MaintenanceProfileInsertPayload(from: profile))
            .execute()
    }

    static func updateMaintenanceProfile(_ profile: MaintenanceProfile) async throws {
        try await supabase
            .from("maintenance_profiles")
            .update(MaintenanceProfileUpdatePayload(from: profile))
            .eq("id", value: profile.id.uuidString)
            .execute()
    }

    static func deleteMaintenanceProfile(staffMemberId: UUID) async throws {
        try await supabase
            .from("maintenance_profiles")
            .delete()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .execute()
    }
}

import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - DriverProfileInsertPayload
// Excludes: id, created_at, updated_at

struct DriverProfileInsertPayload: Encodable {
    let staffMemberId: String
    let licenseNumber: String
    let licenseExpiry: String
    let licenseClass: String
    let licenseIssuingState: String
    let licenseDocumentUrl: String?
    let aadhaarDocumentUrl: String?
    let totalTripsCompleted: Int
    let totalDistanceKm: Double
    let averageRating: Double?
    let currentVehicleId: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case staffMemberId       = "staff_member_id"
        case licenseNumber       = "license_number"
        case licenseExpiry       = "license_expiry"
        case licenseClass        = "license_class"
        case licenseIssuingState = "license_issuing_state"
        case licenseDocumentUrl  = "license_document_url"
        case aadhaarDocumentUrl  = "aadhaar_document_url"
        case totalTripsCompleted = "total_trips_completed"
        case totalDistanceKm     = "total_distance_km"
        case averageRating       = "average_rating"
        case currentVehicleId    = "current_vehicle_id"
        case notes
    }

    init(from p: DriverProfile) {
        staffMemberId       = p.staffMemberId.uuidString
        licenseNumber       = p.licenseNumber
        licenseExpiry       = iso.string(from: p.licenseExpiry)
        licenseClass        = p.licenseClass
        licenseIssuingState = p.licenseIssuingState
        licenseDocumentUrl  = p.licenseDocumentUrl
        aadhaarDocumentUrl  = p.aadhaarDocumentUrl
        totalTripsCompleted = p.totalTripsCompleted
        totalDistanceKm     = p.totalDistanceKm
        averageRating       = p.averageRating
        currentVehicleId    = p.currentVehicleId   // already String?
        notes               = p.notes
    }
}

// MARK: - DriverProfileUpdatePayload
// Excludes: id, staff_member_id, created_at, updated_at

struct DriverProfileUpdatePayload: Encodable {
    let licenseNumber: String
    let licenseExpiry: String
    let licenseClass: String
    let licenseIssuingState: String
    let licenseDocumentUrl: String?
    let aadhaarDocumentUrl: String?
    let totalTripsCompleted: Int
    let totalDistanceKm: Double
    let averageRating: Double?
    let currentVehicleId: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case licenseNumber       = "license_number"
        case licenseExpiry       = "license_expiry"
        case licenseClass        = "license_class"
        case licenseIssuingState = "license_issuing_state"
        case licenseDocumentUrl  = "license_document_url"
        case aadhaarDocumentUrl  = "aadhaar_document_url"
        case totalTripsCompleted = "total_trips_completed"
        case totalDistanceKm     = "total_distance_km"
        case averageRating       = "average_rating"
        case currentVehicleId    = "current_vehicle_id"
        case notes
    }

    init(from p: DriverProfile) {
        licenseNumber       = p.licenseNumber
        licenseExpiry       = iso.string(from: p.licenseExpiry)
        licenseClass        = p.licenseClass
        licenseIssuingState = p.licenseIssuingState
        licenseDocumentUrl  = p.licenseDocumentUrl
        aadhaarDocumentUrl  = p.aadhaarDocumentUrl
        totalTripsCompleted = p.totalTripsCompleted
        totalDistanceKm     = p.totalDistanceKm
        averageRating       = p.averageRating
        currentVehicleId    = p.currentVehicleId
        notes               = p.notes
    }
}

// MARK: - DriverProfileService

struct DriverProfileService {

    static func fetchAllDriverProfiles() async throws -> [DriverProfile] {
        try await supabase
            .from("driver_profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchDriverProfile(staffMemberId: UUID) async throws -> DriverProfile? {
        let rows: [DriverProfile] = try await supabase
            .from("driver_profiles")
            .select()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func addDriverProfile(_ profile: DriverProfile) async throws {
        try await supabase
            .from("driver_profiles")
            .insert(DriverProfileInsertPayload(from: profile))
            .execute()
    }

    static func updateDriverProfile(_ profile: DriverProfile) async throws {
        try await supabase
            .from("driver_profiles")
            .update(DriverProfileUpdatePayload(from: profile))
            .eq("id", value: profile.id.uuidString)
            .execute()
    }

    static func deleteDriverProfile(staffMemberId: UUID) async throws {
        try await supabase
            .from("driver_profiles")
            .delete()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .execute()
    }
}

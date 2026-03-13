import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - DriverProfilePayload

struct DriverProfilePayload: Encodable {
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

    init(from profile: DriverProfile) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.staffMemberId       = profile.staffMemberId.uuidString
        self.licenseNumber       = profile.licenseNumber
        self.licenseExpiry       = fmt.string(from: profile.licenseExpiry)
        self.licenseClass        = profile.licenseClass
        self.licenseIssuingState = profile.licenseIssuingState
        self.licenseDocumentUrl  = profile.licenseDocumentUrl
        self.aadhaarDocumentUrl  = profile.aadhaarDocumentUrl
        self.totalTripsCompleted = profile.totalTripsCompleted
        self.totalDistanceKm     = profile.totalDistanceKm
        self.averageRating       = profile.averageRating
        self.currentVehicleId    = profile.currentVehicleId?.uuidString
        self.notes               = profile.notes
    }
}

// MARK: - DriverProfileService

struct DriverProfileService {

    static func fetchAllDriverProfiles() async throws -> [DriverProfile] {
        return try await supabase
            .from("driver_profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchDriverProfile(staffMemberId: UUID) async throws -> DriverProfile {
        return try await supabase
            .from("driver_profiles")
            .select()
            .eq("staff_member_id", value: staffMemberId.uuidString)
            .single()
            .execute()
            .value
    }

    static func addDriverProfile(_ profile: DriverProfile) async throws {
        let payload = DriverProfilePayload(from: profile)
        try await supabase
            .from("driver_profiles")
            .insert(payload)
            .execute()
    }

    static func updateDriverProfile(_ profile: DriverProfile) async throws {
        let payload = DriverProfilePayload(from: profile)
        try await supabase
            .from("driver_profiles")
            .update(payload)
            .eq("id", value: profile.id.uuidString)
            .execute()
    }

    static func deleteDriverProfile(id: UUID) async throws {
        try await supabase
            .from("driver_profiles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

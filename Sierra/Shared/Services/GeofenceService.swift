import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - GeofencePayload

struct GeofencePayload: Encodable {
    let name: String
    let description: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
    let isActive: Bool
    let createdByAdminId: String
    let alertOnEntry: Bool
    let alertOnExit: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case latitude
        case longitude
        case radiusMeters     = "radius_meters"
        case isActive         = "is_active"
        case createdByAdminId = "created_by_admin_id"
        case alertOnEntry     = "alert_on_entry"
        case alertOnExit      = "alert_on_exit"
    }

    init(from geofence: Geofence) {
        self.name             = geofence.name
        self.description      = geofence.description
        self.latitude         = geofence.latitude
        self.longitude        = geofence.longitude
        self.radiusMeters     = geofence.radiusMeters
        self.isActive         = geofence.isActive
        self.createdByAdminId = geofence.createdByAdminId.uuidString
        self.alertOnEntry     = geofence.alertOnEntry
        self.alertOnExit      = geofence.alertOnExit
    }
}

// MARK: - GeofenceService

struct GeofenceService {

    static func fetchAllGeofences() async throws -> [Geofence] {
        return try await supabase
            .from("geofences")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func fetchActiveGeofences() async throws -> [Geofence] {
        return try await supabase
            .from("geofences")
            .select()
            .eq("is_active", value: true)
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func addGeofence(_ geofence: Geofence) async throws {
        let payload = GeofencePayload(from: geofence)
        try await supabase
            .from("geofences")
            .insert(payload)
            .execute()
    }

    static func updateGeofence(_ geofence: Geofence) async throws {
        let payload = GeofencePayload(from: geofence)
        try await supabase
            .from("geofences")
            .update(payload)
            .eq("id", value: geofence.id.uuidString)
            .execute()
    }

    static func deleteGeofence(id: UUID) async throws {
        try await supabase
            .from("geofences")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

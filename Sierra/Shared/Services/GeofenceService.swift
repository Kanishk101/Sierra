import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - GeofenceInsertPayload
// Excludes: id, created_at, updated_at

struct GeofenceInsertPayload: Encodable {
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
        case name, description, latitude, longitude
        case radiusMeters     = "radius_meters"
        case isActive         = "is_active"
        case createdByAdminId = "created_by_admin_id"
        case alertOnEntry     = "alert_on_entry"
        case alertOnExit      = "alert_on_exit"
    }

    init(from g: Geofence) {
        name             = g.name
        description      = g.description
        latitude         = g.latitude
        longitude        = g.longitude
        radiusMeters     = g.radiusMeters
        isActive         = g.isActive
        createdByAdminId = g.createdByAdminId.uuidString
        alertOnEntry     = g.alertOnEntry
        alertOnExit      = g.alertOnExit
    }
}

// MARK: - GeofenceService

struct GeofenceService {

    static func fetchAllGeofences() async throws -> [Geofence] {
        try await supabase
            .from("geofences")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func fetchActiveGeofences() async throws -> [Geofence] {
        try await supabase
            .from("geofences")
            .select()
            .eq("is_active", value: true)
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func addGeofence(_ geofence: Geofence) async throws {
        try await supabase
            .from("geofences")
            .insert(GeofenceInsertPayload(from: geofence))
            .execute()
    }

    static func updateGeofence(_ geofence: Geofence) async throws {
        try await supabase
            .from("geofences")
            .update(GeofenceInsertPayload(from: geofence))
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

    static func toggleGeofence(id: UUID, isActive: Bool) async throws {
        struct Payload: Encodable { let is_active: Bool }
        try await supabase
            .from("geofences")
            .update(Payload(is_active: isActive))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Create (with geofence_type)

    static func createGeofence(
        name: String,
        description: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        geofenceType: GeofenceType,
        alertOnEntry: Bool,
        alertOnExit: Bool,
        createdByAdminId: UUID
    ) async throws {
        struct CreatePayload: Encodable {
            let name: String
            let description: String
            let latitude: Double
            let longitude: Double
            let radius_meters: Double
            let geofence_type: String
            let is_active: Bool
            let alert_on_entry: Bool
            let alert_on_exit: Bool
            let created_by_admin_id: String
        }

        try await supabase
            .from("geofences")
            .insert(CreatePayload(
                name: name,
                description: description,
                latitude: latitude,
                longitude: longitude,
                radius_meters: radiusMeters,
                geofence_type: geofenceType.rawValue,
                is_active: true,
                alert_on_entry: alertOnEntry,
                alert_on_exit: alertOnExit,
                created_by_admin_id: createdByAdminId.uuidString
            ))
            .execute()
    }
}

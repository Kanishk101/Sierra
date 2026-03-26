import Foundation
import Supabase
import CoreLocation

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - GeofenceInsertPayload
// Excludes: id, created_at, updated_at

struct GeofenceInsertPayload: Encodable {
    let name: String
    let description: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
    let geofenceType: String
    let isActive: Bool
    let createdByAdminId: String
    let alertOnEntry: Bool
    let alertOnExit: Bool

    enum CodingKeys: String, CodingKey {
        case name, description, latitude, longitude
        case radiusMeters     = "radius_meters"
        case geofenceType     = "geofence_type"
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
        geofenceType     = g.geofenceType.rawValue
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

    static func addGeofence(_ geofence: Geofence) async throws -> Geofence {
        let normalized = normalizedGeofence(geofence)

        if let duplicate = try await findDuplicate(for: normalized) {
            return try await updateExistingGeofence(duplicate, with: normalized)
        }

        return try await supabase
            .from("geofences")
            .insert(GeofenceInsertPayload(from: normalized))
            .select()
            .single()
            .execute()
            .value
    }

    static func updateGeofence(_ geofence: Geofence) async throws -> Geofence {
        let normalized = normalizedGeofence(geofence)
        return try await supabase
            .from("geofences")
            .update(GeofenceInsertPayload(from: normalized))
            .eq("id", value: normalized.id.uuidString)
            .select()
            .single()
            .execute()
            .value
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
    ) async throws -> Geofence {
        let candidate = Geofence(
            id: UUID(),
            name: name,
            description: description,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            isActive: true,
            createdByAdminId: createdByAdminId,
            alertOnEntry: alertOnEntry,
            alertOnExit: alertOnExit,
            geofenceType: geofenceType,
            createdAt: Date(),
            updatedAt: Date()
        )

        return try await addGeofence(candidate)
    }

    // MARK: - Backend Deduplication / Normalization

    private static func normalizedGeofence(_ geofence: Geofence) -> Geofence {
        var normalized = geofence
        normalized.latitude = GeofenceScopeService.normalizedLatitude(geofence.latitude)
        normalized.longitude = GeofenceScopeService.normalizedLongitude(geofence.longitude)
        normalized.radiusMeters = GeofenceScopeService.normalizedRadiusMeters(geofence.radiusMeters)
        return normalized
    }

    private static func findDuplicate(for candidate: Geofence) async throws -> Geofence? {
        let nearby: [Geofence] = try await supabase
            .from("geofences")
            .select()
            .eq("created_by_admin_id", value: candidate.createdByAdminId.uuidString)
            .execute()
            .value

        let candidateTripToken = GeofenceScopeService.tripToken(in: candidate.description)
        let candidateCenter = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)

        let matching = nearby
            .filter { existing in
                let existingCenter = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                let distance = existingCenter.distance(from: candidateCenter)
                guard distance <= 35 else { return false }

                let sameTrip =
                    candidateTripToken != nil &&
                    candidateTripToken == GeofenceScopeService.tripToken(in: existing.description)

                let similarRadius = abs(existing.radiusMeters - candidate.radiusMeters) <= 25
                return sameTrip || similarRadius
            }
            .sorted { $0.updatedAt > $1.updatedAt }

        return matching.first
    }

    private static func updateExistingGeofence(_ existing: Geofence, with candidate: Geofence) async throws -> Geofence {
        var merged = existing
        merged.name = candidate.name
        merged.description = candidate.description
        merged.latitude = candidate.latitude
        merged.longitude = candidate.longitude
        merged.radiusMeters = candidate.radiusMeters
        merged.isActive = candidate.isActive
        merged.alertOnEntry = candidate.alertOnEntry
        merged.alertOnExit = candidate.alertOnExit
        merged.geofenceType = candidate.geofenceType

        return try await supabase
            .from("geofences")
            .update(GeofenceInsertPayload(from: merged))
            .eq("id", value: merged.id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }
}

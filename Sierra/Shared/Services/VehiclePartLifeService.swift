import Foundation
import Supabase
import PostgREST

struct VehiclePartLifeService {

    struct ProcessTripResponse: Decodable {
        let tripId: UUID
        let vehicleId: UUID
        let distanceKmApplied: Double
        let serviceTaskCreated: Bool
        let serviceTaskId: UUID?
        let profile: VehiclePartLife

        enum CodingKeys: String, CodingKey {
            case tripId            = "trip_id"
            case vehicleId         = "vehicle_id"
            case distanceKmApplied = "distance_km_applied"
            case serviceTaskCreated = "service_task_created"
            case serviceTaskId     = "service_task_id"
            case profile
        }
    }

    static func fetchAllProfiles(limit: Int = 1000) async throws -> [VehiclePartLife] {
        try await supabase
            .from("vehicle_part_life_profiles")
            .select()
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchProfile(vehicleId: UUID) async throws -> VehiclePartLife? {
        let rows: [VehiclePartLife] = try await supabase
            .from("vehicle_part_life_profiles")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func processTripCompletion(tripId: UUID, fallbackDistanceKm: Double?) async throws -> ProcessTripResponse {
        struct Payload: Encodable {
            let trip_id: String
            let fallback_distance_km: Double?
        }

        return try await SupabaseManager.invokeEdgeWithSessionRecovery(
            "process-trip-parts-life",
            body: Payload(
                trip_id: tripId.uuidString.lowercased(),
                fallback_distance_km: fallbackDistanceKm
            )
        )
    }
}

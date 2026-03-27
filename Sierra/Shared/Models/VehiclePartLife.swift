import Foundation

// MARK: - Vehicle Part Life Profile
// Maps to table: vehicle_part_life_profiles

struct VehiclePartLife: Identifiable, Codable, Hashable {
    let id: UUID
    let vehicleId: UUID
    var serviceIntervalKm: Double
    var remainingKm: Double
    var totalConsumedKm: Double
    var depletionThresholdKm: Double
    var serviceCycleCount: Int
    var lastServiceTaskId: UUID?
    var lastProcessedTripId: UUID?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId            = "vehicle_id"
        case serviceIntervalKm    = "service_interval_km"
        case remainingKm          = "remaining_km"
        case totalConsumedKm      = "total_consumed_km"
        case depletionThresholdKm = "depletion_threshold_km"
        case serviceCycleCount    = "service_cycle_count"
        case lastServiceTaskId    = "last_service_task_id"
        case lastProcessedTripId  = "last_processed_trip_id"
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
    }

    var lifePercent: Double {
        guard serviceIntervalKm > 0 else { return 0 }
        return max(0, min(100, (remainingKm / serviceIntervalKm) * 100))
    }

    var isServiceDue: Bool {
        remainingKm <= depletionThresholdKm
    }
}

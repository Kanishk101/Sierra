import Foundation

// MARK: - VehicleLocationHistory
// Maps to table: vehicle_location_history

struct VehicleLocationHistory: Identifiable, Codable, Equatable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var vehicleId: UUID                   // vehicle_id (FK → vehicles.id)
    var tripId: UUID?                     // trip_id (FK → trips.id)
    var driverId: UUID?                   // driver_id (FK → staff_members.id)

    // MARK: Location
    var latitude: Double                  // latitude
    var longitude: Double                 // longitude
    var speedKmh: Double?                 // speed_kmh

    // MARK: Timestamps
    var recordedAt: Date                  // recorded_at
    var createdAt: Date                   // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId   = "vehicle_id"
        case tripId      = "trip_id"
        case driverId    = "driver_id"
        case latitude
        case longitude
        case speedKmh    = "speed_kmh"
        case recordedAt  = "recorded_at"
        case createdAt   = "created_at"
    }
}

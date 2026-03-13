import Foundation

// MARK: - Fuel Type
// Maps to PostgreSQL enum: fuel_type

enum FuelType: String, Codable, CaseIterable, CustomStringConvertible {
    case diesel   = "Diesel"
    case petrol   = "Petrol"
    case electric = "Electric"
    case cng      = "CNG"
    case hybrid   = "Hybrid"

    var description: String { rawValue }
}

// VehicleStatus is defined in Shared/Theme/VehicleStatus.swift (includes SierraStatus conformance).


// MARK: - Vehicle
// Maps to table: vehicles
// assignedDriverId stored as TEXT in Supabase (FK → staff_members.id)

struct Vehicle: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Core identity
    var name: String
    var manufacturer: String
    var model: String
    var year: Int
    var vin: String
    var licensePlate: String
    var color: String

    // MARK: Specs
    var fuelType: FuelType
    var seatingCapacity: Int

    // MARK: Status & assignment
    var status: VehicleStatus
    var assignedDriverId: String?         // FK as TEXT per schema v2

    // MARK: Location (live GPS)
    var currentLatitude: Double?
    var currentLongitude: Double?

    // MARK: Metrics
    var odometer: Double
    var totalTrips: Int
    var totalDistanceKm: Double

    // MARK: Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name, manufacturer, model, year, vin, color
        case licensePlate       = "license_plate"
        case fuelType           = "fuel_type"
        case seatingCapacity    = "seating_capacity"
        case status
        case assignedDriverId   = "assigned_driver_id"
        case currentLatitude    = "current_latitude"
        case currentLongitude   = "current_longitude"
        case odometer
        case totalTrips         = "total_trips"
        case totalDistanceKm    = "total_distance_km"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }

    // MARK: - Convenience

    var assignedDriverUUID: UUID? { assignedDriverId.flatMap(UUID.init) }

    // MARK: - Mock Data

    static let mockData: [Vehicle] = {
        let now = Date()
        return [
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
                name: "Hauler Alpha",
                manufacturer: "Volvo",
                model: "FH16",
                year: 2024,
                vin: "YV2A4C2A8RB123456",
                licensePlate: "FL-1024",
                color: "White",
                fuelType: .diesel,
                seatingCapacity: 3,
                status: .active,
                assignedDriverId: "D0000000-0000-0000-0000-000000000001",
                currentLatitude: nil,
                currentLongitude: nil,
                odometer: 87500.0,
                totalTrips: 245,
                totalDistanceKm: 78200.0,
                createdAt: now.addingTimeInterval(-86400 * 400),
                updatedAt: now.addingTimeInterval(-86400 * 1)
            ),
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
                name: "City Runner",
                manufacturer: "Mercedes-Benz",
                model: "Sprinter",
                year: 2023,
                vin: "WDB9066331S987654",
                licensePlate: "FL-2048",
                color: "Silver",
                fuelType: .diesel,
                seatingCapacity: 2,
                status: .active,
                assignedDriverId: nil,
                currentLatitude: nil,
                currentLongitude: nil,
                odometer: 52300.0,
                totalTrips: 156,
                totalDistanceKm: 43800.0,
                createdAt: now.addingTimeInterval(-86400 * 550),
                updatedAt: now.addingTimeInterval(-86400 * 2)
            ),
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
                name: "Cargo One",
                manufacturer: "MAN",
                model: "TGX",
                year: 2022,
                vin: "WMAN08ZZZ3Y112233",
                licensePlate: "FL-3072",
                color: "Blue",
                fuelType: .diesel,
                seatingCapacity: 3,
                status: .inMaintenance,
                assignedDriverId: nil,
                currentLatitude: nil,
                currentLongitude: nil,
                odometer: 118400.0,
                totalTrips: 298,
                totalDistanceKm: 94500.0,
                createdAt: now.addingTimeInterval(-86400 * 900),
                updatedAt: now.addingTimeInterval(-86400 * 3)
            ),
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!,
                name: "Express Van",
                manufacturer: "Ford",
                model: "Transit",
                year: 2025,
                vin: "1FTBW2CM5JKA44556",
                licensePlate: "FL-4096",
                color: "Red",
                fuelType: .petrol,
                seatingCapacity: 5,
                status: .idle,
                assignedDriverId: nil,
                currentLatitude: nil,
                currentLongitude: nil,
                odometer: 15200.0,
                totalTrips: 42,
                totalDistanceKm: 12800.0,
                createdAt: now.addingTimeInterval(-86400 * 120),
                updatedAt: now.addingTimeInterval(-86400 * 4)
            ),
            Vehicle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!,
                name: "Green Mile",
                manufacturer: "BYD",
                model: "T3",
                year: 2025,
                vin: "LGXCE4EB2P0667788",
                licensePlate: "FL-5120",
                color: "Green",
                fuelType: .electric,
                seatingCapacity: 2,
                status: .idle,
                assignedDriverId: nil,
                currentLatitude: nil,
                currentLongitude: nil,
                odometer: 22100.0,
                totalTrips: 67,
                totalDistanceKm: 18900.0,
                createdAt: now.addingTimeInterval(-86400 * 90),
                updatedAt: now.addingTimeInterval(-86400 * 5)
            ),
        ]
    }()

    static let samples: [Vehicle] = mockData
}

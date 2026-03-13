import Foundation
import Supabase

// MARK: - Shared Supabase Client

private let supabase = SupabaseManager.shared.client

// MARK: - ISO8601 Date Formatter (for payload encoding)

private let iso8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - VehicleInsertPayload

struct VehicleInsertPayload: Encodable {
    let id: String
    let name: String
    let manufacturer: String
    let model: String
    let year: Int
    let vin: String
    let licensePlate: String
    let color: String
    let fuelType: String
    let seatingCapacity: Int
    let status: String
    let assignedDriverId: String?
    let currentLatitude: Double?
    let currentLongitude: Double?
    let odometer: Double
    let totalTrips: Int
    let totalDistanceKm: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case manufacturer
        case model
        case year
        case vin
        case licensePlate     = "license_plate"
        case color
        case fuelType         = "fuel_type"
        case seatingCapacity  = "seating_capacity"
        case status
        case assignedDriverId = "assigned_driver_id"
        case currentLatitude  = "current_latitude"
        case currentLongitude = "current_longitude"
        case odometer
        case totalTrips       = "total_trips"
        case totalDistanceKm  = "total_distance_km"
    }

    init(from vehicle: Vehicle) {
        self.id               = vehicle.id.uuidString
        self.name             = vehicle.name
        self.manufacturer     = vehicle.manufacturer
        self.model            = vehicle.model
        self.year             = vehicle.year
        self.vin              = vehicle.vin
        self.licensePlate     = vehicle.licensePlate
        self.color            = vehicle.color
        self.fuelType         = vehicle.fuelType.rawValue
        self.seatingCapacity  = vehicle.seatingCapacity
        self.status           = vehicle.status.rawValue
        self.assignedDriverId = vehicle.assignedDriverId?.uuidString
        self.currentLatitude  = vehicle.currentLatitude
        self.currentLongitude = vehicle.currentLongitude
        self.odometer         = vehicle.odometer
        self.totalTrips       = vehicle.totalTrips
        self.totalDistanceKm  = vehicle.totalDistanceKm
    }
}

// MARK: - VehicleUpdatePayload

struct VehicleUpdatePayload: Encodable {
    let name: String
    let manufacturer: String
    let model: String
    let year: Int
    let vin: String
    let licensePlate: String
    let color: String
    let fuelType: String
    let seatingCapacity: Int
    let status: String
    let assignedDriverId: String?
    let currentLatitude: Double?
    let currentLongitude: Double?
    let odometer: Double
    let totalTrips: Int
    let totalDistanceKm: Double

    enum CodingKeys: String, CodingKey {
        case name
        case manufacturer
        case model
        case year
        case vin
        case licensePlate     = "license_plate"
        case color
        case fuelType         = "fuel_type"
        case seatingCapacity  = "seating_capacity"
        case status
        case assignedDriverId = "assigned_driver_id"
        case currentLatitude  = "current_latitude"
        case currentLongitude = "current_longitude"
        case odometer
        case totalTrips       = "total_trips"
        case totalDistanceKm  = "total_distance_km"
    }

    init(from vehicle: Vehicle) {
        self.name             = vehicle.name
        self.manufacturer     = vehicle.manufacturer
        self.model            = vehicle.model
        self.year             = vehicle.year
        self.vin              = vehicle.vin
        self.licensePlate     = vehicle.licensePlate
        self.color            = vehicle.color
        self.fuelType         = vehicle.fuelType.rawValue
        self.seatingCapacity  = vehicle.seatingCapacity
        self.status           = vehicle.status.rawValue
        self.assignedDriverId = vehicle.assignedDriverId?.uuidString
        self.currentLatitude  = vehicle.currentLatitude
        self.currentLongitude = vehicle.currentLongitude
        self.odometer         = vehicle.odometer
        self.totalTrips       = vehicle.totalTrips
        self.totalDistanceKm  = vehicle.totalDistanceKm
    }
}

// MARK: - VehicleService

struct VehicleService {

    // MARK: - Fetch All

    static func fetchAllVehicles() async throws -> [Vehicle] {
        return try await supabase
            .from("vehicles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Fetch by ID

    static func fetchVehicle(id: UUID) async throws -> Vehicle {
        return try await supabase
            .from("vehicles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    // MARK: - Fetch by Status

    static func fetchVehicles(status: VehicleStatus) async throws -> [Vehicle] {
        return try await supabase
            .from("vehicles")
            .select()
            .eq("status", value: status.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: - Insert

    static func addVehicle(_ vehicle: Vehicle) async throws {
        let payload = VehicleInsertPayload(from: vehicle)
        try await supabase
            .from("vehicles")
            .insert(payload)
            .execute()
    }

    // MARK: - Update

    static func updateVehicle(_ vehicle: Vehicle) async throws {
        let payload = VehicleUpdatePayload(from: vehicle)
        try await supabase
            .from("vehicles")
            .update(payload)
            .eq("id", value: vehicle.id.uuidString)
            .execute()
    }

    // MARK: - Delete

    static func deleteVehicle(id: UUID) async throws {
        try await supabase
            .from("vehicles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

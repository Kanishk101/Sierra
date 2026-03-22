import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - VehicleInsertPayload
// Includes id so the client-generated UUID is used by the DB.
// If id is omitted the DB auto-generates a different UUID and any
// subsequent trip/assignment using store.vehicle(for:) will get a
// trips_vehicle_id_fkey violation.
// Excludes: created_at, updated_at (auto-managed by DB)

struct VehicleInsertPayload: Encodable {
    let id: String               // must be included — see note above
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
        case id, name, manufacturer, model, year, vin, color
        case licensePlate     = "license_plate"
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

    init(from v: Vehicle) {
        id               = v.id.uuidString
        name             = v.name
        manufacturer     = v.manufacturer
        model            = v.model
        year             = v.year
        vin              = v.vin
        licensePlate     = v.licensePlate
        color            = v.color
        fuelType         = v.fuelType.rawValue
        seatingCapacity  = v.seatingCapacity
        status           = v.status.rawValue
        assignedDriverId = v.assignedDriverId
        currentLatitude  = v.currentLatitude
        currentLongitude = v.currentLongitude
        odometer         = v.odometer
        totalTrips       = v.totalTrips
        totalDistanceKm  = v.totalDistanceKm
    }
}

// MARK: - VehicleUpdatePayload (same fields as insert, id excluded from update body)

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
        case name, manufacturer, model, year, vin, color
        case licensePlate     = "license_plate"
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

    init(from v: Vehicle) {
        name             = v.name
        manufacturer     = v.manufacturer
        model            = v.model
        year             = v.year
        vin              = v.vin
        licensePlate     = v.licensePlate
        color            = v.color
        fuelType         = v.fuelType.rawValue
        seatingCapacity  = v.seatingCapacity
        status           = v.status.rawValue
        assignedDriverId = v.assignedDriverId
        currentLatitude  = v.currentLatitude
        currentLongitude = v.currentLongitude
        odometer         = v.odometer
        totalTrips       = v.totalTrips
        totalDistanceKm  = v.totalDistanceKm
    }
}

// MARK: - VehicleService

struct VehicleService {

    // MARK: Fetch

    static func fetchAllVehicles() async throws -> [Vehicle] {
        try await supabase
            .from("vehicles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchVehicle(id: UUID) async throws -> Vehicle? {
        let rows: [Vehicle] = try await supabase
            .from("vehicles")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func fetchVehicles(status: VehicleStatus) async throws -> [Vehicle] {
        try await supabase
            .from("vehicles")
            .select()
            .eq("status", value: status.rawValue)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: Insert

    static func addVehicle(_ vehicle: Vehicle) async throws {
        #if DEBUG
        SierraDebugLogger.banner("VehicleService.addVehicle")
        print("🚗 [VehicleService.addVehicle] Starting INSERT for vehicle:")
        print("🚗   ID          : \(vehicle.id.uuidString)")
        print("🚗   Name        : \(vehicle.name)")
        print("🚗   VIN         : \(vehicle.vin)")
        print("🚗   LicensePlate: \(vehicle.licensePlate)")
        print("🚗   Status      : \(vehicle.status.rawValue)")
        print("🚗   FuelType    : \(vehicle.fuelType.rawValue)")
        await SierraDebugLogger.logSessionState(context: "VehicleService.addVehicle")
        await SierraDebugLogger.logRLSRole(context: "VehicleService.addVehicle")
        let payload = VehicleInsertPayload(from: vehicle)
        SierraDebugLogger.logPayload(label: "VehicleInsertPayload", payload: payload)
        let t = Date()
        #endif

        do {
            try await supabase
                .from("vehicles")
                .insert(VehicleInsertPayload(from: vehicle))
                .execute()
            #if DEBUG
            let ms = Int(Date().timeIntervalSince(t) * 1000)
            print("🚗 [VehicleService.addVehicle] ✅ INSERT succeeded in \(ms)ms")
            #endif
        } catch {
            #if DEBUG
            let ms = Int(Date().timeIntervalSince(t) * 1000)
            print("🚗 [VehicleService.addVehicle] ❌ INSERT FAILED in \(ms)ms")
            SierraDebugLogger.logPostgRESTError(
                context: "VehicleService.addVehicle",
                error: error,
                table: "vehicles",
                operation: "INSERT"
            )
            #endif
            throw error
        }
    }

    // MARK: Update

    static func updateVehicle(_ vehicle: Vehicle) async throws {
        #if DEBUG
        SierraDebugLogger.banner("VehicleService.updateVehicle")
        print("🚗 [VehicleService.updateVehicle] Updating vehicle ID=\(vehicle.id.uuidString)")
        print("🚗   Status: \(vehicle.status.rawValue) | AssignedDriver: \(vehicle.assignedDriverId ?? "nil")")
        await SierraDebugLogger.logSessionState(context: "VehicleService.updateVehicle")
        let payload = VehicleUpdatePayload(from: vehicle)
        SierraDebugLogger.logPayload(label: "VehicleUpdatePayload", payload: payload)
        let t = Date()
        #endif

        do {
            try await supabase
                .from("vehicles")
                .update(VehicleUpdatePayload(from: vehicle))
                .eq("id", value: vehicle.id.uuidString)
                .execute()
            #if DEBUG
            let ms = Int(Date().timeIntervalSince(t) * 1000)
            print("🚗 [VehicleService.updateVehicle] ✅ UPDATE succeeded in \(ms)ms")
            #endif
        } catch {
            #if DEBUG
            let ms = Int(Date().timeIntervalSince(t) * 1000)
            print("🚗 [VehicleService.updateVehicle] ❌ UPDATE FAILED in \(ms)ms")
            SierraDebugLogger.logPostgRESTError(
                context: "VehicleService.updateVehicle",
                error: error,
                table: "vehicles",
                operation: "UPDATE"
            )
            #endif
            throw error
        }
    }

    // MARK: Delete

    static func deleteVehicle(id: UUID) async throws {
        #if DEBUG
        SierraDebugLogger.banner("VehicleService.deleteVehicle")
        print("🚗 [VehicleService.deleteVehicle] Deleting vehicle ID=\(id.uuidString)")
        await SierraDebugLogger.logSessionState(context: "VehicleService.deleteVehicle")
        let t = Date()
        #endif

        do {
            try await supabase
                .from("vehicles")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            #if DEBUG
            let ms = Int(Date().timeIntervalSince(t) * 1000)
            print("🚗 [VehicleService.deleteVehicle] ✅ DELETE succeeded in \(ms)ms")
            #endif
        } catch {
            #if DEBUG
            let ms = Int(Date().timeIntervalSince(t) * 1000)
            print("🚗 [VehicleService.deleteVehicle] ❌ DELETE FAILED in \(ms)ms")
            SierraDebugLogger.logPostgRESTError(
                context: "VehicleService.deleteVehicle",
                error: error,
                table: "vehicles",
                operation: "DELETE"
            )
            #endif
            throw error
        }
    }

    // MARK: Assign Driver

    static func assignDriver(vehicleId: UUID, driverId: UUID?) async throws {
        struct Payload: Encodable {
            let assigned_driver_id: String?
        }
        #if DEBUG
        print("🚗 [VehicleService.assignDriver] vehicleId=\(vehicleId) driverId=\(driverId?.uuidString ?? "nil")")
        await SierraDebugLogger.logSessionState(context: "VehicleService.assignDriver")
        let t = Date()
        #endif

        do {
            try await supabase
                .from("vehicles")
                .update(Payload(assigned_driver_id: driverId?.uuidString))
                .eq("id", value: vehicleId.uuidString)
                .execute()
            #if DEBUG
            print("🚗 [VehicleService.assignDriver] ✅ succeeded in \(Int(Date().timeIntervalSince(t) * 1000))ms")
            #endif
        } catch {
            #if DEBUG
            SierraDebugLogger.logPostgRESTError(context: "VehicleService.assignDriver", error: error, table: "vehicles", operation: "UPDATE")
            #endif
            throw error
        }
    }

    // MARK: Update Location

    static func updateLocation(vehicleId: UUID, latitude: Double, longitude: Double) async throws {
        struct Payload: Encodable {
            let current_latitude: Double
            let current_longitude: Double
        }
        try await supabase
            .from("vehicles")
            .update(Payload(current_latitude: latitude, current_longitude: longitude))
            .eq("id", value: vehicleId.uuidString)
            .execute()
    }
}

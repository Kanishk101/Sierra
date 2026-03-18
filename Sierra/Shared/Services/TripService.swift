import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - TripInsertPayload
// Excludes: id, created_at, updated_at, proof_of_delivery_id,
//           pre_inspection_id, post_inspection_id (set after related records)

struct TripInsertPayload: Encodable {
    let taskId: String
    let driverId: String?
    let vehicleId: String?
    let createdByAdminId: String
    let origin: String
    let destination: String
    let deliveryInstructions: String
    let scheduledDate: String
    let scheduledEndDate: String?
    let actualStartDate: String?
    let actualEndDate: String?
    let startMileage: Double?
    let endMileage: Double?
    let notes: String
    let status: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case taskId               = "task_id"
        case driverId             = "driver_id"
        case vehicleId            = "vehicle_id"
        case createdByAdminId     = "created_by_admin_id"
        case origin, destination
        case deliveryInstructions = "delivery_instructions"
        case scheduledDate        = "scheduled_date"
        case scheduledEndDate     = "scheduled_end_date"
        case actualStartDate      = "actual_start_date"
        case actualEndDate        = "actual_end_date"
        case startMileage         = "start_mileage"
        case endMileage           = "end_mileage"
        case notes, status, priority
    }

    init(from t: Trip) {
        taskId               = t.taskId
        driverId             = t.driverId             // already String?
        vehicleId            = t.vehicleId            // already String?
        createdByAdminId     = t.createdByAdminId     // already String
        origin               = t.origin
        destination          = t.destination
        deliveryInstructions = t.deliveryInstructions
        scheduledDate        = iso.string(from: t.scheduledDate)
        scheduledEndDate     = t.scheduledEndDate.map { iso.string(from: $0) }
        actualStartDate      = t.actualStartDate.map  { iso.string(from: $0) }
        actualEndDate        = t.actualEndDate.map    { iso.string(from: $0) }
        startMileage         = t.startMileage
        endMileage           = t.endMileage
        notes                = t.notes
        status               = t.status.rawValue
        priority             = t.priority.rawValue
    }
}

// MARK: - TripUpdatePayload (same fields as insert)

typealias TripUpdatePayload = TripInsertPayload

// MARK: - TripService

struct TripService {

    // MARK: Fetch

    static func fetchAllTrips() async throws -> [Trip] {
        try await supabase
            .from("trips")
            .select()
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    static func fetchTrip(id: UUID) async throws -> Trip? {
        let rows: [Trip] = try await supabase
            .from("trips")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func fetchTrips(driverId: UUID) async throws -> [Trip] {
        try await supabase
            .from("trips")
            .select()
            .eq("driver_id", value: driverId.uuidString.lowercased())
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    static func fetchTrips(vehicleId: UUID) async throws -> [Trip] {
        try await supabase
            .from("trips")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    static func fetchActiveTrips() async throws -> [Trip] {
        try await supabase
            .from("trips")
            .select()
            .eq("status", value: TripStatus.active.rawValue)
            .order("scheduled_date", ascending: true)
            .execute()
            .value
    }

    // MARK: Insert

    static func addTrip(_ trip: Trip) async throws {
        try await supabase
            .from("trips")
            .insert(TripInsertPayload(from: trip))
            .execute()
    }

    // MARK: Update

    static func updateTrip(_ trip: Trip) async throws {
        try await supabase
            .from("trips")
            .update(TripUpdatePayload(from: trip))
            .eq("id", value: trip.id.uuidString)
            .execute()
    }

    static func updateTripStatus(id: UUID, status: TripStatus) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase
            .from("trips")
            .update(Payload(status: status.rawValue))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Delete

    static func deleteTrip(id: UUID) async throws {
        try await supabase
            .from("trips")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Task ID Helper

    static func newTaskId() -> String { generateTaskId() }

    private static func generateTaskId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let datePart = formatter.string(from: Date())
        let suffix = String(format: "%04d", Int.random(in: 1...9999))
        return "TRP-\(datePart)-\(suffix)"
    }

    // MARK: - Busy Status Helpers

    /// Calls the `check-resource-overlap` Edge Function to detect double-booking.
    static func checkOverlap(
        driverId: UUID,
        vehicleId: UUID,
        start: Date,
        end: Date,
        excludingTripId: UUID? = nil
    ) async throws -> (driverConflict: Bool, vehicleConflict: Bool) {

        struct OverlapRequest: Encodable {
            let driver_id: String
            let vehicle_id: String
            let start: String
            let end: String
            let exclude_trip_id: String?
        }

        struct OverlapResult: Decodable {
            let driverConflict: Bool
            let vehicleConflict: Bool
            enum CodingKeys: String, CodingKey {
                case driverConflict  = "driver_conflict"
                case vehicleConflict = "vehicle_conflict"
            }
        }

        let body = OverlapRequest(
            driver_id:        driverId.uuidString.lowercased(),
            vehicle_id:       vehicleId.uuidString.lowercased(),
            start:            iso.string(from: start),
            end:              iso.string(from: end),
            exclude_trip_id:  excludingTripId?.uuidString.lowercased()
        )
        let bodyData = try JSONEncoder().encode(body)
        let result: OverlapResult = try await supabase.functions.invoke(
            "check-resource-overlap",
            options: .init(body: bodyData)
        )
        return (result.driverConflict, result.vehicleConflict)
    }

    /// Sets driver availability → "Busy" and vehicle status → "Busy" at the DB level.
    static func markResourcesBusy(driverId: UUID, vehicleId: UUID) async throws {
        struct AvailabilityPayload: Encodable { let availability: String }
        struct VehicleStatusPayload: Encodable { let status: String }

        try await supabase
            .from("staff_members")
            .update(AvailabilityPayload(availability: "Busy"))
            .eq("id", value: driverId.uuidString.lowercased())
            .execute()

        try await supabase
            .from("vehicles")
            .update(VehicleStatusPayload(status: "Busy"))
            .eq("id", value: vehicleId.uuidString.lowercased())
            .execute()
    }

    /// Releases resources after trip completion or cancellation:
    /// driver → "Available", vehicle → "Idle", assignedDriverId → nil.
    static func releaseResources(driverId: UUID, vehicleId: UUID) async throws {
        struct AvailabilityPayload: Encodable { let availability: String }
        struct VehicleReleasePayload: Encodable {
            let status: String
            let assignedDriverId: String?
            enum CodingKeys: String, CodingKey {
                case status
                case assignedDriverId = "assigned_driver_id"
            }
        }

        try await supabase
            .from("staff_members")
            .update(AvailabilityPayload(availability: "Available"))
            .eq("id", value: driverId.uuidString.lowercased())
            .execute()

        try await supabase
            .from("vehicles")
            .update(VehicleReleasePayload(status: "Idle", assignedDriverId: nil))
            .eq("id", value: vehicleId.uuidString.lowercased())
            .execute()
    }

    // MARK: - Trip Lifecycle

    /// Sets trip to Active with start date and mileage.
    /// Does NOT update vehicles or staff_members — DB triggers handle that.
    static func startTrip(tripId: UUID, startMileage: Double) async throws {
        struct Payload: Encodable {
            let status: String
            let actual_start_date: String
            let start_mileage: Double
        }
        try await supabase
            .from("trips")
            .update(Payload(
                status: TripStatus.active.rawValue,
                actual_start_date: iso.string(from: Date()),
                start_mileage: startMileage
            ))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    /// Sets trip to Completed with end date and mileage.
    /// Does NOT update vehicles or staff_members — DB triggers handle that.
    static func completeTrip(tripId: UUID, endMileage: Double) async throws {
        struct Payload: Encodable {
            let status: String
            let actual_end_date: String
            let end_mileage: Double
        }
        try await supabase
            .from("trips")
            .update(Payload(
                status: TripStatus.completed.rawValue,
                actual_end_date: iso.string(from: Date()),
                end_mileage: endMileage
            ))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    /// Sets trip to Cancelled. Does NOT update vehicles or staff_members.
    static func cancelTrip(tripId: UUID) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase
            .from("trips")
            .update(Payload(status: TripStatus.cancelled.rawValue))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    // MARK: - Coordinates & Rating

    static func updateTripCoordinates(
        tripId: UUID,
        originLat: Double,
        originLng: Double,
        destLat: Double,
        destLng: Double,
        routePolyline: String
    ) async throws {
        struct Payload: Encodable {
            let origin_latitude: Double
            let origin_longitude: Double
            let destination_latitude: Double
            let destination_longitude: Double
            let route_polyline: String
        }
        try await supabase
            .from("trips")
            .update(Payload(
                origin_latitude: originLat,
                origin_longitude: originLng,
                destination_latitude: destLat,
                destination_longitude: destLng,
                route_polyline: routePolyline
            ))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    static func rateDriver(tripId: UUID, rating: Int, note: String?, ratedById: UUID) async throws {
        struct Payload: Encodable {
            let driver_rating: Int
            let driver_rating_note: String?
            let rated_by_id: String
            let rated_at: String
        }
        try await supabase
            .from("trips")
            .update(Payload(
                driver_rating: rating,
                driver_rating_note: note,
                rated_by_id: ratedById.uuidString,
                rated_at: iso.string(from: Date())
            ))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    // MARK: - Reassign Vehicle

    /// Reassign a trip to a different vehicle (e.g. after pre-trip inspection failure).
    /// DB trigger `trg_trip_started` handles vehicle status transitions automatically.
    static func reassignVehicle(tripId: UUID, newVehicleId: UUID) async throws {
        struct Payload: Encodable { let vehicle_id: String }
        try await supabase
            .from("trips")
            .update(Payload(vehicle_id: newVehicleId.uuidString))
            .eq("id", value: tripId.uuidString)
            .execute()
    }
}

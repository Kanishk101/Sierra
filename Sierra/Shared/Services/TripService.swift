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
            .eq("driver_id", value: driverId.uuidString)
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
}

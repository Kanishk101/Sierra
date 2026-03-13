import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - TripPayload

struct TripPayload: Encodable {
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
    let proofOfDeliveryId: String?
    let preInspectionId: String?
    let postInspectionId: String?

    enum CodingKeys: String, CodingKey {
        case taskId               = "task_id"
        case driverId             = "driver_id"
        case vehicleId            = "vehicle_id"
        case createdByAdminId     = "created_by_admin_id"
        case origin
        case destination
        case deliveryInstructions = "delivery_instructions"
        case scheduledDate        = "scheduled_date"
        case scheduledEndDate     = "scheduled_end_date"
        case actualStartDate      = "actual_start_date"
        case actualEndDate        = "actual_end_date"
        case startMileage         = "start_mileage"
        case endMileage           = "end_mileage"
        case notes
        case status
        case priority
        case proofOfDeliveryId    = "proof_of_delivery_id"
        case preInspectionId      = "pre_inspection_id"
        case postInspectionId     = "post_inspection_id"
    }

    init(from trip: Trip) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.taskId               = trip.taskId
        self.driverId             = trip.driverId?.uuidString
        self.vehicleId            = trip.vehicleId?.uuidString
        self.createdByAdminId     = trip.createdByAdminId.uuidString
        self.origin               = trip.origin
        self.destination          = trip.destination
        self.deliveryInstructions = trip.deliveryInstructions
        self.scheduledDate        = fmt.string(from: trip.scheduledDate)
        self.scheduledEndDate     = trip.scheduledEndDate.map { fmt.string(from: $0) }
        self.actualStartDate      = trip.actualStartDate.map { fmt.string(from: $0) }
        self.actualEndDate        = trip.actualEndDate.map { fmt.string(from: $0) }
        self.startMileage         = trip.startMileage
        self.endMileage           = trip.endMileage
        self.notes                = trip.notes
        self.status               = trip.status.rawValue
        self.priority             = trip.priority.rawValue
        self.proofOfDeliveryId    = trip.proofOfDeliveryId?.uuidString
        self.preInspectionId      = trip.preInspectionId?.uuidString
        self.postInspectionId     = trip.postInspectionId?.uuidString
    }
}

// MARK: - TripService

struct TripService {

    static func fetchAllTrips() async throws -> [Trip] {
        return try await supabase
            .from("trips")
            .select()
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    static func fetchTrips(driverId: UUID) async throws -> [Trip] {
        return try await supabase
            .from("trips")
            .select()
            .eq("driver_id", value: driverId.uuidString)
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    static func fetchTrips(vehicleId: UUID) async throws -> [Trip] {
        return try await supabase
            .from("trips")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("scheduled_date", ascending: false)
            .execute()
            .value
    }

    static func fetchActiveTrips() async throws -> [Trip] {
        return try await supabase
            .from("trips")
            .select()
            .eq("status", value: TripStatus.active.rawValue)
            .order("scheduled_date", ascending: true)
            .execute()
            .value
    }

    static func fetchTrip(taskId: String) async throws -> Trip {
        return try await supabase
            .from("trips")
            .select()
            .eq("task_id", value: taskId)
            .single()
            .execute()
            .value
    }

    static func addTrip(_ trip: Trip) async throws {
        let payload = TripPayload(from: trip)
        try await supabase
            .from("trips")
            .insert(payload)
            .execute()
    }

    static func updateTrip(_ trip: Trip) async throws {
        let payload = TripPayload(from: trip)
        try await supabase
            .from("trips")
            .update(payload)
            .eq("id", value: trip.id.uuidString)
            .execute()
    }

    static func deleteTrip(id: UUID) async throws {
        try await supabase
            .from("trips")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

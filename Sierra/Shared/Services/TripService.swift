import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ISO Formatter

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - TripServiceError

enum TripServiceError: LocalizedError {
    case tripNotFound(UUID)
    case driverMismatch
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .tripNotFound(let id):
            return "No trips row found for id \(id.uuidString.lowercased())"
        case .driverMismatch:
            return "You are not the assigned driver for this trip."
        case .sessionExpired:
            return "Your session expired. Please sign in again and retry."
        }
    }
}

// MARK: - TripInsertPayload
// All TEXT FK UUID columns are lowercased to match auth.uid()::text (always lowercase).
// acceptanceDeadline included so PendingAcceptance trips carry the 24h window from INSERT.

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
    let originLatitude: Double?
    let originLongitude: Double?
    let destinationLatitude: Double?
    let destinationLongitude: Double?
    let routePolyline: String?
    let routeStops: [RouteStop]
    let acceptanceDeadline: String?

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
        case originLatitude       = "origin_latitude"
        case originLongitude      = "origin_longitude"
        case destinationLatitude  = "destination_latitude"
        case destinationLongitude = "destination_longitude"
        case routePolyline        = "route_polyline"
        case routeStops           = "route_stops"
        case acceptanceDeadline   = "acceptance_deadline"
    }

    init(from t: Trip) {
        taskId               = t.taskId
        driverId             = t.driverId?.lowercased()
        vehicleId            = t.vehicleId?.lowercased()
        createdByAdminId     = t.createdByAdminId.lowercased()
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
        originLatitude       = t.originLatitude
        originLongitude      = t.originLongitude
        destinationLatitude  = t.destinationLatitude
        destinationLongitude = t.destinationLongitude
        routePolyline        = t.routePolyline
        routeStops           = t.routeStops ?? []
        acceptanceDeadline   = t.acceptanceDeadline.map { iso.string(from: $0) }
    }
}

// MARK: - TripUpdatePayload

struct TripUpdatePayload: Encodable {
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
    let originLatitude: Double?
    let originLongitude: Double?
    let destinationLatitude: Double?
    let destinationLongitude: Double?
    let routePolyline: String?
    let routeStops: [RouteStop]
    let proofOfDeliveryId: String?
    let preInspectionId: String?
    let postInspectionId: String?
    let acceptedAt: String?
    let acceptanceDeadline: String?
    let rejectedReason: String?
    let driverRating: Int?
    let driverRatingNote: String?
    let ratedById: String?
    let ratedAt: String?

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
        case originLatitude       = "origin_latitude"
        case originLongitude      = "origin_longitude"
        case destinationLatitude  = "destination_latitude"
        case destinationLongitude = "destination_longitude"
        case routePolyline        = "route_polyline"
        case routeStops           = "route_stops"
        case proofOfDeliveryId    = "proof_of_delivery_id"
        case preInspectionId      = "pre_inspection_id"
        case postInspectionId     = "post_inspection_id"
        case acceptedAt           = "accepted_at"
        case acceptanceDeadline   = "acceptance_deadline"
        case rejectedReason       = "rejected_reason"
        case driverRating         = "driver_rating"
        case driverRatingNote     = "driver_rating_note"
        case ratedById            = "rated_by_id"
        case ratedAt              = "rated_at"
    }

    init(from t: Trip) {
        taskId               = t.taskId
        driverId             = t.driverId?.lowercased()
        vehicleId            = t.vehicleId?.lowercased()
        createdByAdminId     = t.createdByAdminId.lowercased()
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
        originLatitude       = t.originLatitude
        originLongitude      = t.originLongitude
        destinationLatitude  = t.destinationLatitude
        destinationLongitude = t.destinationLongitude
        routePolyline        = t.routePolyline
        routeStops           = t.routeStops ?? []
        proofOfDeliveryId    = t.proofOfDeliveryId?.uuidString
        preInspectionId      = t.preInspectionId?.uuidString
        postInspectionId     = t.postInspectionId?.uuidString
        acceptedAt           = t.acceptedAt.map    { iso.string(from: $0) }
        acceptanceDeadline   = t.acceptanceDeadline.map { iso.string(from: $0) }
        rejectedReason       = t.rejectedReason
        driverRating         = t.driverRating
        driverRatingNote     = t.driverRatingNote
        ratedById            = t.ratedById?.uuidString
        ratedAt              = t.ratedAt.map { iso.string(from: $0) }
    }
}

// MARK: - TripService

struct TripService {

    // MARK: Fetch

    static func fetchAllTrips() async throws -> [Trip] {
        try await supabase
            .from("trips")
            .select()
            .order("created_at", ascending: false)
            .limit(500)
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
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value
    }

    static func fetchTrips(vehicleId: UUID) async throws -> [Trip] {
        try await supabase
            .from("trips")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
            .order("created_at", ascending: false)
            .limit(200)
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
        do {
            try await supabase
                .from("trips")
                .insert(TripInsertPayload(from: trip))
                .execute()
        } catch {
            print("[TripService] addTrip failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: Update

    static func updateTrip(_ trip: Trip) async throws {
        do {
            try await supabase
                .from("trips")
                .update(TripUpdatePayload(from: trip))
                .eq("id", value: trip.id.uuidString)
                .execute()
        } catch {
            print("[TripService] updateTrip failed: \(error.localizedDescription)")
            throw error
        }
    }

    static func updateTripStatus(id: UUID, status: TripStatus) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase
            .from("trips")
            .update(Payload(status: status.rawValue))
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Partial update: sets only proof_of_delivery_id (avoids driver write-restriction trigger).
    static func setProofOfDeliveryId(tripId: UUID, podId: UUID) async throws {
        struct Payload: Encodable { let proof_of_delivery_id: String }
        try await supabase
            .from("trips")
            .update(Payload(proof_of_delivery_id: podId.uuidString))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    /// Partial update: sets only pre_ or post_inspection_id.
    static func setInspectionId(tripId: UUID, inspectionId: UUID, type: InspectionType) async throws {
        if type == .preTripInspection {
            struct Payload: Encodable { let pre_inspection_id: String }
            try await supabase
                .from("trips")
                .update(Payload(pre_inspection_id: inspectionId.uuidString))
                .eq("id", value: tripId.uuidString)
                .execute()
        } else {
            struct Payload: Encodable { let post_inspection_id: String }
            try await supabase
                .from("trips")
                .update(Payload(post_inspection_id: inspectionId.uuidString))
                .eq("id", value: tripId.uuidString)
                .execute()
        }
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
        let suffix = String(UUID().uuidString.prefix(8)).uppercased()
        return "TRP-\(datePart)-\(suffix)"
    }

    // MARK: - Dispatch Lifecycle (FM: manual dispatch for legacy Scheduled trips)

    static func dispatchTrip(tripId: UUID) async throws {
        struct Payload: Encodable {
            let status: String
            let acceptance_deadline: String
            let updated_at: String
        }
        let deadline = Date().addingTimeInterval(TripConstants.acceptanceDeadlineSeconds)
        try await supabase
            .from("trips")
            .update(Payload(
                status: TripStatus.pendingAcceptance.rawValue,
                acceptance_deadline: iso.string(from: deadline),
                updated_at: iso.string(from: Date())
            ))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    // MARK: - Accept Lifecycle
    // Driver accepts → DB writes status = 'Scheduled' (PendingAcceptance → Scheduled)

    static func acceptTrip(tripId: UUID, driverId: UUID) async throws {
        struct Payload: Encodable {
            let status: String
            let accepted_at: String
        }
        let rows: [Trip] = try await supabase
            .from("trips")
            .update(Payload(
                status: TripStatus.scheduled.rawValue,
                accepted_at: iso.string(from: Date())
            ))
            .eq("id",        value: tripId.uuidString)
            .eq("driver_id", value: driverId.uuidString.lowercased())
            .select()
            .execute()
            .value
        guard !rows.isEmpty else { throw TripServiceError.driverMismatch }
    }

    // MARK: - Resource Overlap Check

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
            driver_id:       driverId.uuidString.lowercased(),
            vehicle_id:      vehicleId.uuidString.lowercased(),
            start:           iso.string(from: start),
            end:             iso.string(from: end),
            exclude_trip_id: excludingTripId?.uuidString.lowercased()
        )

        do {
            let result: OverlapResult = try await SupabaseManager
                .invokeEdgeWithSessionRecovery("check-resource-overlap", body: body)
            return (result.driverConflict, result.vehicleConflict)
        } catch {
            if SupabaseManager.isUnauthorizedEdgeError(error) || SupabaseManager.isSessionRecoveryError(error) {
                throw TripServiceError.sessionExpired
            }
            print("[TripService] checkOverlap failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Busy / Release Helpers

    static func markResourcesBusy(driverId: UUID, vehicleId: UUID) async throws {
        struct AvailabilityPayload: Encodable { let availability: String }
        struct VehicleStatusPayload: Encodable { let status: String }
        try await supabase.from("staff_members")
            .update(AvailabilityPayload(availability: "Busy"))
            .eq("id", value: driverId.uuidString.lowercased()).execute()
        try await supabase.from("vehicles")
            .update(VehicleStatusPayload(status: "Busy"))
            .eq("id", value: vehicleId.uuidString.lowercased()).execute()
    }

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
        try await supabase.from("staff_members")
            .update(AvailabilityPayload(availability: "Available"))
            .eq("id", value: driverId.uuidString.lowercased()).execute()
        try await supabase.from("vehicles")
            .update(VehicleReleasePayload(status: "Idle", assignedDriverId: nil))
            .eq("id", value: vehicleId.uuidString.lowercased()).execute()
    }

    // MARK: - Trip Lifecycle

    static func startTrip(tripId: UUID, startMileage: Double) async throws {
        struct Payload: Encodable {
            let status: String
            let actual_start_date: String
            let start_mileage: Double
        }
        try await supabase.from("trips")
            .update(Payload(
                status: TripStatus.active.rawValue,
                actual_start_date: iso.string(from: Date()),
                start_mileage: startMileage
            ))
            .eq("id", value: tripId.uuidString).execute()
    }

    static func markTripActive(tripId: UUID, startMileage: Double) async throws {
        struct Payload: Encodable {
            let status: String
            let actual_start_date: String
            let start_mileage: Double
        }
        try await supabase.from("trips")
            .update(Payload(
                status: TripStatus.active.rawValue,
                actual_start_date: iso.string(from: Date()),
                start_mileage: startMileage
            ))
            .eq("id", value: tripId.uuidString).execute()
    }

    static func completeTrip(tripId: UUID, endMileage: Double? = nil) async throws {
        struct Payload: Encodable {
            let status: String
            let actual_end_date: String
            let end_mileage: Double?
        }
        try await supabase.from("trips")
            .update(Payload(
                status: TripStatus.completed.rawValue,
                actual_end_date: iso.string(from: Date()),
                end_mileage: endMileage
            ))
            .eq("id", value: tripId.uuidString).execute()
    }

    static func updateCompletedTripDetails(tripId: UUID, endMileage: Double) async throws {
        struct Payload: Encodable {
            let actual_end_date: String
            let end_mileage: Double
        }
        try await supabase.from("trips")
            .update(Payload(
                actual_end_date: iso.string(from: Date()),
                end_mileage: endMileage
            ))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    static func recordEndOdometer(tripId: UUID, endMileage: Double) async throws {
        struct Payload: Encodable {
            let end_mileage: Double
            let updated_at: String
        }
        try await supabase.from("trips")
            .update(Payload(
                end_mileage: endMileage,
                updated_at: iso.string(from: Date())
            ))
            .eq("id", value: tripId.uuidString)
            .execute()
    }

    static func cancelTrip(tripId: UUID) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase.from("trips")
            .update(Payload(status: TripStatus.cancelled.rawValue))
            .eq("id", value: tripId.uuidString).execute()
    }

    // MARK: - Coordinates & Rating

    static func updateTripCoordinates(
        tripId: UUID,
        originLat: Double, originLng: Double,
        destLat: Double, destLng: Double,
        routePolyline: String
    ) async throws {
        struct Payload: Encodable {
            let origin_latitude: Double
            let origin_longitude: Double
            let destination_latitude: Double
            let destination_longitude: Double
            let route_polyline: String
        }
        try await supabase.from("trips")
            .update(Payload(
                origin_latitude: originLat, origin_longitude: originLng,
                destination_latitude: destLat, destination_longitude: destLng,
                route_polyline: routePolyline
            ))
            .eq("id", value: tripId.uuidString).execute()
    }

    static func rateDriver(tripId: UUID, rating: Int, note: String?, ratedById: UUID) async throws {
        struct Payload: Encodable {
            let driver_rating: Int
            let driver_rating_note: String?
            let rated_by_id: String
            let rated_at: String
        }
        try await supabase.from("trips")
            .update(Payload(
                driver_rating: rating,
                driver_rating_note: note,
                rated_by_id: ratedById.uuidString,
                rated_at: iso.string(from: Date())
            ))
            .eq("id", value: tripId.uuidString).execute()
    }

    static func reassignVehicle(tripId: UUID, newVehicleId: UUID) async throws {
        struct Payload: Encodable { let vehicle_id: String }
        struct Row: Decodable { let id: UUID; let vehicle_id: UUID? }
        let rows: [Row] = try await supabase.from("trips")
            .update(Payload(vehicle_id: newVehicleId.uuidString))
            .eq("id", value: tripId.uuidString)
            .select("id, vehicle_id").execute().value
        guard !rows.isEmpty else { throw TripServiceError.tripNotFound(tripId) }
    }
}

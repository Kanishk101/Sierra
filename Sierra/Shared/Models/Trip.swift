import Foundation

// MARK: - Trip Status
// Maps to PostgreSQL enum: trip_status

enum TripStatus: String, Codable, CaseIterable {
    case scheduled = "Scheduled"
    case active    = "Active"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var color: String {
        switch self {
        case .scheduled: "blue"
        case .active:    "green"
        case .completed: "gray"
        case .cancelled: "red"
        }
    }
}

// MARK: - Trip Priority
// Maps to PostgreSQL enum: trip_priority

enum TripPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case normal = "Normal"
    case high   = "High"
    case urgent = "Urgent"
}

// MARK: - Trip
// Maps to table: trips
// FK columns (driver_id, vehicle_id, created_by_admin_id) are stored as TEXT in Supabase
// and decoded as String/String? per schema v2 rules.

struct Trip: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Core fields
    var taskId: String                    // task_id (UNIQUE)
    var driverId: String?                 // driver_id (FK → staff_members.id, TEXT)
    var vehicleId: String?                // vehicle_id (FK → vehicles.id, TEXT)
    var createdByAdminId: String          // created_by_admin_id (FK → staff_members.id, TEXT)

    // MARK: Route
    var origin: String
    var destination: String
    var originLatitude: Double?           // origin_latitude
    var originLongitude: Double?          // origin_longitude
    var destinationLatitude: Double?      // destination_latitude
    var destinationLongitude: Double?     // destination_longitude
    var routePolyline: String?            // route_polyline
    var routeStops: [RouteStop]?          // route_stops (JSONB array, nullable for backward compat)
    var deliveryInstructions: String      // delivery_instructions (default '')

    // MARK: Scheduling
    var scheduledDate: Date
    var scheduledEndDate: Date?
    var actualStartDate: Date?
    var actualEndDate: Date?

    // MARK: Odometry
    var startMileage: Double?
    var endMileage: Double?

    // MARK: Metadata
    var notes: String                     // notes (default '')
    var status: TripStatus
    var priority: TripPriority

    // MARK: Related records
    var proofOfDeliveryId: UUID?
    var preInspectionId: UUID?
    var postInspectionId: UUID?

    // MARK: Rating
    var driverRating: Int?               // driver_rating (smallint nullable)
    var driverRatingNote: String?        // driver_rating_note
    var ratedById: UUID?                 // rated_by_id (FK → staff_members.id)
    var ratedAt: Date?                   // rated_at

    // MARK: Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case taskId               = "task_id"
        case driverId             = "driver_id"
        case vehicleId            = "vehicle_id"
        case createdByAdminId     = "created_by_admin_id"
        case origin, destination
        case originLatitude       = "origin_latitude"
        case originLongitude      = "origin_longitude"
        case destinationLatitude  = "destination_latitude"
        case destinationLongitude = "destination_longitude"
        case routePolyline        = "route_polyline"
        case routeStops           = "route_stops"
        case deliveryInstructions = "delivery_instructions"
        case scheduledDate        = "scheduled_date"
        case scheduledEndDate     = "scheduled_end_date"
        case actualStartDate      = "actual_start_date"
        case actualEndDate        = "actual_end_date"
        case startMileage         = "start_mileage"
        case endMileage           = "end_mileage"
        case notes, status, priority
        case proofOfDeliveryId    = "proof_of_delivery_id"
        case preInspectionId      = "pre_inspection_id"
        case postInspectionId     = "post_inspection_id"
        case driverRating         = "driver_rating"
        case driverRatingNote     = "driver_rating_note"
        case ratedById            = "rated_by_id"
        case ratedAt              = "rated_at"
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
    }

    // MARK: - Computed

    var distanceKm: Double? {
        guard let start = startMileage, let end = endMileage else { return nil }
        return end - start
    }

    var isOverdue: Bool {
        status == .scheduled && scheduledDate < Date()
    }

    var durationString: String? {
        guard let start = actualStartDate, let end = actualEndDate else { return nil }
        let interval = end.timeIntervalSince(start)
        let hours   = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: - Helpers

    /// Convenience accessors that parse the String FK back to UUID when needed.
    var driverUUID: UUID?  { driverId.flatMap(UUID.init) }
    var vehicleUUID: UUID? { vehicleId.flatMap(UUID.init) }
    var adminUUID: UUID?   { UUID(uuidString: createdByAdminId) }

    // MARK: - Task ID Generation

    static func generateTaskId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: Date())
        let random  = String(format: "%04d", Int.random(in: 0...9999))
        return "TRP-\(dateStr)-\(random)"
    }

    // MARK: - Mock Data

    static let mockData: [Trip] = {
        let cal     = Calendar.current
        let now     = Date()
        let adminId = "F0000000-0000-0000-0000-000000000001"

        return [
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
                taskId: "TRP-20260310-0001",
                driverId: "D0000000-0000-0000-0000-000000000001",
                vehicleId: "A0000000-0000-0000-0000-000000000001",
                createdByAdminId: adminId,
                origin: "Mumbai Warehouse",
                destination: "Pune Distribution Center",
                originLatitude: nil,
                originLongitude: nil,
                destinationLatitude: nil,
                destinationLongitude: nil,
                routePolyline: nil,
                routeStops: nil,
                deliveryInstructions: "Handle with care — electronics",
                scheduledDate: cal.date(byAdding: .hour, value: -2, to: now) ?? now,
                scheduledEndDate: cal.date(byAdding: .hour, value: 4, to: now),
                actualStartDate: cal.date(byAdding: .hour, value: -1, to: now),
                actualEndDate: nil,
                startMileage: 45230.5,
                endMileage: nil,
                notes: "Fragile cargo — electronics shipment",
                status: .active,
                priority: .high,
                proofOfDeliveryId: nil,
                preInspectionId: nil,
                postInspectionId: nil,
                driverRating: nil,
                driverRatingNote: nil,
                ratedById: nil,
                ratedAt: nil,
                createdAt: cal.date(byAdding: .hour, value: -3, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -1, to: now) ?? now
            ),
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
                taskId: "TRP-20260310-0042",
                driverId: nil,
                vehicleId: nil,
                createdByAdminId: adminId,
                origin: "Delhi Hub",
                destination: "Jaipur Depot",
                originLatitude: nil,
                originLongitude: nil,
                destinationLatitude: nil,
                destinationLongitude: nil,
                routePolyline: nil,
                routeStops: nil,
                deliveryInstructions: "",
                scheduledDate: cal.date(byAdding: .day, value: 1, to: now) ?? now,
                scheduledEndDate: nil,
                actualStartDate: nil,
                actualEndDate: nil,
                startMileage: nil,
                endMileage: nil,
                notes: "Regular supply route",
                status: .scheduled,
                priority: .normal,
                proofOfDeliveryId: nil,
                preInspectionId: nil,
                postInspectionId: nil,
                driverRating: nil,
                driverRatingNote: nil,
                ratedById: nil,
                ratedAt: nil,
                createdAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now
            ),
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000003")!,
                taskId: "TRP-20260309-0017",
                driverId: "D0000000-0000-0000-0000-000000000001",
                vehicleId: "A0000000-0000-0000-0000-000000000001",
                createdByAdminId: adminId,
                origin: "Chennai Port",
                destination: "Bangalore Warehouse",
                originLatitude: nil,
                originLongitude: nil,
                destinationLatitude: nil,
                destinationLongitude: nil,
                routePolyline: nil,
                routeStops: nil,
                deliveryInstructions: "",
                scheduledDate: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                scheduledEndDate: cal.date(byAdding: .hour, value: -22, to: now),
                actualStartDate: cal.date(byAdding: .hour, value: -28, to: now),
                actualEndDate: cal.date(byAdding: .hour, value: -22, to: now),
                startMileage: 44800.0,
                endMileage: 45150.5,
                notes: "Delivered on time",
                status: .completed,
                priority: .normal,
                proofOfDeliveryId: nil,
                preInspectionId: nil,
                postInspectionId: nil,
                driverRating: nil,
                driverRatingNote: nil,
                ratedById: nil,
                ratedAt: nil,
                createdAt: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -22, to: now) ?? now
            ),
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000004")!,
                taskId: "TRP-20260308-0005",
                driverId: nil,
                vehicleId: "A0000000-0000-0000-0000-000000000003",
                createdByAdminId: adminId,
                origin: "Hyderabad Yard",
                destination: "Vizag Terminal",
                originLatitude: nil,
                originLongitude: nil,
                destinationLatitude: nil,
                destinationLongitude: nil,
                routePolyline: nil,
                routeStops: nil,
                deliveryInstructions: "",
                scheduledDate: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                scheduledEndDate: nil,
                actualStartDate: nil,
                actualEndDate: nil,
                startMileage: nil,
                endMileage: nil,
                notes: "Vehicle entered maintenance — trip cancelled",
                status: .cancelled,
                priority: .low,
                proofOfDeliveryId: nil,
                preInspectionId: nil,
                postInspectionId: nil,
                driverRating: nil,
                driverRatingNote: nil,
                ratedById: nil,
                ratedAt: nil,
                createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -2, to: now) ?? now
            ),
        ]
    }()
}

import Foundation

// MARK: - Trip Status
// Maps to PostgreSQL enum: trip_status
//
// CANONICAL FLOW (post migration simplify_statuses_flow_and_security):
//   PendingAcceptance → (driver accepts) → Scheduled
//   Scheduled         → (pre-trip done + within 30min window) → Active
//   Active            → (POD + post-trip) → Completed
//   PendingAcceptance | Scheduled → (FM cancels) → Cancelled
//
// Removed from DB (CHECK constraint blocks writes):
//   Accepted → maps to Scheduled (driver has accepted = trip is Scheduled)
//   Rejected → maps to Cancelled
//
// Both are kept in the Swift enum ONLY for safe decoding of any residual
// in-memory/cached data. They will never appear from a fresh DB query.

enum TripStatus: String, Codable, CaseIterable {
    case pendingAcceptance  = "PendingAcceptance"
    case scheduled          = "Scheduled"
    case active             = "Active"
    case completed          = "Completed"
    case cancelled          = "Cancelled"
    // Legacy decode-only — DB CHECK constraint blocks new writes of these values.
    // accepted was migrated to Scheduled; rejected was migrated to Cancelled.
    case accepted           = "Accepted"
    case rejected           = "Rejected"

    var color: String {
        switch self {
        case .pendingAcceptance: return "orange"
        case .scheduled:         return "blue"
        case .active:            return "green"
        case .completed:         return "gray"
        case .cancelled:         return "red"
        case .accepted:          return "blue"   // treat same as scheduled
        case .rejected:          return "red"    // treat same as cancelled
        }
    }

    /// True when the driver still needs to act on this trip.
    var isActionable: Bool {
        switch self {
        case .pendingAcceptance, .scheduled, .active: return true
        case .accepted: return true   // legacy — treat as scheduled
        default: return false
        }
    }

    /// Normalised status — maps legacy values to their canonical equivalents.
    var normalized: TripStatus {
        switch self {
        case .accepted: return .scheduled
        case .rejected: return .cancelled
        default: return self
        }
    }

    static func parse(_ raw: String) -> TripStatus? {
        if let exact = TripStatus(rawValue: raw) { return exact }

        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "pendingacceptance": return .pendingAcceptance
        case "scheduled": return .scheduled
        case "active": return .active
        case "completed": return .completed
        case "cancelled", "canceled": return .cancelled
        case "accepted": return .accepted
        case "rejected": return .rejected
        default: return nil
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
// FK columns (driver_id, vehicle_id, created_by_admin_id) stored as TEXT in Supabase.

struct Trip: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Core fields
    var taskId: String
    var driverId: String?
    var vehicleId: String?
    var createdByAdminId: String

    // MARK: Route
    var origin: String
    var destination: String
    var originLatitude: Double?
    var originLongitude: Double?
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var routePolyline: String?
    var routeStops: [RouteStop]?
    var deliveryInstructions: String

    // MARK: Scheduling
    var scheduledDate: Date
    var scheduledEndDate: Date?
    var actualStartDate: Date?
    var actualEndDate: Date?

    // MARK: Odometry
    var startMileage: Double?
    var endMileage: Double?

    // MARK: Metadata
    var notes: String
    var status: TripStatus
    var priority: TripPriority

    // MARK: Related records
    var proofOfDeliveryId: UUID?
    var preInspectionId: UUID?
    var postInspectionId: UUID?

    // MARK: Acceptance lifecycle
    var acceptedAt: Date?           = nil
    var acceptanceDeadline: Date?   = nil
    var rejectedReason: String?     = nil

    // MARK: Rating
    var driverRating: Int?
    var driverRatingNote: String?
    var ratedById: UUID?
    var ratedAt: Date?

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
        case acceptedAt           = "accepted_at"
        case acceptanceDeadline   = "acceptance_deadline"
        case rejectedReason       = "rejected_reason"
        case driverRating         = "driver_rating"
        case driverRatingNote     = "driver_rating_note"
        case ratedById            = "rated_by_id"
        case ratedAt              = "rated_at"
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
    }

    // MARK: - Decoder Hardening

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id                   = try c.decode(UUID.self, forKey: .id)
        taskId               = try c.decode(String.self, forKey: .taskId)
        driverId             = try c.decodeIfPresent(String.self, forKey: .driverId)
        vehicleId            = try c.decodeIfPresent(String.self, forKey: .vehicleId)
        createdByAdminId     = try c.decode(String.self, forKey: .createdByAdminId)
        origin               = try c.decode(String.self, forKey: .origin)
        destination          = try c.decode(String.self, forKey: .destination)
        originLatitude       = try c.decodeIfPresent(Double.self, forKey: .originLatitude)
        originLongitude      = try c.decodeIfPresent(Double.self, forKey: .originLongitude)
        destinationLatitude  = try c.decodeIfPresent(Double.self, forKey: .destinationLatitude)
        destinationLongitude = try c.decodeIfPresent(Double.self, forKey: .destinationLongitude)
        routePolyline        = try c.decodeIfPresent(String.self, forKey: .routePolyline)

        if let parsedStops = try? c.decodeIfPresent([RouteStop].self, forKey: .routeStops) {
            routeStops = parsedStops
        } else if let raw = try? c.decode(String.self, forKey: .routeStops),
                  let data = raw.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode([RouteStop].self, from: data) {
            routeStops = parsed
        } else {
            routeStops = nil
        }

        deliveryInstructions = try c.decodeIfPresent(String.self, forKey: .deliveryInstructions) ?? ""
        scheduledDate        = try c.decode(Date.self, forKey: .scheduledDate)
        scheduledEndDate     = try c.decodeIfPresent(Date.self, forKey: .scheduledEndDate)
        actualStartDate      = try c.decodeIfPresent(Date.self, forKey: .actualStartDate)
        actualEndDate        = try c.decodeIfPresent(Date.self, forKey: .actualEndDate)
        startMileage         = try c.decodeIfPresent(Double.self, forKey: .startMileage)
        endMileage           = try c.decodeIfPresent(Double.self, forKey: .endMileage)
        notes                = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""

        let statusRaw   = try c.decodeIfPresent(String.self, forKey: .status) ?? TripStatus.scheduled.rawValue
        let priorityRaw = try c.decodeIfPresent(String.self, forKey: .priority) ?? TripPriority.normal.rawValue
        status          = TripStatus.parse(statusRaw) ?? .scheduled
        priority        = TripPriority(rawValue: priorityRaw) ?? .normal

        proofOfDeliveryId  = try c.decodeIfPresent(UUID.self, forKey: .proofOfDeliveryId)
        preInspectionId    = try c.decodeIfPresent(UUID.self, forKey: .preInspectionId)
        postInspectionId   = try c.decodeIfPresent(UUID.self, forKey: .postInspectionId)
        acceptedAt         = try c.decodeIfPresent(Date.self, forKey: .acceptedAt)
        acceptanceDeadline = try c.decodeIfPresent(Date.self, forKey: .acceptanceDeadline)
        rejectedReason     = try c.decodeIfPresent(String.self, forKey: .rejectedReason)
        driverRating       = try c.decodeIfPresent(Int.self, forKey: .driverRating)
        driverRatingNote   = try c.decodeIfPresent(String.self, forKey: .driverRatingNote)
        ratedById          = try c.decodeIfPresent(UUID.self, forKey: .ratedById)
        ratedAt            = try c.decodeIfPresent(Date.self, forKey: .ratedAt)
        createdAt          = try c.decode(Date.self, forKey: .createdAt)
        updatedAt          = try c.decode(Date.self, forKey: .updatedAt)
    }

    // Explicit memberwise initializer to preserve existing call sites.
    init(
        id: UUID,
        taskId: String,
        driverId: String?,
        vehicleId: String?,
        createdByAdminId: String,
        origin: String,
        destination: String,
        originLatitude: Double?,
        originLongitude: Double?,
        destinationLatitude: Double?,
        destinationLongitude: Double?,
        routePolyline: String?,
        routeStops: [RouteStop]?,
        deliveryInstructions: String,
        scheduledDate: Date,
        scheduledEndDate: Date?,
        actualStartDate: Date?,
        actualEndDate: Date?,
        startMileage: Double?,
        endMileage: Double?,
        notes: String,
        status: TripStatus,
        priority: TripPriority,
        proofOfDeliveryId: UUID?,
        preInspectionId: UUID?,
        postInspectionId: UUID?,
        acceptedAt: Date? = nil,
        acceptanceDeadline: Date? = nil,
        rejectedReason: String? = nil,
        driverRating: Int?,
        driverRatingNote: String?,
        ratedById: UUID?,
        ratedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.taskId = taskId
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.createdByAdminId = createdByAdminId
        self.origin = origin
        self.destination = destination
        self.originLatitude = originLatitude
        self.originLongitude = originLongitude
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.routePolyline = routePolyline
        self.routeStops = routeStops
        self.deliveryInstructions = deliveryInstructions
        self.scheduledDate = scheduledDate
        self.scheduledEndDate = scheduledEndDate
        self.actualStartDate = actualStartDate
        self.actualEndDate = actualEndDate
        self.startMileage = startMileage
        self.endMileage = endMileage
        self.notes = notes
        self.status = status
        self.priority = priority
        self.proofOfDeliveryId = proofOfDeliveryId
        self.preInspectionId = preInspectionId
        self.postInspectionId = postInspectionId
        self.acceptedAt = acceptedAt
        self.acceptanceDeadline = acceptanceDeadline
        self.rejectedReason = rejectedReason
        self.driverRating = driverRating
        self.driverRatingNote = driverRatingNote
        self.ratedById = ratedById
        self.ratedAt = ratedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed

    var distanceKm: Double? {
        guard let start = startMileage, let end = endMileage else { return nil }
        return end - start
    }

    var isOverdue: Bool {
        (status == .scheduled || status == .pendingAcceptance) && scheduledDate < Date()
    }

    var durationString: String? {
        guard let start = actualStartDate, let end = actualEndDate else { return nil }
        let interval = end.timeIntervalSince(start)
        let hours   = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// Trip has finished route execution (POD captured + end odometer captured),
    /// but may still require post-trip inspection before status becomes Completed.
    var hasEndedNavigationPhase: Bool {
        status.normalized == .active && proofOfDeliveryId != nil && endMileage != nil
    }

    var requiresPostTripInspection: Bool {
        (status.normalized == .completed && postInspectionId == nil)
        || (hasEndedNavigationPhase && postInspectionId == nil)
    }

    /// Driver flow completion used by UI when backend status lags behind.
    /// Treat as completed once POD + end odometer + post inspection are present.
    var isDriverWorkflowCompleted: Bool {
        status.normalized == .completed
        || (proofOfDeliveryId != nil && endMileage != nil && postInspectionId != nil)
    }

    // MARK: - Helpers

    var driverUUID: UUID?  { driverId.flatMap(UUID.init) }
    var vehicleUUID: UUID? { vehicleId.flatMap(UUID.init) }
    var adminUUID: UUID?   { UUID(uuidString: createdByAdminId) }

    static func generateTaskId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: Date())
        let random  = String(format: "%04d", Int.random(in: 0...9999))
        return "TRP-\(dateStr)-\(random)"
    }

    // MARK: - Mock Data

    #if DEBUG
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
                originLatitude: nil, originLongitude: nil,
                destinationLatitude: nil, destinationLongitude: nil,
                routePolyline: nil, routeStops: nil,
                deliveryInstructions: "Handle with care",
                scheduledDate: cal.date(byAdding: .hour, value: -2, to: now) ?? now,
                scheduledEndDate: cal.date(byAdding: .hour, value: 4, to: now),
                actualStartDate: cal.date(byAdding: .hour, value: -1, to: now),
                actualEndDate: nil,
                startMileage: 45230.5, endMileage: nil,
                notes: "Fragile cargo", status: .active, priority: .high,
                proofOfDeliveryId: nil, preInspectionId: nil, postInspectionId: nil,
                driverRating: nil, driverRatingNote: nil, ratedById: nil, ratedAt: nil,
                createdAt: cal.date(byAdding: .hour, value: -3, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -1, to: now) ?? now
            ),
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
                taskId: "TRP-20260310-0042",
                driverId: "D0000000-0000-0000-0000-000000000001",
                vehicleId: nil,
                createdByAdminId: adminId,
                origin: "Delhi Hub",
                destination: "Jaipur Depot",
                originLatitude: nil, originLongitude: nil,
                destinationLatitude: nil, destinationLongitude: nil,
                routePolyline: nil, routeStops: nil,
                deliveryInstructions: "",
                scheduledDate: cal.date(byAdding: .day, value: 1, to: now) ?? now,
                scheduledEndDate: nil,
                actualStartDate: nil, actualEndDate: nil,
                startMileage: nil, endMileage: nil,
                notes: "Regular supply route", status: .pendingAcceptance, priority: .normal,
                proofOfDeliveryId: nil, preInspectionId: nil, postInspectionId: nil,
                driverRating: nil, driverRatingNote: nil, ratedById: nil, ratedAt: nil,
                createdAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now
            ),
        ]
    }()
    #endif
}

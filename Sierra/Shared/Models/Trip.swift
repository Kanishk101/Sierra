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

struct Trip: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Core fields
    var taskId: String                    // task_id (UNIQUE)
    var driverId: UUID?                   // driver_id (FK → staff_members.id)
    var vehicleId: UUID?                  // vehicle_id (FK → vehicles.id)
    var createdByAdminId: UUID            // created_by_admin_id (FK → staff_members.id)

    // MARK: Route
    var origin: String                    // origin
    var destination: String               // destination
    var deliveryInstructions: String      // delivery_instructions (default '')

    // MARK: Scheduling
    var scheduledDate: Date               // scheduled_date
    var scheduledEndDate: Date?           // scheduled_end_date
    var actualStartDate: Date?            // actual_start_date
    var actualEndDate: Date?              // actual_end_date

    // MARK: Odometry
    var startMileage: Double?             // start_mileage
    var endMileage: Double?               // end_mileage

    // MARK: Metadata
    var notes: String                     // notes (default '')
    var status: TripStatus                // status
    var priority: TripPriority            // priority

    // MARK: Related records
    var proofOfDeliveryId: UUID?          // proof_of_delivery_id (FK)
    var preInspectionId: UUID?            // pre_inspection_id (FK)
    var postInspectionId: UUID?           // post_inspection_id (FK)

    // MARK: Timestamps
    var createdAt: Date                   // created_at
    var updatedAt: Date                   // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case taskId                = "task_id"
        case driverId              = "driver_id"
        case vehicleId             = "vehicle_id"
        case createdByAdminId      = "created_by_admin_id"
        case origin
        case destination
        case deliveryInstructions  = "delivery_instructions"
        case scheduledDate         = "scheduled_date"
        case scheduledEndDate      = "scheduled_end_date"
        case actualStartDate       = "actual_start_date"
        case actualEndDate         = "actual_end_date"
        case startMileage          = "start_mileage"
        case endMileage            = "end_mileage"
        case notes
        case status
        case priority
        case proofOfDeliveryId     = "proof_of_delivery_id"
        case preInspectionId       = "pre_inspection_id"
        case postInspectionId      = "post_inspection_id"
        case createdAt             = "created_at"
        case updatedAt             = "updated_at"
    }

    // MARK: - Computed

    var durationString: String? {
        guard let start = actualStartDate, let end = actualEndDate else { return nil }
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var distanceKm: Double? {
        guard let start = startMileage, let end = endMileage else { return nil }
        return end - start
    }

    // MARK: - Task ID Generation

    /// Generates a task ID in format: TRP-yyyyMMdd-XXXX (4 random digits)
    static func generateTaskId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: Date())
        let random = String(format: "%04d", Int.random(in: 0...9999))
        return "TRP-\(dateStr)-\(random)"
    }

    // MARK: - Mock Data

    static let mockData: [Trip] = {
        let cal = Calendar.current
        let now = Date()
        let adminId = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!

        return [
            // Active trip
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
                taskId: "TRP-20260310-0001",
                driverId: UUID(uuidString: "D0000000-0000-0000-0000-000000000001"),
                vehicleId: UUID(uuidString: "A0000000-0000-0000-0000-000000000001"),
                createdByAdminId: adminId,
                origin: "Mumbai Warehouse",
                destination: "Pune Distribution Center",
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
                createdAt: cal.date(byAdding: .hour, value: -3, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -1, to: now) ?? now
            ),
            // Scheduled trip
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
                taskId: "TRP-20260310-0042",
                driverId: nil,
                vehicleId: nil,
                createdByAdminId: adminId,
                origin: "Delhi Hub",
                destination: "Jaipur Depot",
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
                createdAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -6, to: now) ?? now
            ),
            // Completed trip
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000003")!,
                taskId: "TRP-20260309-0017",
                driverId: UUID(uuidString: "D0000000-0000-0000-0000-000000000001"),
                vehicleId: UUID(uuidString: "A0000000-0000-0000-0000-000000000001"),
                createdByAdminId: adminId,
                origin: "Chennai Port",
                destination: "Bangalore Warehouse",
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
                createdAt: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: cal.date(byAdding: .hour, value: -22, to: now) ?? now
            ),
            // Cancelled trip
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000004")!,
                taskId: "TRP-20260308-0005",
                driverId: nil,
                vehicleId: UUID(uuidString: "A0000000-0000-0000-0000-000000000003"),
                createdByAdminId: adminId,
                origin: "Hyderabad Yard",
                destination: "Vizag Terminal",
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
                createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                updatedAt: cal.date(byAdding: .day, value: -2, to: now) ?? now
            ),
        ]
    }()
}

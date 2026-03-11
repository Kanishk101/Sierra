import Foundation

// MARK: - Trip Status

enum TripStatus: String, Codable, CaseIterable {
    case scheduled  = "Scheduled"
    case active     = "Active"
    case completed  = "Completed"
    case cancelled  = "Cancelled"

    var color: String {
        switch self {
        case .scheduled:  "blue"
        case .active:     "green"
        case .completed:  "gray"
        case .cancelled:  "red"
        }
    }
}

// MARK: - Trip Priority

enum TripPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case normal = "Normal"
    case high   = "High"
    case urgent = "Urgent"
}

// MARK: - Trip

struct Trip: Identifiable, Codable {
    let id: UUID
    var taskId: String
    var driverId: String?
    var vehicleId: String?
    var origin: String
    var destination: String
    var scheduledDate: Date
    var actualStartDate: Date?
    var actualEndDate: Date?
    var startMileage: Double?
    var endMileage: Double?
    var notes: String
    var status: TripStatus
    var priority: TripPriority

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

        return [
            // Active trip — assigned to driver_demo with vehicle 1
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000001")!,
                taskId: "TRP-20260310-0001",
                driverId: "D0000000-0000-0000-0000-000000000001",
                vehicleId: "A0000000-0000-0000-0000-000000000001",
                origin: "Mumbai Warehouse",
                destination: "Pune Distribution Center",
                scheduledDate: cal.date(byAdding: .hour, value: -2, to: now) ?? now,
                actualStartDate: cal.date(byAdding: .hour, value: -1, to: now),
                actualEndDate: nil,
                startMileage: 45230.5,
                endMileage: nil,
                notes: "Fragile cargo — electronics shipment",
                status: .active,
                priority: .high
            ),
            // Scheduled trip — tomorrow
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!,
                taskId: "TRP-20260310-0042",
                driverId: nil,
                vehicleId: nil,
                origin: "Delhi Hub",
                destination: "Jaipur Depot",
                scheduledDate: cal.date(byAdding: .day, value: 1, to: now) ?? now,
                actualStartDate: nil,
                actualEndDate: nil,
                startMileage: nil,
                endMileage: nil,
                notes: "Regular supply route",
                status: .scheduled,
                priority: .normal
            ),
            // Completed trip — yesterday
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000003")!,
                taskId: "TRP-20260309-0017",
                driverId: "D0000000-0000-0000-0000-000000000001",
                vehicleId: "A0000000-0000-0000-0000-000000000001",
                origin: "Chennai Port",
                destination: "Bangalore Warehouse",
                scheduledDate: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                actualStartDate: cal.date(byAdding: .hour, value: -28, to: now),
                actualEndDate: cal.date(byAdding: .hour, value: -22, to: now),
                startMileage: 44800.0,
                endMileage: 45150.5,
                notes: "Delivered on time",
                status: .completed,
                priority: .normal
            ),
            // Cancelled trip
            Trip(
                id: UUID(uuidString: "B0000000-0000-0000-0000-000000000004")!,
                taskId: "TRP-20260308-0005",
                driverId: nil,
                vehicleId: "A0000000-0000-0000-0000-000000000003",
                origin: "Hyderabad Yard",
                destination: "Vizag Terminal",
                scheduledDate: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                actualStartDate: nil,
                actualEndDate: nil,
                startMileage: nil,
                endMileage: nil,
                notes: "Vehicle entered maintenance — trip cancelled",
                status: .cancelled,
                priority: .low
            ),
        ]
    }()
}

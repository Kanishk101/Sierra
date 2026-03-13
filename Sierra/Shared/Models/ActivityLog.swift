import Foundation

// MARK: - Activity Type
// Maps to PostgreSQL enum: activity_type

enum ActivityType: String, Codable, CaseIterable {
    case tripStarted           = "Trip Started"
    case tripCompleted         = "Trip Completed"
    case tripCancelled         = "Trip Cancelled"
    case inspectionFailed      = "Inspection Failed"
    case vehicleAssigned       = "Vehicle Assigned"
    case maintenanceRequested  = "Maintenance Requested"
    case maintenanceCompleted  = "Maintenance Completed"
    case staffApproved         = "Staff Approved"
    case staffRejected         = "Staff Rejected"
    case emergencyAlert        = "Emergency Alert"
    case geofenceViolation     = "Geofence Violation"
    case documentExpiringSoon  = "Document Expiring Soon"
    case documentExpired       = "Document Expired"
    case fuelLogged            = "Fuel Logged"
}

// MARK: - Activity Severity
// Maps to PostgreSQL enum: activity_severity

enum ActivitySeverity: String, Codable, CaseIterable {
    case info     = "Info"
    case warning  = "Warning"
    case critical = "Critical"
}

// MARK: - ActivityLog
// Maps to table: activity_logs

struct ActivityLog: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Core fields
    var type: ActivityType                // type
    var title: String                     // title
    var description: String              // description
    var actorId: UUID?                    // actor_id (FK → staff_members.id)
    var entityType: String                // entity_type
    var entityId: UUID?                   // entity_id
    var severity: ActivitySeverity        // severity
    var isRead: Bool                      // is_read
    var timestamp: Date                   // timestamp
    var createdAt: Date                   // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case description
        case actorId     = "actor_id"
        case entityType  = "entity_type"
        case entityId    = "entity_id"
        case severity
        case isRead      = "is_read"
        case timestamp
        case createdAt   = "created_at"
    }

    // MARK: - Computed

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    // MARK: - Samples

    static let samples: [ActivityLog] = [
        ActivityLog(
            id: UUID(),
            type: .tripCompleted,
            title: "Trip Completed",
            description: "Hauler Alpha completed delivery to Dock 7",
            actorId: UUID(uuidString: "D0000000-0000-0000-0000-000000000001"),
            entityType: "trip",
            entityId: UUID(uuidString: "B0000000-0000-0000-0000-000000000003"),
            severity: .info,
            isRead: false,
            timestamp: Date().addingTimeInterval(-300),
            createdAt: Date().addingTimeInterval(-300)
        ),
        ActivityLog(
            id: UUID(),
            type: .maintenanceRequested,
            title: "Maintenance Requested",
            description: "Cargo One scheduled for brake inspection",
            actorId: nil,
            entityType: "vehicle",
            entityId: UUID(uuidString: "A0000000-0000-0000-0000-000000000003"),
            severity: .warning,
            isRead: false,
            timestamp: Date().addingTimeInterval(-1800),
            createdAt: Date().addingTimeInterval(-1800)
        ),
        ActivityLog(
            id: UUID(),
            type: .fuelLogged,
            title: "Fuel Logged",
            description: "City Runner refuelled — 62L diesel",
            actorId: UUID(uuidString: "D0000000-0000-0000-0000-000000000002"),
            entityType: "vehicle",
            entityId: UUID(uuidString: "A0000000-0000-0000-0000-000000000002"),
            severity: .info,
            isRead: true,
            timestamp: Date().addingTimeInterval(-3600),
            createdAt: Date().addingTimeInterval(-3600)
        ),
        ActivityLog(
            id: UUID(),
            type: .staffApproved,
            title: "Staff Application",
            description: "David Park submitted driver application",
            actorId: UUID(uuidString: "D0000000-0000-0000-0000-000000000003"),
            entityType: "staff_member",
            entityId: UUID(uuidString: "D0000000-0000-0000-0000-000000000003"),
            severity: .info,
            isRead: true,
            timestamp: Date().addingTimeInterval(-7200),
            createdAt: Date().addingTimeInterval(-7200)
        ),
        ActivityLog(
            id: UUID(),
            type: .documentExpiringSoon,
            title: "Document Expiring Soon",
            description: "Express Van insurance expires in 5 days",
            actorId: nil,
            entityType: "vehicle",
            entityId: UUID(uuidString: "A0000000-0000-0000-0000-000000000004"),
            severity: .warning,
            isRead: false,
            timestamp: Date().addingTimeInterval(-10800),
            createdAt: Date().addingTimeInterval(-10800)
        ),
    ]
}

import Foundation

// MARK: - Notification Type
// Maps to PostgreSQL enum: notification_type

enum NotificationType: String, Codable, CaseIterable {
    case tripAssigned          = "Trip Assigned"
    case tripCancelled         = "Trip Cancelled"
    case vehicleAssigned       = "Vehicle Assigned"
    case maintenanceApproved   = "Maintenance Approved"
    case maintenanceRejected   = "Maintenance Rejected"
    case maintenanceOverdue    = "Maintenance Overdue"
    case sosAlert              = "SOS Alert"
    case defectAlert           = "Defect Alert"
    case routeDeviation        = "Route Deviation"
    case geofenceViolation     = "Geofence Violation"
    case inspectionFailed      = "Inspection Failed"
    case general               = "General"
}

// MARK: - SierraNotification
// Maps to table: notifications
// Named SierraNotification to avoid conflict with Foundation.Notification

struct SierraNotification: Identifiable, Codable, Equatable {
    // MARK: Primary key
    let id: UUID

    // MARK: Core fields
    var recipientId: UUID                 // recipient_id (FK → staff_members.id)
    var type: NotificationType           // type
    var title: String                    // title
    var body: String                     // body

    // MARK: Entity reference
    var entityType: String?              // entity_type
    var entityId: UUID?                  // entity_id

    // MARK: Read status
    var isRead: Bool                     // is_read (default false)
    var readAt: Date?                    // read_at

    // MARK: Timestamps
    var sentAt: Date                     // sent_at
    var createdAt: Date                  // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case recipientId  = "recipient_id"
        case type
        case title
        case body
        case entityType   = "entity_type"
        case entityId     = "entity_id"
        case isRead       = "is_read"
        case readAt       = "read_at"
        case sentAt       = "sent_at"
        case createdAt    = "created_at"
    }
}

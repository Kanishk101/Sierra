import Foundation

// MARK: - NotificationType
// Maps to PostgreSQL enum: notification_type
// IMPORTANT: ALL enum values the DB can write must be listed here.
// Missing cases cause Codable to throw, dropping the notification silently.

enum NotificationType: String, Codable, CaseIterable {
    // Immediate notifications
    case tripAssigned            = "Trip Assigned"
    case tripAccepted            = "Trip Accepted"
    case tripRejected            = "Trip Rejected"
    case tripCancelled           = "Trip Cancelled"
    case vehicleAssigned         = "Vehicle Assigned"
    case maintenanceApproved     = "Maintenance Approved"
    case maintenanceRejected     = "Maintenance Rejected"
    case maintenanceOverdue      = "Maintenance Overdue"
    case sosAlert                = "SOS Alert"
    case defectAlert             = "Defect Alert"
    case routeDeviation          = "Route Deviation"
    case geofenceAlert           = "Geofence Alert"
    case documentExpiry          = "Document Expiry"
    case inspectionFailed        = "Inspection Failed"
    case emergency               = "Emergency"
    case maintenanceComplete     = "Maintenance Complete"
    case partsApproved           = "Parts Approved"
    case partsRejected           = "Parts Rejected"
    case maintenanceRequest      = "Maintenance Request"
    case general                 = "General"
    // Inspection lifecycle
    case preTripCompleted        = "Pre-Trip Completed"
    case postTripCompleted       = "Post-Trip Completed"
    case preTripFailed           = "Pre-Trip Failed"
    case postTripFailed          = "Post-Trip Failed"
    case preTripWarning          = "Pre-Trip Warning"
    case postTripWarning         = "Post-Trip Warning"
    // Scheduled notifications (queued by DB trigger, delivered at scheduled_for time)
    case preInspectionReminder   = "Pre-Inspection Reminder"
    case tripAcceptanceReminder  = "Trip Acceptance Reminder"

    // Graceful fallback for any future/unknown types to avoid drop on decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = NotificationType(rawValue: raw) ?? .general
    }
}

// MARK: - SierraNotification
// Maps to table: notifications
// Named SierraNotification to avoid conflict with Foundation.Notification

struct SierraNotification: Identifiable, Codable, Equatable {

    // MARK: Primary key
    let id: UUID

    // MARK: Core fields
    var recipientId: UUID
    var type: NotificationType
    var title: String
    var body: String

    // MARK: Entity reference
    var entityType: String?
    var entityId: UUID?

    // MARK: Read + delivery state
    var isRead: Bool
    var readAt: Date?
    var isDelivered: Bool          // is_delivered — false = scheduled but not yet pushed
    var scheduledFor: Date?        // scheduled_for — nil = immediate, non-nil = future delivery

    // MARK: Timestamps
    var sentAt: Date
    var createdAt: Date

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
        case isDelivered  = "is_delivered"
        case scheduledFor = "scheduled_for"
        case sentAt       = "sent_at"
        case createdAt    = "created_at"
    }

    // MARK: - Computed helpers

    /// True for immediate notifications, or scheduled ones that have been delivered.
    var isVisible: Bool { scheduledFor == nil || isDelivered }

    /// If this is a scheduled-but-not-yet-delivered reminder, returns how many
    /// minutes until it fires. Returns nil for delivered or immediate notifications.
    var minutesUntilDelivery: Int? {
        guard let fireDate = scheduledFor, !isDelivered else { return nil }
        let diff = fireDate.timeIntervalSinceNow
        guard diff > 0 else { return 0 }
        return Int(diff / 60)
    }

    /// True if this is a scheduled reminder that hasn't been delivered yet
    /// but is within 2 hours (surfaced in the notification bell as "Upcoming").
    var isPendingUpcoming: Bool {
        guard let fireDate = scheduledFor, !isDelivered else { return false }
        return fireDate.timeIntervalSinceNow > 0
            && fireDate.timeIntervalSinceNow <= 2 * 3600
    }
}

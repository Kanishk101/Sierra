import Foundation

// MARK: - Maintenance Task Type
// Maps to PostgreSQL enum: maintenance_task_type

enum MaintenanceTaskType: String, Codable, CaseIterable {
    case scheduled         = "Scheduled"
    case breakdown         = "Breakdown"
    case inspectionDefect  = "Inspection Defect"
    case urgent            = "Urgent"
}

// MARK: - Maintenance Task Status
// Maps to PostgreSQL enum: maintenance_task_status

enum MaintenanceTaskStatus: String, Codable, CaseIterable {
    case pending    = "Pending"
    case assigned   = "Assigned"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case cancelled  = "Cancelled"
}

// MARK: - Task Priority
// Maps to PostgreSQL enum: task_priority

enum TaskPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"
    case urgent = "Urgent"
}

// MARK: - MaintenanceTask
// Maps to table: maintenance_tasks

struct MaintenanceTask: Identifiable, Codable, Hashable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var vehicleId: UUID                       // vehicle_id (FK → vehicles.id)
    var createdByAdminId: UUID                // created_by_admin_id (FK → staff_members.id)
    var assignedToId: UUID?                   // assigned_to_id (FK → staff_members.id)

    // MARK: Task details
    var title: String                         // title
    var taskDescription: String              // task_description
    var priority: TaskPriority               // priority (default 'Medium')
    var status: MaintenanceTaskStatus        // status (default 'Pending')
    var taskType: MaintenanceTaskType        // task_type (default 'Scheduled')

    // MARK: Source/origin
    var sourceAlertId: UUID?                 // source_alert_id (FK → emergency_alerts.id)
    var sourceInspectionId: UUID?            // source_inspection_id (FK → vehicle_inspections.id)

    // MARK: Scheduling
    var dueDate: Date                        // due_date
    var completedAt: Date?                   // completed_at

    // MARK: Approval
    var approvedById: UUID?                  // approved_by_id (FK → staff_members.id)
    var approvedAt: Date?                    // approved_at
    var rejectionReason: String?             // rejection_reason

    // MARK: Timestamps
    var createdAt: Date                      // created_at
    var updatedAt: Date                      // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId           = "vehicle_id"
        case createdByAdminId    = "created_by_admin_id"
        case assignedToId        = "assigned_to_id"
        case title
        case taskDescription     = "task_description"
        case priority
        case status
        case taskType            = "task_type"
        case sourceAlertId       = "source_alert_id"
        case sourceInspectionId  = "source_inspection_id"
        case dueDate             = "due_date"
        case completedAt         = "completed_at"
        case approvedById        = "approved_by_id"
        case approvedAt          = "approved_at"
        case rejectionReason     = "rejection_reason"
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }
}

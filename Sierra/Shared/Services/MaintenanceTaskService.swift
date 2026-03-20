import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - MaintenanceTaskInsertPayload
// Excludes: id, created_at, updated_at, completed_at

struct MaintenanceTaskInsertPayload: Encodable {
    let vehicleId: String
    let createdByAdminId: String
    let assignedToId: String?
    let title: String
    let taskDescription: String
    let priority: String
    let status: String
    let taskType: String
    let sourceAlertId: String?
    let sourceInspectionId: String?
    let dueDate: String

    enum CodingKeys: String, CodingKey {
        case vehicleId          = "vehicle_id"
        case createdByAdminId   = "created_by_admin_id"
        case assignedToId       = "assigned_to_id"
        case title
        case taskDescription    = "task_description"
        case priority, status
        case taskType           = "task_type"
        case sourceAlertId      = "source_alert_id"
        case sourceInspectionId = "source_inspection_id"
        case dueDate            = "due_date"
    }

    init(from t: MaintenanceTask) {
        vehicleId          = t.vehicleId.uuidString
        createdByAdminId   = t.createdByAdminId.uuidString
        assignedToId       = t.assignedToId?.uuidString
        title              = t.title
        taskDescription    = t.taskDescription
        priority           = t.priority.rawValue
        status             = t.status.rawValue
        taskType           = t.taskType.rawValue
        sourceAlertId      = t.sourceAlertId?.uuidString
        sourceInspectionId = t.sourceInspectionId?.uuidString
        dueDate            = iso.string(from: t.dueDate)
    }
}

// MARK: - MaintenanceTaskUpdatePayload
// Same as insert + completedAt

struct MaintenanceTaskUpdatePayload: Encodable {
    let vehicleId: String
    let createdByAdminId: String
    let assignedToId: String?
    let title: String
    let taskDescription: String
    let priority: String
    let status: String
    let taskType: String
    let sourceAlertId: String?
    let sourceInspectionId: String?
    let dueDate: String
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case vehicleId          = "vehicle_id"
        case createdByAdminId   = "created_by_admin_id"
        case assignedToId       = "assigned_to_id"
        case title
        case taskDescription    = "task_description"
        case priority, status
        case taskType           = "task_type"
        case sourceAlertId      = "source_alert_id"
        case sourceInspectionId = "source_inspection_id"
        case dueDate            = "due_date"
        case completedAt        = "completed_at"
    }

    init(from t: MaintenanceTask) {
        vehicleId          = t.vehicleId.uuidString
        createdByAdminId   = t.createdByAdminId.uuidString
        assignedToId       = t.assignedToId?.uuidString
        title              = t.title
        taskDescription    = t.taskDescription
        priority           = t.priority.rawValue
        status             = t.status.rawValue
        taskType           = t.taskType.rawValue
        sourceAlertId      = t.sourceAlertId?.uuidString
        sourceInspectionId = t.sourceInspectionId?.uuidString
        dueDate            = iso.string(from: t.dueDate)
        completedAt        = t.completedAt.map { iso.string(from: $0) }
    }
}

// MARK: - MaintenanceTaskService

struct MaintenanceTaskService {

    // MARK: Fetch

    static func fetchAllMaintenanceTasks() async throws -> [MaintenanceTask] {
        try await supabase
            .from("maintenance_tasks")
            .select()
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    static func fetchMaintenanceTasks(vehicleId: UUID) async throws -> [MaintenanceTask] {
        try await supabase
            .from("maintenance_tasks")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    static func fetchMaintenanceTasks(assignedToId: UUID) async throws -> [MaintenanceTask] {
        try await supabase
            .from("maintenance_tasks")
            .select()
            .eq("assigned_to_id", value: assignedToId.uuidString)
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    static func fetchMaintenanceTasks(status: MaintenanceTaskStatus) async throws -> [MaintenanceTask] {
        try await supabase
            .from("maintenance_tasks")
            .select()
            .eq("status", value: status.rawValue)
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    // MARK: Insert

    static func addMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await supabase
            .from("maintenance_tasks")
            .insert(MaintenanceTaskInsertPayload(from: task))
            .execute()
    }

    // MARK: Update

    static func updateMaintenanceTask(_ task: MaintenanceTask) async throws {
        try await supabase
            .from("maintenance_tasks")
            .update(MaintenanceTaskUpdatePayload(from: task))
            .eq("id", value: task.id.uuidString)
            .execute()
    }

    static func updateMaintenanceTaskStatus(id: UUID, status: MaintenanceTaskStatus) async throws {
        struct Payload: Encodable { let status: String }
        try await supabase
            .from("maintenance_tasks")
            .update(Payload(status: status.rawValue))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Delete

    static func deleteMaintenanceTask(id: UUID) async throws {
        try await supabase
            .from("maintenance_tasks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Approval (single atomic update per safeguard)

    /// Approves a task: sets status, approved_by_id, approved_at, assigned_to_id in one call.
    static func approveTask(taskId: UUID, approvedById: UUID, assignedToId: UUID) async throws {
        struct Payload: Encodable {
            let status: String
            let approved_by_id: String
            let approved_at: String
            let assigned_to_id: String
        }
        try await supabase
            .from("maintenance_tasks")
            .update(Payload(
                status: MaintenanceTaskStatus.assigned.rawValue,
                approved_by_id: approvedById.uuidString,
                approved_at: iso.string(from: Date()),
                assigned_to_id: assignedToId.uuidString
            ))
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    /// Rejects a task: sets status, approved_by_id, approved_at, rejection_reason in one call.
    static func rejectTask(taskId: UUID, approvedById: UUID, reason: String) async throws {
        struct Payload: Encodable {
            let status: String
            let approved_by_id: String
            let approved_at: String
            let rejection_reason: String
        }
        try await supabase
            .from("maintenance_tasks")
            .update(Payload(
                status: MaintenanceTaskStatus.cancelled.rawValue,
                approved_by_id: approvedById.uuidString,
                approved_at: iso.string(from: Date()),
                rejection_reason: reason
            ))
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    // MARK: - Driver-initiated Request
    //
    // Creates a maintenance request raised by a driver (e.g. post-trip inspection
    // fail or ad-hoc breakdown report).
    //
    // Note on photos: maintenance_tasks has NO photo_urls column. Photos related
    // to a defect are stored on the vehicle_inspections row via its photo_urls
    // column and linked here via source_inspection_id. Do not attempt to pass
    // photos to this method — store them on the inspection first.

    static func createDriverRequest(
        vehicleId: UUID,
        driverId: UUID,
        title: String,
        description: String,
        priority: TaskPriority,
        sourceInspectionId: UUID?
    ) async throws {
        struct DriverRequestPayload: Encodable {
            let vehicle_id: String
            let created_by_admin_id: String
            let title: String
            let task_description: String
            let priority: String
            let status: String
            let task_type: String
            let source_inspection_id: String?
            let due_date: String
        }

        let payload = DriverRequestPayload(
            vehicle_id: vehicleId.uuidString,
            created_by_admin_id: driverId.uuidString,
            title: title,
            task_description: description,
            priority: priority.rawValue,
            status: MaintenanceTaskStatus.pending.rawValue,
            task_type: MaintenanceTaskType.inspectionDefect.rawValue,
            source_inspection_id: sourceInspectionId?.uuidString,
            due_date: iso.string(from: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date())
        )

        try await supabase
            .from("maintenance_tasks")
            .insert(payload)
            .execute()
    }
}

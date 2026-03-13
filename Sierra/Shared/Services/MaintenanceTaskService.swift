import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - MaintenanceTaskPayload

struct MaintenanceTaskPayload: Encodable {
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
        case priority
        case status
        case taskType           = "task_type"
        case sourceAlertId      = "source_alert_id"
        case sourceInspectionId = "source_inspection_id"
        case dueDate            = "due_date"
        case completedAt        = "completed_at"
    }

    init(from task: MaintenanceTask) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.vehicleId          = task.vehicleId.uuidString
        self.createdByAdminId   = task.createdByAdminId.uuidString
        self.assignedToId       = task.assignedToId?.uuidString
        self.title              = task.title
        self.taskDescription    = task.taskDescription
        self.priority           = task.priority.rawValue
        self.status             = task.status.rawValue
        self.taskType           = task.taskType.rawValue
        self.sourceAlertId      = task.sourceAlertId?.uuidString
        self.sourceInspectionId = task.sourceInspectionId?.uuidString
        self.dueDate            = fmt.string(from: task.dueDate)
        self.completedAt        = task.completedAt.map { fmt.string(from: $0) }
    }
}

// MARK: - MaintenanceTaskService

struct MaintenanceTaskService {

    static func fetchAllTasks() async throws -> [MaintenanceTask] {
        return try await supabase
            .from("maintenance_tasks")
            .select()
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    static func fetchTasks(vehicleId: UUID) async throws -> [MaintenanceTask] {
        return try await supabase
            .from("maintenance_tasks")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    static func fetchTasks(assignedToId: UUID) async throws -> [MaintenanceTask] {
        return try await supabase
            .from("maintenance_tasks")
            .select()
            .eq("assigned_to_id", value: assignedToId.uuidString)
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    static func fetchTasks(status: MaintenanceTaskStatus) async throws -> [MaintenanceTask] {
        return try await supabase
            .from("maintenance_tasks")
            .select()
            .eq("status", value: status.rawValue)
            .order("due_date", ascending: true)
            .execute()
            .value
    }

    static func addTask(_ task: MaintenanceTask) async throws {
        let payload = MaintenanceTaskPayload(from: task)
        try await supabase
            .from("maintenance_tasks")
            .insert(payload)
            .execute()
    }

    static func updateTask(_ task: MaintenanceTask) async throws {
        let payload = MaintenanceTaskPayload(from: task)
        try await supabase
            .from("maintenance_tasks")
            .update(payload)
            .eq("id", value: task.id.uuidString)
            .execute()
    }

    static func deleteTask(id: UUID) async throws {
        try await supabase
            .from("maintenance_tasks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

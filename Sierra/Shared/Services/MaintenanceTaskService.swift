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
        case status
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
        case status
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

    static func fetchAllMaintenanceTasks(limit: Int = 500) async throws -> [MaintenanceTask] {
        try await supabase
            .from("maintenance_tasks")
            .select()
            .order("due_date", ascending: true)
            .limit(limit)
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

    static func fetchTask(sourceAlertId: UUID) async throws -> MaintenanceTask? {
        let rows: [MaintenanceTask] = try await supabase
            .from("maintenance_tasks")
            .select()
            .eq("source_alert_id", value: sourceAlertId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
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

    /// Step 1 approval: mark task as admin-approved but keep it unassigned.
    /// Status intentionally remains Pending until a technician is assigned.
    static func approveTaskWithoutAssignment(taskId: UUID, approvedById: UUID) async throws {
        struct Payload: Encodable {
            let approved_by_id: String
            let approved_at: String
            let rejection_reason: String?
        }
        try await supabase
            .from("maintenance_tasks")
            .update(Payload(
                approved_by_id: approvedById.uuidString,
                approved_at: iso.string(from: Date()),
                rejection_reason: nil
            ))
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    /// Step 2 assignment after approval: assign technician.
    ///
    /// NOTE:
    /// Avoid writing `status = Assigned` here. In current backend, that transition
    /// can invoke work-order automation with enum-cast mismatch (`work_order_type`),
    /// which makes assignment fail. We persist the assignee and keep status pending;
    /// UI/workflows treat approved+assigned rows as effectively assigned.
    static func assignApprovedTask(taskId: UUID, assignedToId: UUID) async throws {
        struct Payload: Encodable {
            let assigned_to_id: String
        }
        try await supabase
            .from("maintenance_tasks")
            .update(Payload(
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
        createdById: UUID,
        title: String,
        description: String,
        sourceInspectionId: UUID?
    ) async throws -> UUID {
        struct DriverRequestPayload: Encodable {
            let vehicle_id: String
            let title: String
            let task_description: String
            let source_inspection_id: String?
            let due_date: String
        }

        struct DriverRequestResponse: Decodable {
            let id: String
        }

        let payload = DriverRequestPayload(
            vehicle_id: vehicleId.uuidString.lowercased(),
            title: title,
            task_description: description,
            source_inspection_id: sourceInspectionId?.uuidString,
            due_date: iso.string(from: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date())
        )

        // Driver/technician users cannot INSERT maintenance_tasks directly due to RLS.
        // Route creation through edge function with explicit caller JWT validation.
        // Keep `createdById` in signature for backward call-site compatibility.
        _ = createdById
        let response: DriverRequestResponse = try await SupabaseManager.invokeEdgeWithSessionRecovery(
            "create-driver-maintenance-request",
            body: payload
        )
        guard let taskId = UUID(uuidString: response.id) else {
            throw NSError(
                domain: "MaintenanceTaskService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Driver request created but task ID was invalid."]
            )
        }
        return taskId
    }

    static func fetchAvailableMaintenancePersonnel(limit: Int = 12) async throws -> [UUID] {
        struct StaffRow: Decodable { let id: UUID }
        let rows: [StaffRow] = try await supabase
            .from("staff_members")
            .select("id")
            .eq("role", value: UserRole.maintenancePersonnel.rawValue)
            .eq("status", value: StaffStatus.active.rawValue)
            .eq("availability", value: StaffAvailability.available.rawValue)
            .order("updated_at", ascending: true)
            .limit(limit)
            .execute()
            .value
        return rows.map(\.id)
    }

    static func approveAndAssignWithoutStatusChange(
        taskId: UUID,
        approvedById: UUID,
        assignedToId: UUID
    ) async throws {
        struct Payload: Encodable {
            let approved_by_id: String
            let approved_at: String
            let rejection_reason: String?
            let assigned_to_id: String
        }
        try await supabase
            .from("maintenance_tasks")
            .update(Payload(
                approved_by_id: approvedById.uuidString,
                approved_at: iso.string(from: Date()),
                rejection_reason: nil,
                assigned_to_id: assignedToId.uuidString
            ))
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    static func assignToFirstAvailableMaintenancePersonnel(
        taskId: UUID,
        approvedById: UUID
    ) async -> UUID? {
        guard let assigneeId = try? await fetchAvailableMaintenancePersonnel(limit: 1).first else {
            return nil
        }
        do {
            try await approveAndAssignWithoutStatusChange(
                taskId: taskId,
                approvedById: approvedById,
                assignedToId: assigneeId
            )
            return assigneeId
        } catch {
            #if DEBUG
            print("[MaintenanceTaskService] Auto-assignment failed: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Alert linkage

    /// On maintenance approval, linked active defect alerts should leave the Alerts inbox.
    /// This resolves:
    /// 1) explicit source_alert_id on the task, and
    /// 2) active defect alerts for the same vehicle/trip (fallback for legacy rows).
    static func resolveLinkedDefectAlertsOnApproval(
        task: MaintenanceTask,
        tripId: UUID?
    ) async {
        await resolveLinkedDefectAlertsOnTerminalDecision(task: task, tripId: tripId)
    }

    /// Resolves linked defect alerts when a maintenance request reaches any terminal decision
    /// path in admin flow (approval/assignment/rejection), so alerts don't stay stale.
    static func resolveLinkedDefectAlertsOnTerminalDecision(
        task: MaintenanceTask,
        tripId: UUID?
    ) async {
        var idsToResolve: Set<UUID> = []

        if let sourceAlertId = task.sourceAlertId {
            idsToResolve.insert(sourceAlertId)
        }

        if let matched = try? await EmergencyAlertService.fetchActiveDefectAlerts(
            vehicleId: task.vehicleId,
            tripId: tripId
        ) {
            for alert in matched {
                idsToResolve.insert(alert.id)
            }
        }

        for id in idsToResolve {
            try? await EmergencyAlertService.resolveAlert(id: id)
        }
    }
}

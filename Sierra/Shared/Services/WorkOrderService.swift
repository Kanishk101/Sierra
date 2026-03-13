import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - WorkOrderPayload
// NOTE: total_cost is GENERATED (labour_cost_total + parts_cost_total) — never included in payload.

struct WorkOrderPayload: Encodable {
    let maintenanceTaskId: String
    let vehicleId: String
    let assignedToId: String
    let status: String
    let repairDescription: String
    let labourCostTotal: Double
    let partsCostTotal: Double
    let startedAt: String?
    let completedAt: String?
    let technicianNotes: String?
    let vinScanned: Bool

    enum CodingKeys: String, CodingKey {
        case maintenanceTaskId = "maintenance_task_id"
        case vehicleId         = "vehicle_id"
        case assignedToId      = "assigned_to_id"
        case status
        case repairDescription = "repair_description"
        case labourCostTotal   = "labour_cost_total"
        case partsCostTotal    = "parts_cost_total"
        case startedAt         = "started_at"
        case completedAt       = "completed_at"
        case technicianNotes   = "technician_notes"
        case vinScanned        = "vin_scanned"
    }

    init(from order: WorkOrder) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.maintenanceTaskId = order.maintenanceTaskId.uuidString
        self.vehicleId         = order.vehicleId.uuidString
        self.assignedToId      = order.assignedToId.uuidString
        self.status            = order.status.rawValue
        self.repairDescription = order.repairDescription
        self.labourCostTotal   = order.labourCostTotal
        self.partsCostTotal    = order.partsCostTotal
        self.startedAt         = order.startedAt.map { fmt.string(from: $0) }
        self.completedAt       = order.completedAt.map { fmt.string(from: $0) }
        self.technicianNotes   = order.technicianNotes
        self.vinScanned        = order.vinScanned
    }
}

// MARK: - WorkOrderService

struct WorkOrderService {

    static func fetchAllWorkOrders() async throws -> [WorkOrder] {
        return try await supabase
            .from("work_orders")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchWorkOrder(maintenanceTaskId: UUID) async throws -> WorkOrder {
        return try await supabase
            .from("work_orders")
            .select()
            .eq("maintenance_task_id", value: maintenanceTaskId.uuidString)
            .single()
            .execute()
            .value
    }

    static func fetchWorkOrders(assignedToId: UUID) async throws -> [WorkOrder] {
        return try await supabase
            .from("work_orders")
            .select()
            .eq("assigned_to_id", value: assignedToId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func addWorkOrder(_ order: WorkOrder) async throws {
        let payload = WorkOrderPayload(from: order)
        try await supabase
            .from("work_orders")
            .insert(payload)
            .execute()
    }

    static func updateWorkOrder(_ order: WorkOrder) async throws {
        let payload = WorkOrderPayload(from: order)
        try await supabase
            .from("work_orders")
            .update(payload)
            .eq("id", value: order.id.uuidString)
            .execute()
    }

    static func deleteWorkOrder(id: UUID) async throws {
        try await supabase
            .from("work_orders")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

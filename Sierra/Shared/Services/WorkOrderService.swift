import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - WorkOrderInsertPayload
// Excludes: id, total_cost (GENERATED), created_at, updated_at, started_at, completed_at

struct WorkOrderInsertPayload: Encodable {
    let maintenanceTaskId: String
    let vehicleId: String
    let assignedToId: String
    let status: String
    let repairDescription: String
    let labourCostTotal: Double
    let partsCostTotal: Double
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
        case technicianNotes   = "technician_notes"
        case vinScanned        = "vin_scanned"
    }

    init(from o: WorkOrder) {
        maintenanceTaskId = o.maintenanceTaskId.uuidString
        vehicleId         = o.vehicleId.uuidString
        assignedToId      = o.assignedToId.uuidString
        status            = o.status.rawValue
        repairDescription = o.repairDescription
        labourCostTotal   = o.labourCostTotal
        partsCostTotal    = o.partsCostTotal
        technicianNotes   = o.technicianNotes
        vinScanned        = o.vinScanned
    }
}

// MARK: - WorkOrderUpdatePayload
// Same as insert + started_at, completed_at. Never includes total_cost.

struct WorkOrderUpdatePayload: Encodable {
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

    init(from o: WorkOrder) {
        maintenanceTaskId = o.maintenanceTaskId.uuidString
        vehicleId         = o.vehicleId.uuidString
        assignedToId      = o.assignedToId.uuidString
        status            = o.status.rawValue
        repairDescription = o.repairDescription
        labourCostTotal   = o.labourCostTotal
        partsCostTotal    = o.partsCostTotal
        startedAt         = o.startedAt.map  { iso.string(from: $0) }
        completedAt       = o.completedAt.map { iso.string(from: $0) }
        technicianNotes   = o.technicianNotes
        vinScanned        = o.vinScanned
    }
}

// MARK: - WorkOrderService

struct WorkOrderService {

    static func fetchAllWorkOrders() async throws -> [WorkOrder] {
        try await supabase
            .from("work_orders")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchWorkOrders(assignedToId: UUID) async throws -> [WorkOrder] {
        try await supabase
            .from("work_orders")
            .select()
            .eq("assigned_to_id", value: assignedToId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchWorkOrder(maintenanceTaskId: UUID) async throws -> WorkOrder? {
        let rows: [WorkOrder] = try await supabase
            .from("work_orders")
            .select()
            .eq("maintenance_task_id", value: maintenanceTaskId.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func fetchWorkOrders(vehicleId: UUID) async throws -> [WorkOrder] {
        try await supabase
            .from("work_orders")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func addWorkOrder(_ order: WorkOrder) async throws {
        try await supabase
            .from("work_orders")
            .insert(WorkOrderInsertPayload(from: order))
            .execute()
    }

    static func updateWorkOrder(_ order: WorkOrder) async throws {
        try await supabase
            .from("work_orders")
            .update(WorkOrderUpdatePayload(from: order))
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

    // MARK: - Repair Images & Estimated Completion

    /// Updates repair_image_urls. Passes Swift array directly — SDK handles serialisation.
    static func updateRepairImages(workOrderId: UUID, imageUrls: [String]) async throws {
        struct Payload: Encodable { let repair_image_urls: [String] }
        try await supabase
            .from("work_orders")
            .update(Payload(repair_image_urls: imageUrls))
            .eq("id", value: workOrderId.uuidString)
            .execute()
    }

    static func setEstimatedCompletion(workOrderId: UUID, estimatedAt: Date) async throws {
        struct Payload: Encodable { let estimated_completion_at: String }
        try await supabase
            .from("work_orders")
            .update(Payload(estimated_completion_at: iso.string(from: estimatedAt)))
            .eq("id", value: workOrderId.uuidString)
            .execute()
    }

    static func setVinScanned(workOrderId: UUID) async throws {
        struct P: Encodable { let vin_scanned: Bool }
        try await supabase
            .from("work_orders")
            .update(P(vin_scanned: true))
            .eq("id", value: workOrderId.uuidString)
            .execute()
    }

    /// Targeted update for estimated completion date only.
    static func updateEstimatedCompletion(workOrderId: UUID, date: Date) async throws {
        struct P: Encodable { let estimated_completion_at: String }
        try await supabase
            .from("work_orders")
            .update(P(estimated_completion_at: iso.string(from: date)))
            .eq("id", value: workOrderId.uuidString)
            .execute()
    }

    /// Targeted update for parts sub-status only.
    static func updatePartsSubStatus(workOrderId: UUID, status: PartsSubStatus) async throws {
        struct P: Encodable { let parts_sub_status: String }
        try await supabase
            .from("work_orders")
            .update(P(parts_sub_status: status.rawValue))
            .eq("id", value: workOrderId.uuidString)
            .execute()
    }
}

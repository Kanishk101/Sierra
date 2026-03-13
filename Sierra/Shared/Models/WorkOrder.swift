import Foundation

// MARK: - Work Order Status
// Maps to PostgreSQL enum: work_order_status

enum WorkOrderStatus: String, Codable, CaseIterable {
    case open       = "Open"
    case inProgress = "In Progress"
    case onHold     = "On Hold"
    case completed  = "Completed"
    case closed     = "Closed"
}

// MARK: - WorkOrder
// Maps to table: work_orders

struct WorkOrder: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var maintenanceTaskId: UUID          // maintenance_task_id (FK, UNIQUE)
    var vehicleId: UUID                  // vehicle_id (FK → vehicles.id)
    var assignedToId: UUID               // assigned_to_id (FK → staff_members.id)

    // MARK: Details
    var status: WorkOrderStatus          // status (default 'Open')
    var repairDescription: String        // repair_description (default '')
    var labourCostTotal: Double          // labour_cost_total (default 0)
    var partsCostTotal: Double           // parts_cost_total (default 0)
    /// Read-only GENERATED column: labour_cost_total + parts_cost_total
    let totalCost: Double?               // total_cost (GENERATED)

    // MARK: Scheduling
    var startedAt: Date?                 // started_at
    var completedAt: Date?               // completed_at

    // MARK: Notes & verification
    var technicianNotes: String?         // technician_notes
    var vinScanned: Bool                 // vin_scanned (default false)

    // MARK: Timestamps
    var createdAt: Date                  // created_at
    var updatedAt: Date                  // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case maintenanceTaskId   = "maintenance_task_id"
        case vehicleId           = "vehicle_id"
        case assignedToId        = "assigned_to_id"
        case status
        case repairDescription   = "repair_description"
        case labourCostTotal     = "labour_cost_total"
        case partsCostTotal      = "parts_cost_total"
        case totalCost           = "total_cost"
        case startedAt           = "started_at"
        case completedAt         = "completed_at"
        case technicianNotes     = "technician_notes"
        case vinScanned          = "vin_scanned"
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }
}

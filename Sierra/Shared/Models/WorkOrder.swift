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

// MARK: - Work Order Type
// Maps to PostgreSQL enum: work_order_type

enum WorkOrderType: String, Codable, CaseIterable {
    case repair  = "repair"
    case service = "service"
}

// MARK: - Parts Sub-Status
// Maps to PostgreSQL enum: parts_sub_status

enum PartsSubStatus: String, Codable, CaseIterable {
    case none           = "none"
    case requested      = "requested"
    case partiallyReady = "partially_ready"
    case approved       = "approved"
    case orderPlaced    = "order_placed"
    case ready          = "ready"

    var displayText: String {
        switch self {
        case .none:           return "No Parts Needed"
        case .requested:      return "Parts Request Sent"
        case .partiallyReady: return "Parts Partially Ready"
        case .approved:       return "Parts Available"
        case .orderPlaced:    return "Parts On Order"
        case .ready:          return "All Parts Ready"
        }
    }

    var icon: String {
        switch self {
        case .none:           return "shippingbox"
        case .requested:      return "clock.fill"
        case .partiallyReady: return "shippingbox.and.arrow.backward"
        case .approved:       return "checkmark.circle"
        case .orderPlaced:    return "cart.fill"
        case .ready:          return "checkmark.seal.fill"
        }
    }
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

    // MARK: Type & Parts State
    var workOrderType: WorkOrderType     // work_order_type (default 'repair')
    var partsSubStatus: PartsSubStatus   // parts_sub_status (default 'none')

    // MARK: Details
    var status: WorkOrderStatus          // status (default 'Open')
    var repairDescription: String        // repair_description (default '')
    var labourCostTotal: Double          // labour_cost_total (default 0)
    var partsCostTotal: Double           // parts_cost_total (default 0)
    let totalCost: Double                // total_cost (GENERATED)

    // MARK: Scheduling
    var startedAt: Date?                 // started_at
    var completedAt: Date?               // completed_at

    // MARK: Notes & verification
    var technicianNotes: String?         // technician_notes
    var vinScanned: Bool                 // vin_scanned (default false)

    // MARK: Images & estimates
    var repairImageUrls: [String] = []   // repair_image_urls (default '{}')
    var estimatedCompletionAt: Date?     // estimated_completion_at

    // MARK: Timestamps
    var createdAt: Date                  // created_at
    var updatedAt: Date                  // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case maintenanceTaskId   = "maintenance_task_id"
        case vehicleId           = "vehicle_id"
        case assignedToId        = "assigned_to_id"
        case workOrderType       = "work_order_type"
        case partsSubStatus      = "parts_sub_status"
        case status
        case repairDescription   = "repair_description"
        case labourCostTotal     = "labour_cost_total"
        case partsCostTotal      = "parts_cost_total"
        case totalCost           = "total_cost"
        case startedAt           = "started_at"
        case completedAt         = "completed_at"
        case technicianNotes     = "technician_notes"
        case vinScanned          = "vin_scanned"
        case repairImageUrls     = "repair_image_urls"
        case estimatedCompletionAt = "estimated_completion_at"
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }
}

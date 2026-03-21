import Foundation

// MARK: - Spare Parts Request Status
// Maps to PostgreSQL enum: spare_parts_request_status

enum SparePartsRequestStatus: String, Codable, CaseIterable {
    case pending   = "Pending"
    case approved  = "Approved"
    case rejected  = "Rejected"
    case fulfilled = "Fulfilled"
}

// MARK: - SparePartsRequest
// Maps to table: spare_parts_requests

struct SparePartsRequest: Identifiable, Codable, Equatable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var maintenanceTaskId: UUID           // maintenance_task_id (FK → maintenance_tasks.id)
    var workOrderId: UUID?                // work_order_id (nullable — may not exist until work order is created)
    var requestedById: UUID              // requested_by_id (FK → staff_members.id)

    // MARK: Part details
    var partName: String                 // part_name
    var partNumber: String?              // part_number
    var quantity: Int                    // quantity
    var estimatedUnitCost: Double?       // estimated_unit_cost
    var supplier: String?                // supplier
    var reason: String                   // reason

    // MARK: Review
    var status: SparePartsRequestStatus  // status (default 'Pending')
    var reviewedBy: UUID?                // reviewed_by (FK → staff_members.id)
    var reviewedAt: Date?                // reviewed_at
    var rejectionReason: String?         // rejection_reason
    var fulfilledAt: Date?               // fulfilled_at

    // MARK: Timestamps
    var createdAt: Date                  // created_at
    var updatedAt: Date                  // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case maintenanceTaskId  = "maintenance_task_id"
        case workOrderId        = "work_order_id"
        case requestedById      = "requested_by_id"
        case partName           = "part_name"
        case partNumber         = "part_number"
        case quantity
        case estimatedUnitCost  = "estimated_unit_cost"
        case supplier
        case reason
        case status
        case reviewedBy         = "reviewed_by"
        case reviewedAt         = "reviewed_at"
        case rejectionReason    = "rejection_reason"
        case fulfilledAt        = "fulfilled_at"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }
}

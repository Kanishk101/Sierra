import Foundation

// MARK: - PartUsed
// Maps to table: parts_used

struct PartUsed: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign key
    var workOrderId: UUID               // work_order_id (FK → work_orders.id)

    // MARK: Part details
    var partName: String                // part_name
    var partNumber: String?             // part_number
    var quantity: Int                   // quantity (default 1)
    var unitCost: Double                // unit_cost
    let totalCost: Double               // total_cost (GENERATED)
    var supplier: String?               // supplier

    // MARK: Timestamps
    var createdAt: Date                 // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case workOrderId  = "work_order_id"
        case partName     = "part_name"
        case partNumber   = "part_number"
        case quantity
        case unitCost     = "unit_cost"
        case totalCost    = "total_cost"
        case supplier
        case createdAt    = "created_at"
    }
}

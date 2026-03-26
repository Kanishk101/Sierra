import Foundation

// MARK: - InventoryPart
// Maps to table: inventory_parts

struct InventoryPart: Identifiable, Codable, Hashable {
    let id: UUID

    var partName: String
    var partNumber: String?
    var supplier: String?
    var category: String?
    var unit: String

    var currentQuantity: Int
    var reorderLevel: Int
    var onOrderQuantity: Int
    var expectedArrivalAt: Date?

    var compatibleVehicleIds: [UUID]
    var isActive: Bool

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case partName = "part_name"
        case partNumber = "part_number"
        case supplier
        case category
        case unit
        case currentQuantity = "current_quantity"
        case reorderLevel = "reorder_level"
        case onOrderQuantity = "on_order_quantity"
        case expectedArrivalAt = "expected_arrival_at"
        case compatibleVehicleIds = "compatible_vehicle_ids"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

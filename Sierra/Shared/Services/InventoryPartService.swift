import Foundation
import Supabase

private struct InventoryPartInsertPayload: Encodable {
    let part_name: String
    let part_number: String?
    let supplier: String?
    let category: String?
    let unit: String
    let current_quantity: Int
    let reorder_level: Int
    let on_order_quantity: Int
    let expected_arrival_at: String?
    let compatible_vehicle_ids: [String]
    let is_active: Bool
}

private struct InventoryPartUpdatePayload: Encodable {
    let part_name: String
    let part_number: String?
    let supplier: String?
    let category: String?
    let unit: String
    let current_quantity: Int
    let reorder_level: Int
    let on_order_quantity: Int
    let expected_arrival_at: String?
    let compatible_vehicle_ids: [String]
    let is_active: Bool
}

private let inventoryIso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

struct InventoryPartService {
    static func fetchAllInventoryParts(activeOnly: Bool = true) async throws -> [InventoryPart] {
        if activeOnly {
            return try await supabase
                .from("inventory_parts")
                .select()
                .eq("is_active", value: true)
                .order("part_name", ascending: true)
                .execute()
                .value
        }

        return try await supabase
            .from("inventory_parts")
            .select()
            .order("part_name", ascending: true)
            .execute()
            .value
    }

    static func createInventoryPart(
        partName: String,
        partNumber: String?,
        supplier: String?,
        category: String?,
        unit: String,
        currentQuantity: Int,
        reorderLevel: Int,
        onOrderQuantity: Int,
        expectedArrivalAt: Date?,
        compatibleVehicleIds: [UUID],
        isActive: Bool
    ) async throws -> InventoryPart {
        let payload = InventoryPartInsertPayload(
            part_name: partName,
            part_number: partNumber,
            supplier: supplier,
            category: category,
            unit: unit,
            current_quantity: max(0, currentQuantity),
            reorder_level: max(0, reorderLevel),
            on_order_quantity: max(0, onOrderQuantity),
            expected_arrival_at: expectedArrivalAt.map { inventoryIso.string(from: $0) },
            compatible_vehicle_ids: compatibleVehicleIds.map(\.uuidString),
            is_active: isActive
        )

        return try await supabase
            .from("inventory_parts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    static func updateInventoryPart(
        id: UUID,
        partName: String,
        partNumber: String?,
        supplier: String?,
        category: String?,
        unit: String,
        currentQuantity: Int,
        reorderLevel: Int,
        onOrderQuantity: Int,
        expectedArrivalAt: Date?,
        compatibleVehicleIds: [UUID],
        isActive: Bool
    ) async throws -> InventoryPart {
        let payload = InventoryPartUpdatePayload(
            part_name: partName,
            part_number: partNumber,
            supplier: supplier,
            category: category,
            unit: unit,
            current_quantity: max(0, currentQuantity),
            reorder_level: max(0, reorderLevel),
            on_order_quantity: max(0, onOrderQuantity),
            expected_arrival_at: expectedArrivalAt.map { inventoryIso.string(from: $0) },
            compatible_vehicle_ids: compatibleVehicleIds.map(\.uuidString),
            is_active: isActive
        )

        return try await supabase
            .from("inventory_parts")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    static func deleteInventoryPart(id: UUID) async throws {
        try await supabase
            .from("inventory_parts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

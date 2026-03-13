import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - PartUsedInsertPayload
// Excludes: id, total_cost (GENERATED = quantity * unit_cost), created_at

struct PartUsedInsertPayload: Encodable {
    let workOrderId: String
    let partName: String
    let partNumber: String?
    let quantity: Int
    let unitCost: Double
    let supplier: String?

    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case partName    = "part_name"
        case partNumber  = "part_number"
        case quantity
        case unitCost    = "unit_cost"
        case supplier
    }

    init(from p: PartUsed) {
        workOrderId = p.workOrderId.uuidString
        partName    = p.partName
        partNumber  = p.partNumber
        quantity    = p.quantity
        unitCost    = p.unitCost
        supplier    = p.supplier
    }
}

// MARK: - PartUsedService

struct PartUsedService {

    static func fetchAllPartsUsed() async throws -> [PartUsed] {
        try await supabase
            .from("parts_used")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func fetchPartsUsed(workOrderId: UUID) async throws -> [PartUsed] {
        try await supabase
            .from("parts_used")
            .select()
            .eq("work_order_id", value: workOrderId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func addPartUsed(_ part: PartUsed) async throws {
        try await supabase
            .from("parts_used")
            .insert(PartUsedInsertPayload(from: part))
            .execute()
    }

    static func deletePartUsed(id: UUID) async throws {
        try await supabase
            .from("parts_used")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

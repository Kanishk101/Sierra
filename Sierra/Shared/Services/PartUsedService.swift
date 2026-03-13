import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - PartUsedPayload
// NOTE: total_cost is GENERATED (quantity * unit_cost) — never included in payload.

struct PartUsedPayload: Encodable {
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

    init(from part: PartUsed) {
        self.workOrderId = part.workOrderId.uuidString
        self.partName    = part.partName
        self.partNumber  = part.partNumber
        self.quantity    = part.quantity
        self.unitCost    = part.unitCost
        self.supplier    = part.supplier
    }
}

// MARK: - PartUsedService

struct PartUsedService {

    static func fetchParts(workOrderId: UUID) async throws -> [PartUsed] {
        return try await supabase
            .from("parts_used")
            .select()
            .eq("work_order_id", value: workOrderId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func addPart(_ part: PartUsed) async throws {
        let payload = PartUsedPayload(from: part)
        try await supabase
            .from("parts_used")
            .insert(payload)
            .execute()
    }

    static func updatePart(_ part: PartUsed) async throws {
        let payload = PartUsedPayload(from: part)
        try await supabase
            .from("parts_used")
            .update(payload)
            .eq("id", value: part.id.uuidString)
            .execute()
    }

    static func deletePart(id: UUID) async throws {
        try await supabase
            .from("parts_used")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

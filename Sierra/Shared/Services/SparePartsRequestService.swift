import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - SparePartsRequestService

struct SparePartsRequestService {

    // MARK: Submit

    static func submitRequest(
        maintenanceTaskId: UUID,
        workOrderId: UUID?,
        requestedById: UUID,
        partName: String,
        partNumber: String?,
        quantity: Int,
        estimatedUnitCost: Double?,
        supplier: String?,
        reason: String
    ) async throws {
        struct Payload: Encodable {
            let maintenance_task_id: String
            let work_order_id: String?
            let requested_by_id: String
            let part_name: String
            let part_number: String?
            let quantity: Int
            let estimated_unit_cost: Double?
            let supplier: String?
            let reason: String
            let status: String
        }
        try await supabase
            .from("spare_parts_requests")
            .insert(Payload(
                maintenance_task_id: maintenanceTaskId.uuidString,
                work_order_id: workOrderId?.uuidString,
                requested_by_id: requestedById.uuidString,
                part_name: partName,
                part_number: partNumber,
                quantity: quantity,
                estimated_unit_cost: estimatedUnitCost,
                supplier: supplier,
                reason: reason,
                status: SparePartsRequestStatus.pending.rawValue
            ))
            .execute()
    }

    // MARK: Fetch

    static func fetchRequests(for maintenanceTaskId: UUID) async throws -> [SparePartsRequest] {
        try await supabase
            .from("spare_parts_requests")
            .select()
            .eq("maintenance_task_id", value: maintenanceTaskId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: Approve

    static func approveRequest(id: UUID, reviewedBy: UUID) async throws {
        struct Payload: Encodable {
            let status: String
            let reviewed_by: String
            let reviewed_at: String
        }
        try await supabase
            .from("spare_parts_requests")
            .update(Payload(
                status: SparePartsRequestStatus.approved.rawValue,
                reviewed_by: reviewedBy.uuidString,
                reviewed_at: iso.string(from: Date())
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Reject

    static func rejectRequest(id: UUID, reviewedBy: UUID, reason: String) async throws {
        struct Payload: Encodable {
            let status: String
            let reviewed_by: String
            let reviewed_at: String
            let rejection_reason: String
        }
        try await supabase
            .from("spare_parts_requests")
            .update(Payload(
                status: SparePartsRequestStatus.rejected.rawValue,
                reviewed_by: reviewedBy.uuidString,
                reviewed_at: iso.string(from: Date()),
                rejection_reason: reason
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Fulfill

    static func markFulfilled(id: UUID) async throws {
        struct Payload: Encodable {
            let status: String
            let fulfilled_at: String
        }
        try await supabase
            .from("spare_parts_requests")
            .update(Payload(
                status: SparePartsRequestStatus.fulfilled.rawValue,
                fulfilled_at: iso.string(from: Date())
            ))
            .eq("id", value: id.uuidString)
            .execute()
    }
}

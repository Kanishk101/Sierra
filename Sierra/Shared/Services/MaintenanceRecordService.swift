import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - MaintenanceRecordInsertPayload
// Excludes: id, total_cost (GENERATED), created_at

struct MaintenanceRecordInsertPayload: Encodable {
    let vehicleId: String
    let workOrderId: String
    let maintenanceTaskId: String
    let performedById: String
    let issueReported: String
    let repairDetails: String
    let odometerAtService: Double
    let labourCost: Double
    let partsCost: Double
    let status: String
    let serviceDate: String
    let nextServiceDue: String?

    enum CodingKeys: String, CodingKey {
        case vehicleId         = "vehicle_id"
        case workOrderId       = "work_order_id"
        case maintenanceTaskId = "maintenance_task_id"
        case performedById     = "performed_by_id"
        case issueReported     = "issue_reported"
        case repairDetails     = "repair_details"
        case odometerAtService = "odometer_at_service"
        case labourCost        = "labour_cost"
        case partsCost         = "parts_cost"
        case status
        case serviceDate       = "service_date"
        case nextServiceDue    = "next_service_due"
    }

    init(from r: MaintenanceRecord) {
        vehicleId         = r.vehicleId.uuidString
        workOrderId       = r.workOrderId.uuidString
        maintenanceTaskId = r.maintenanceTaskId.uuidString
        performedById     = r.performedById.uuidString
        issueReported     = r.issueReported
        repairDetails     = r.repairDetails
        odometerAtService = r.odometerAtService
        labourCost        = r.labourCost
        partsCost         = r.partsCost
        status            = r.status.rawValue
        serviceDate       = iso.string(from: r.serviceDate)
        nextServiceDue    = r.nextServiceDue.map { iso.string(from: $0) }
    }
}

// MARK: - MaintenanceRecordService

struct MaintenanceRecordService {

    static func fetchAllMaintenanceRecords(limit: Int = 500) async throws -> [MaintenanceRecord] {
        try await supabase
            .from("maintenance_records")
            .select()
            .order("service_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchMaintenanceRecords(vehicleId: UUID) async throws -> [MaintenanceRecord] {
        try await supabase
            .from("maintenance_records")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("service_date", ascending: false)
            .execute()
            .value
    }

    static func fetchMaintenanceRecords(performedById: UUID) async throws -> [MaintenanceRecord] {
        try await supabase
            .from("maintenance_records")
            .select()
            .eq("performed_by_id", value: performedById.uuidString)
            .order("service_date", ascending: false)
            .execute()
            .value
    }

    static func addMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await supabase
            .from("maintenance_records")
            .insert(MaintenanceRecordInsertPayload(from: record))
            .execute()
    }

    static func updateMaintenanceRecord(_ record: MaintenanceRecord) async throws {
        try await supabase
            .from("maintenance_records")
            .update(MaintenanceRecordInsertPayload(from: record))
            .eq("id", value: record.id.uuidString)
            .execute()
    }

    static func deleteMaintenanceRecord(id: UUID) async throws {
        try await supabase
            .from("maintenance_records")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

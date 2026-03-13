import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - MaintenanceRecordPayload
// NOTE: total_cost is GENERATED (labour_cost + parts_cost) — never included in payload.

struct MaintenanceRecordPayload: Encodable {
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

    init(from record: MaintenanceRecord) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.vehicleId         = record.vehicleId.uuidString
        self.workOrderId       = record.workOrderId.uuidString
        self.maintenanceTaskId = record.maintenanceTaskId.uuidString
        self.performedById     = record.performedById.uuidString
        self.issueReported     = record.issueReported
        self.repairDetails     = record.repairDetails
        self.odometerAtService = record.odometerAtService
        self.labourCost        = record.labourCost
        self.partsCost         = record.partsCost
        self.status            = record.status.rawValue
        self.serviceDate       = fmt.string(from: record.serviceDate)
        self.nextServiceDue    = record.nextServiceDue.map { fmt.string(from: $0) }
    }
}

// MARK: - MaintenanceRecordService

struct MaintenanceRecordService {

    static func fetchAllRecords() async throws -> [MaintenanceRecord] {
        return try await supabase
            .from("maintenance_records")
            .select()
            .order("service_date", ascending: false)
            .execute()
            .value
    }

    static func fetchRecords(vehicleId: UUID) async throws -> [MaintenanceRecord] {
        return try await supabase
            .from("maintenance_records")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("service_date", ascending: false)
            .execute()
            .value
    }

    static func fetchRecord(workOrderId: UUID) async throws -> MaintenanceRecord {
        return try await supabase
            .from("maintenance_records")
            .select()
            .eq("work_order_id", value: workOrderId.uuidString)
            .single()
            .execute()
            .value
    }

    static func addRecord(_ record: MaintenanceRecord) async throws {
        let payload = MaintenanceRecordPayload(from: record)
        try await supabase
            .from("maintenance_records")
            .insert(payload)
            .execute()
    }

    static func updateRecord(_ record: MaintenanceRecord) async throws {
        let payload = MaintenanceRecordPayload(from: record)
        try await supabase
            .from("maintenance_records")
            .update(payload)
            .eq("id", value: record.id.uuidString)
            .execute()
    }

    static func deleteRecord(id: UUID) async throws {
        try await supabase
            .from("maintenance_records")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

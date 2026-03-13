import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - VehicleInspectionInsertPayload
// items is encoded as a JSON string for the JSONB column.
// Excludes: id, created_at

struct VehicleInspectionInsertPayload: Encodable {
    let tripId: String
    let vehicleId: String
    let driverId: String
    let type: String
    let overallResult: String
    let items: String          // JSON-encoded [InspectionItem]
    let defectsReported: String?
    let additionalNotes: String?
    let driverSignatureUrl: String?
    let inspectedAt: String

    enum CodingKeys: String, CodingKey {
        case tripId             = "trip_id"
        case vehicleId          = "vehicle_id"
        case driverId           = "driver_id"
        case type
        case overallResult      = "overall_result"
        case items
        case defectsReported    = "defects_reported"
        case additionalNotes    = "additional_notes"
        case driverSignatureUrl = "driver_signature_url"
        case inspectedAt        = "inspected_at"
    }

    init(from i: VehicleInspection) throws {
        let itemsData = try JSONEncoder().encode(i.items)
        let itemsString = String(data: itemsData, encoding: .utf8) ?? "[]"
        tripId             = i.tripId.uuidString
        vehicleId          = i.vehicleId.uuidString
        driverId           = i.driverId.uuidString
        type               = i.type.rawValue
        overallResult      = i.overallResult.rawValue
        items              = itemsString
        defectsReported    = i.defectsReported
        additionalNotes    = i.additionalNotes
        driverSignatureUrl = i.driverSignatureUrl
        inspectedAt        = iso.string(from: i.inspectedAt)
    }
}

// MARK: - VehicleInspectionService

struct VehicleInspectionService {

    static func fetchAllInspections() async throws -> [VehicleInspection] {
        try await supabase
            .from("vehicle_inspections")
            .select()
            .order("inspected_at", ascending: false)
            .execute()
            .value
    }

    static func fetchInspections(tripId: UUID) async throws -> [VehicleInspection] {
        try await supabase
            .from("vehicle_inspections")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .order("inspected_at", ascending: true)
            .execute()
            .value
    }

    static func fetchInspections(vehicleId: UUID) async throws -> [VehicleInspection] {
        try await supabase
            .from("vehicle_inspections")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("inspected_at", ascending: false)
            .execute()
            .value
    }

    static func fetchInspection(id: UUID) async throws -> VehicleInspection? {
        let rows: [VehicleInspection] = try await supabase
            .from("vehicle_inspections")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func addInspection(_ inspection: VehicleInspection) async throws {
        let payload = try VehicleInspectionInsertPayload(from: inspection)
        try await supabase
            .from("vehicle_inspections")
            .insert(payload)
            .execute()
    }

    static func updateInspection(_ inspection: VehicleInspection) async throws {
        let payload = try VehicleInspectionInsertPayload(from: inspection)
        try await supabase
            .from("vehicle_inspections")
            .update(payload)
            .eq("id", value: inspection.id.uuidString)
            .execute()
    }

    static func deleteInspection(id: UUID) async throws {
        try await supabase
            .from("vehicle_inspections")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

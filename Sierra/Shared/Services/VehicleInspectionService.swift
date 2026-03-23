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

    // MARK: - Submit With Photos

    static func submitInspectionWithPhotos(
        tripId: UUID,
        vehicleId: UUID,
        driverId: UUID,
        type: InspectionType,
        overallResult: InspectionResult,
        items: [InspectionItem],
        defectsReported: String?,
        additionalNotes: String?,
        driverSignatureUrl: String?,
        photoUrls: [String],
        odometerReading: Double?,
        fuelReceiptUrl: String?,
        isDefectRaised: Bool,
        raisedTaskId: UUID?
    ) async throws -> VehicleInspection {
        struct Payload: Encodable {
            let trip_id: String
            let vehicle_id: String
            let driver_id: String
            let type: String
            let overall_result: String
            let items: String           // JSON-encoded [InspectionItem]
            let defects_reported: String?
            let additional_notes: String?
            let driver_signature_url: String?
            let photo_urls: [String]    // Swift array — SDK handles serialisation
            let odometer_reading: Double?
            let fuel_receipt_url: String?
            let is_defect_raised: Bool
            let raised_task_id: String?
            let inspected_at: String
        }

        let itemsData = try JSONEncoder().encode(items)
        let itemsString = String(data: itemsData, encoding: .utf8) ?? "[]"
        let now = Date()

        let payload = Payload(
            trip_id: tripId.uuidString,
            vehicle_id: vehicleId.uuidString,
            driver_id: driverId.uuidString,
            type: type.rawValue,
            overall_result: overallResult.rawValue,
            items: itemsString,
            defects_reported: defectsReported,
            additional_notes: additionalNotes,
            driver_signature_url: driverSignatureUrl,
            photo_urls: photoUrls,
            odometer_reading: odometerReading,
            fuel_receipt_url: fuelReceiptUrl,
            is_defect_raised: isDefectRaised,
            raised_task_id: raisedTaskId?.uuidString,
            inspected_at: iso.string(from: now)
        )

        let rows: [VehicleInspection] = try await supabase
            .from("vehicle_inspections")
            .insert(payload)
            .select()
            .execute()
            .value

        guard let inspection = rows.first else {
            throw NSError(domain: "VehicleInspectionService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Insert returned no rows"])
        }
        return inspection
    }
}

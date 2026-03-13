import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - VehicleInspectionPayload

struct VehicleInspectionPayload: Encodable {
    let tripId: String
    let vehicleId: String
    let driverId: String
    let type: String
    let overallResult: String
    let items: [InspectionItem]
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

    init(from inspection: VehicleInspection) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.tripId             = inspection.tripId.uuidString
        self.vehicleId          = inspection.vehicleId.uuidString
        self.driverId           = inspection.driverId.uuidString
        self.type               = inspection.type.rawValue
        self.overallResult      = inspection.overallResult.rawValue
        self.items              = inspection.items
        self.defectsReported    = inspection.defectsReported
        self.additionalNotes    = inspection.additionalNotes
        self.driverSignatureUrl = inspection.driverSignatureUrl
        self.inspectedAt        = fmt.string(from: inspection.inspectedAt)
    }
}

// MARK: - VehicleInspectionService

struct VehicleInspectionService {

    static func fetchAllInspections() async throws -> [VehicleInspection] {
        return try await supabase
            .from("vehicle_inspections")
            .select()
            .order("inspected_at", ascending: false)
            .execute()
            .value
    }

    static func fetchInspections(tripId: UUID) async throws -> [VehicleInspection] {
        return try await supabase
            .from("vehicle_inspections")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .order("inspected_at", ascending: true)
            .execute()
            .value
    }

    static func fetchInspections(vehicleId: UUID) async throws -> [VehicleInspection] {
        return try await supabase
            .from("vehicle_inspections")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("inspected_at", ascending: false)
            .execute()
            .value
    }

    static func addInspection(_ inspection: VehicleInspection) async throws {
        let payload = VehicleInspectionPayload(from: inspection)
        try await supabase
            .from("vehicle_inspections")
            .insert(payload)
            .execute()
    }

    static func updateInspection(_ inspection: VehicleInspection) async throws {
        let payload = VehicleInspectionPayload(from: inspection)
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

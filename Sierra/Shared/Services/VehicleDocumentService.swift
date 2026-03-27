import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - VehicleDocumentInsertPayload
// Excludes: id, created_at, updated_at

struct VehicleDocumentInsertPayload: Encodable {
    let vehicleId: String
    let documentType: String
    let documentNumber: String
    let issuedDate: String
    let expiryDate: String
    let issuingAuthority: String
    let documentUrl: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case vehicleId        = "vehicle_id"
        case documentType     = "document_type"
        case documentNumber   = "document_number"
        case issuedDate       = "issued_date"
        case expiryDate       = "expiry_date"
        case issuingAuthority = "issuing_authority"
        case documentUrl      = "document_url"
        case notes
    }

    init(from d: VehicleDocument) {
        vehicleId        = d.vehicleId.uuidString
        documentType     = d.documentType.rawValue
        documentNumber   = d.documentNumber
        issuedDate       = iso.string(from: d.issuedDate)
        expiryDate       = iso.string(from: d.expiryDate)
        issuingAuthority = d.issuingAuthority
        documentUrl      = d.documentUrl
        notes            = d.notes
    }
}

// MARK: - VehicleDocumentService

struct VehicleDocumentService {
    static let storageBucket = "vehicle-documents"

    static func fetchAllVehicleDocuments() async throws -> [VehicleDocument] {
        try await supabase
            .from("vehicle_documents")
            .select()
            .order("expiry_date", ascending: true)
            .execute()
            .value
    }

    static func fetchVehicleDocuments(vehicleId: UUID) async throws -> [VehicleDocument] {
        try await supabase
            .from("vehicle_documents")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("expiry_date", ascending: true)
            .execute()
            .value
    }

    static func fetchExpiringDocuments(withinDays days: Int) async throws -> [VehicleDocument] {
        let cutoff = Date().addingTimeInterval(Double(days) * 86400)
        return try await supabase
            .from("vehicle_documents")
            .select()
            .lte("expiry_date", value: iso.string(from: cutoff))
            .gte("expiry_date", value: iso.string(from: Date()))
            .order("expiry_date", ascending: true)
            .execute()
            .value
    }

    static func addVehicleDocument(_ doc: VehicleDocument) async throws {
        try await supabase
            .from("vehicle_documents")
            .insert(VehicleDocumentInsertPayload(from: doc))
            .execute()
    }

    static func updateVehicleDocument(_ doc: VehicleDocument) async throws {
        try await supabase
            .from("vehicle_documents")
            .update(VehicleDocumentInsertPayload(from: doc))
            .eq("id", value: doc.id.uuidString)
            .execute()
    }

    static func deleteVehicleDocument(id: UUID) async throws {
        try await supabase
            .from("vehicle_documents")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func uploadVehicleDocument(
        data: Data,
        fileExtension: String,
        vehicleId: UUID,
        documentType: VehicleDocumentType
    ) async throws -> String {
        let ext = fileExtension.lowercased()
        let mimeType: String = switch ext {
        case "pdf": "application/pdf"
        case "png": "image/png"
        case "webp": "image/webp"
        case "heic": "image/heic"
        case "heif": "image/heif"
        default: "image/jpeg"
        }

        let safeType = documentType.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
        let path = "\(vehicleId.uuidString)/\(safeType)/\(UUID().uuidString).\(ext)"
        try await supabase.storage
            .from(storageBucket)
            .upload(path, data: data, options: .init(contentType: mimeType, upsert: true))
        return try supabase.storage
            .from(storageBucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    static func resolveDocumentURL(storedValue: String) -> URL? {
        if let direct = URL(string: storedValue), direct.scheme != nil {
            return direct
        }
        return try? supabase.storage
            .from(storageBucket)
            .getPublicURL(path: storedValue)
    }
}

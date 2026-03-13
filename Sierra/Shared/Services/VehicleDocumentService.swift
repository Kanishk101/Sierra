import Foundation
import Supabase

private let supabase = SupabaseManager.shared.client

// MARK: - VehicleDocumentPayload

struct VehicleDocumentPayload: Encodable {
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

    init(from doc: VehicleDocument) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.vehicleId        = doc.vehicleId.uuidString
        self.documentType     = doc.documentType.rawValue
        self.documentNumber   = doc.documentNumber
        self.issuedDate       = fmt.string(from: doc.issuedDate)
        self.expiryDate       = fmt.string(from: doc.expiryDate)
        self.issuingAuthority = doc.issuingAuthority
        self.documentUrl      = doc.documentUrl
        self.notes            = doc.notes
    }
}

// MARK: - VehicleDocumentService

struct VehicleDocumentService {

    static func fetchAllDocuments() async throws -> [VehicleDocument] {
        return try await supabase
            .from("vehicle_documents")
            .select()
            .order("expiry_date", ascending: true)
            .execute()
            .value
    }

    static func fetchDocuments(vehicleId: UUID) async throws -> [VehicleDocument] {
        return try await supabase
            .from("vehicle_documents")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("expiry_date", ascending: true)
            .execute()
            .value
    }

    /// Fetch all documents expiring within the next `withinDays` days (server-side filter).
    static func fetchExpiringSoon(withinDays: Int) async throws -> [VehicleDocument] {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cutoff = Date().addingTimeInterval(Double(withinDays) * 86400)
        let cutoffString = fmt.string(from: cutoff)
        return try await supabase
            .from("vehicle_documents")
            .select()
            .lte("expiry_date", value: cutoffString)
            .gte("expiry_date", value: fmt.string(from: Date()))
            .order("expiry_date", ascending: true)
            .execute()
            .value
    }

    static func addDocument(_ doc: VehicleDocument) async throws {
        let payload = VehicleDocumentPayload(from: doc)
        try await supabase
            .from("vehicle_documents")
            .insert(payload)
            .execute()
    }

    static func updateDocument(_ doc: VehicleDocument) async throws {
        let payload = VehicleDocumentPayload(from: doc)
        try await supabase
            .from("vehicle_documents")
            .update(payload)
            .eq("id", value: doc.id.uuidString)
            .execute()
    }

    static func deleteDocument(id: UUID) async throws {
        try await supabase
            .from("vehicle_documents")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

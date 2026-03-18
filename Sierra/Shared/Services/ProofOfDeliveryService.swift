import Foundation
import Supabase

// Uses global `supabase` constant from SupabaseManager.swift

// MARK: - ProofOfDeliveryPayload

struct ProofOfDeliveryPayload: Encodable {
    let tripId: String
    let driverId: String
    let method: String
    let photoUrl: String?
    let signatureUrl: String?
    let otpVerified: Bool
    let recipientName: String?
    let deliveryLatitude: Double?
    let deliveryLongitude: Double?
    let deliveryOtpHash: String?
    let deliveryOtpExpiresAt: String?
    let capturedAt: String

    enum CodingKeys: String, CodingKey {
        case tripId            = "trip_id"
        case driverId          = "driver_id"
        case method
        case photoUrl          = "photo_url"
        case signatureUrl      = "signature_url"
        case otpVerified       = "otp_verified"
        case recipientName     = "recipient_name"
        case deliveryLatitude  = "delivery_latitude"
        case deliveryLongitude = "delivery_longitude"
        case deliveryOtpHash   = "delivery_otp_hash"
        case deliveryOtpExpiresAt = "delivery_otp_expires_at"
        case capturedAt        = "captured_at"
    }

    init(from pod: ProofOfDelivery) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.tripId            = pod.tripId.uuidString
        self.driverId          = pod.driverId.uuidString
        self.method            = pod.method.rawValue
        self.photoUrl          = pod.photoUrl
        self.signatureUrl      = pod.signatureUrl
        self.otpVerified       = pod.otpVerified
        self.recipientName     = pod.recipientName
        self.deliveryLatitude  = pod.deliveryLatitude
        self.deliveryLongitude = pod.deliveryLongitude
        self.deliveryOtpHash   = pod.deliveryOtpHash
        self.deliveryOtpExpiresAt = pod.deliveryOtpExpiresAt.map { fmt.string(from: $0) }
        self.capturedAt        = fmt.string(from: pod.capturedAt)
    }
}

// MARK: - ProofOfDeliveryService

struct ProofOfDeliveryService {

    static func fetchAllProofsOfDelivery() async throws -> [ProofOfDelivery] {
        return try await supabase
            .from("proof_of_deliveries")
            .select()
            .order("captured_at", ascending: false)
            .execute()
            .value
    }

    static func fetchProofOfDelivery(tripId: UUID) async throws -> ProofOfDelivery? {
        let rows: [ProofOfDelivery] = try await supabase
            .from("proof_of_deliveries")
            .select()
            .eq("trip_id", value: tripId.uuidString)
            .execute()
            .value
        return rows.first
    }

    static func addProofOfDelivery(_ pod: ProofOfDelivery) async throws {
        let payload = ProofOfDeliveryPayload(from: pod)
        try await supabase
            .from("proof_of_deliveries")
            .insert(payload)
            .execute()
    }

    static func updateProofOfDelivery(_ pod: ProofOfDelivery) async throws {
        let payload = ProofOfDeliveryPayload(from: pod)
        try await supabase
            .from("proof_of_deliveries")
            .update(payload)
            .eq("id", value: pod.id.uuidString)
            .execute()
    }

    static func deleteProofOfDelivery(id: UUID) async throws {
        try await supabase
            .from("proof_of_deliveries")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

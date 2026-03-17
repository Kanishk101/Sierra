import Foundation

// MARK: - Proof of Delivery Method
// Maps to PostgreSQL enum: proof_of_delivery_method

enum ProofOfDeliveryMethod: String, Codable, CaseIterable {
    case photo           = "Photo"
    case signature       = "Signature"
    case otpVerification = "OTP Verification"
}

// MARK: - ProofOfDelivery
// Maps to table: proof_of_deliveries

struct ProofOfDelivery: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var tripId: UUID                     // trip_id (FK → trips.id, UNIQUE)
    var driverId: UUID                   // driver_id (FK → staff_members.id)

    // MARK: Delivery details
    var method: ProofOfDeliveryMethod    // method
    var photoUrl: String?                // photo_url
    var signatureUrl: String?            // signature_url
    var otpVerified: Bool                // otp_verified (default false)
    var recipientName: String?           // recipient_name
    var deliveryLatitude: Double?        // delivery_latitude
    var deliveryLongitude: Double?       // delivery_longitude

    // MARK: OTP & notes
    var deliveryOtpHash: String?         // delivery_otp_hash
    var deliveryOtpExpiresAt: Date?      // delivery_otp_expires_at
    var notes: String?                   // notes

    // MARK: Timestamps
    var capturedAt: Date                 // captured_at
    var createdAt: Date                  // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case tripId             = "trip_id"
        case driverId           = "driver_id"
        case method
        case photoUrl           = "photo_url"
        case signatureUrl       = "signature_url"
        case otpVerified        = "otp_verified"
        case recipientName      = "recipient_name"
        case deliveryLatitude   = "delivery_latitude"
        case deliveryLongitude  = "delivery_longitude"
        case deliveryOtpHash    = "delivery_otp_hash"
        case deliveryOtpExpiresAt = "delivery_otp_expires_at"
        case notes
        case capturedAt         = "captured_at"
        case createdAt          = "created_at"
    }
}

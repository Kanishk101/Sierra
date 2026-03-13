import Foundation

// MARK: - Staff Status
// Maps to PostgreSQL enum: staff_status
// Values: Active | Pending Approval | Suspended

enum StaffStatus: String, Codable, CaseIterable {
    case active          = "Active"
    case pendingApproval = "Pending Approval"
    case suspended       = "Suspended"
}

// MARK: - Staff Availability
// Maps to PostgreSQL enum: staff_availability
// Values: Available | Unavailable | On Trip | On Task

enum StaffAvailability: String, Codable, CaseIterable {
    case available   = "Available"
    case unavailable = "Unavailable"
    case onTrip      = "On Trip"
    case onTask      = "On Task"
}

// MARK: - StaffMember
// Maps to table: staff_members

struct StaffMember: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID                         // auth.users.id

    // MARK: Core fields
    var name: String?                    // name (nullable in DB)
    var role: UserRole                   // role (user_role enum)
    var status: StaffStatus              // status
    var email: String                    // email
    var phone: String?                   // phone
    var availability: StaffAvailability  // availability

    // MARK: Personal information
    var dateOfBirth: Date?               // date_of_birth (date)
    var gender: String?                  // gender
    var address: String?                 // address
    var emergencyContactName: String?    // emergency_contact_name
    var emergencyContactPhone: String?   // emergency_contact_phone
    var aadhaarNumber: String?           // aadhaar_number

    // MARK: Profile
    var profilePhotoUrl: String?         // profile_photo_url

    // MARK: Flags
    var isFirstLogin: Bool               // is_first_login
    var isProfileComplete: Bool          // is_profile_complete
    var isApproved: Bool                 // is_approved
    var rejectionReason: String?         // rejection_reason

    // MARK: Timestamps
    var joinedDate: Date?                // joined_date (timestamptz)
    var createdAt: Date                  // created_at
    var updatedAt: Date                  // updated_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case status
        case email
        case phone
        case availability
        case dateOfBirth              = "date_of_birth"
        case gender
        case address
        case emergencyContactName     = "emergency_contact_name"
        case emergencyContactPhone    = "emergency_contact_phone"
        case aadhaarNumber            = "aadhaar_number"
        case profilePhotoUrl          = "profile_photo_url"
        case isFirstLogin             = "is_first_login"
        case isProfileComplete        = "is_profile_complete"
        case isApproved               = "is_approved"
        case rejectionReason          = "rejection_reason"
        case joinedDate               = "joined_date"
        case createdAt                = "created_at"
        case updatedAt                = "updated_at"
    }

    // MARK: - Computed Properties

    var displayName: String { name ?? email }

    var initials: String {
        guard let n = name else {
            return String(email.prefix(2)).uppercased()
        }
        let parts = n.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Mock Data

    static let samples: [StaffMember] = [
        StaffMember(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000001")!,
            name: "James Turner",
            role: .driver,
            status: .active,
            email: "james@fleet.com",
            phone: "+91 98765 43210",
            availability: .available,
            dateOfBirth: nil,
            gender: "Male",
            address: nil,
            emergencyContactName: nil,
            emergencyContactPhone: nil,
            aadhaarNumber: nil,
            profilePhotoUrl: nil,
            isFirstLogin: false,
            isProfileComplete: true,
            isApproved: true,
            rejectionReason: nil,
            joinedDate: Date().addingTimeInterval(-86400 * 120),
            createdAt: Date().addingTimeInterval(-86400 * 120),
            updatedAt: Date().addingTimeInterval(-86400 * 1)
        ),
        StaffMember(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000002")!,
            name: "Maria Chen",
            role: .driver,
            status: .active,
            email: "maria@fleet.com",
            phone: "+91 91234 56789",
            availability: .available,
            dateOfBirth: nil,
            gender: "Female",
            address: nil,
            emergencyContactName: nil,
            emergencyContactPhone: nil,
            aadhaarNumber: nil,
            profilePhotoUrl: nil,
            isFirstLogin: false,
            isProfileComplete: true,
            isApproved: true,
            rejectionReason: nil,
            joinedDate: Date().addingTimeInterval(-86400 * 90),
            createdAt: Date().addingTimeInterval(-86400 * 90),
            updatedAt: Date().addingTimeInterval(-86400 * 1)
        ),
        StaffMember(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000003")!,
            name: "David Park",
            role: .driver,
            status: .pendingApproval,
            email: "david@fleet.com",
            phone: "+91 87654 32100",
            availability: .unavailable,
            dateOfBirth: nil,
            gender: "Male",
            address: nil,
            emergencyContactName: nil,
            emergencyContactPhone: nil,
            aadhaarNumber: nil,
            profilePhotoUrl: nil,
            isFirstLogin: true,
            isProfileComplete: false,
            isApproved: false,
            rejectionReason: nil,
            joinedDate: Date().addingTimeInterval(-86400 * 3),
            createdAt: Date().addingTimeInterval(-86400 * 3),
            updatedAt: Date().addingTimeInterval(-86400 * 3)
        ),
        StaffMember(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000004")!,
            name: "Sarah Miller",
            role: .maintenancePersonnel,
            status: .active,
            email: "sarah@fleet.com",
            phone: "+91 99887 76655",
            availability: .available,
            dateOfBirth: nil,
            gender: "Female",
            address: nil,
            emergencyContactName: nil,
            emergencyContactPhone: nil,
            aadhaarNumber: nil,
            profilePhotoUrl: nil,
            isFirstLogin: false,
            isProfileComplete: true,
            isApproved: true,
            rejectionReason: nil,
            joinedDate: Date().addingTimeInterval(-86400 * 200),
            createdAt: Date().addingTimeInterval(-86400 * 200),
            updatedAt: Date().addingTimeInterval(-86400 * 2)
        ),
        StaffMember(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000005")!,
            name: "Ahmed Khan",
            role: .maintenancePersonnel,
            status: .active,
            email: "ahmed@fleet.com",
            phone: "+91 88776 65544",
            availability: .available,
            dateOfBirth: nil,
            gender: "Male",
            address: nil,
            emergencyContactName: nil,
            emergencyContactPhone: nil,
            aadhaarNumber: nil,
            profilePhotoUrl: nil,
            isFirstLogin: false,
            isProfileComplete: true,
            isApproved: true,
            rejectionReason: nil,
            joinedDate: Date().addingTimeInterval(-86400 * 60),
            createdAt: Date().addingTimeInterval(-86400 * 60),
            updatedAt: Date().addingTimeInterval(-86400 * 1)
        ),
        StaffMember(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000006")!,
            name: "Lisa Wong",
            role: .driver,
            status: .suspended,
            email: "lisa@fleet.com",
            phone: "+91 77665 54433",
            availability: .unavailable,
            dateOfBirth: nil,
            gender: "Female",
            address: nil,
            emergencyContactName: nil,
            emergencyContactPhone: nil,
            aadhaarNumber: nil,
            profilePhotoUrl: nil,
            isFirstLogin: false,
            isProfileComplete: true,
            isApproved: false,
            rejectionReason: "Policy violation",
            joinedDate: Date().addingTimeInterval(-86400 * 180),
            createdAt: Date().addingTimeInterval(-86400 * 180),
            updatedAt: Date().addingTimeInterval(-86400 * 30)
        ),
        StaffMember(
            id: UUID(uuidString: "D0000000-0000-0000-0000-000000000007")!,
            name: "Tom Bradley",
            role: .maintenancePersonnel,
            status: .pendingApproval,
            email: "tom@fleet.com",
            phone: "+91 66554 43322",
            availability: .unavailable,
            dateOfBirth: nil,
            gender: "Male",
            address: nil,
            emergencyContactName: nil,
            emergencyContactPhone: nil,
            aadhaarNumber: nil,
            profilePhotoUrl: nil,
            isFirstLogin: true,
            isProfileComplete: false,
            isApproved: false,
            rejectionReason: nil,
            joinedDate: Date().addingTimeInterval(-86400 * 5),
            createdAt: Date().addingTimeInterval(-86400 * 5),
            updatedAt: Date().addingTimeInterval(-86400 * 5)
        ),
    ]
}

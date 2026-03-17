import Foundation

// MARK: - StaffRole
// UI-only enum — used exclusively for the segmented picker in StaffListView.
// Never stored to Supabase. Use `asUserRole` to bridge to the authoritative UserRole.

enum StaffRole: CaseIterable {
    case driver
    case maintenance

    var displayLabel: String {
        switch self {
        case .driver:      "Drivers"
        case .maintenance: "Maintenance"
        }
    }

    /// Maps to the corresponding UserRole for filtering staff_members by role
    var asUserRole: UserRole {
        switch self {
        case .driver:      .driver
        case .maintenance: .maintenancePersonnel
        }
    }
}

// MARK: - Staff Status
// Maps to PostgreSQL enum: staff_status

enum StaffStatus: String, Codable, CaseIterable {
    case active          = "Active"
    case pendingApproval = "Pending Approval"
    case suspended       = "Suspended"
}

// MARK: - Staff Availability
// Maps to PostgreSQL enum: staff_availability

enum StaffAvailability: String, Codable, CaseIterable {
    case available   = "Available"
    case busy        = "Busy"
    case unavailable = "Unavailable"
    case onTrip      = "On Trip"   // legacy — read-only, never written by new code
    case onTask      = "On Task"
}

// MARK: - StaffMember
// Maps to table: staff_members

struct StaffMember: Identifiable, Codable {
    // MARK: Primary key (same UUID as auth.users.id)
    let id: UUID

    // MARK: Core fields
    var name: String?                    // nullable in DB — optional for decode safety
    var role: UserRole                   // user_role enum
    var status: StaffStatus
    var email: String
    var phone: String?                   // nullable in DB
    var availability: StaffAvailability

    // MARK: Personal information (nullable — populated after onboarding)
    var dateOfBirth: String?
    var gender: String?          
    var address: String?
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var aadhaarNumber: String?

    // MARK: Profile
    var profilePhotoUrl: String?

    // MARK: Flags
    var isFirstLogin: Bool
    var isProfileComplete: Bool
    var isApproved: Bool
    var rejectionReason: String?

    // MARK: Security
    var failedLoginAttempts: Int = 0      // failed_login_attempts (default 0)
    var accountLockedUntil: Date?         // account_locked_until

    // MARK: Timestamps
    var joinedDate: Date?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name, role, status, email, phone, availability
        case dateOfBirth              = "date_of_birth"
        case gender, address
        case emergencyContactName     = "emergency_contact_name"
        case emergencyContactPhone    = "emergency_contact_phone"
        case aadhaarNumber            = "aadhaar_number"
        case profilePhotoUrl          = "profile_photo_url"
        case isFirstLogin             = "is_first_login"
        case isProfileComplete        = "is_profile_complete"
        case isApproved               = "is_approved"
        case rejectionReason          = "rejection_reason"
        case failedLoginAttempts      = "failed_login_attempts"
        case accountLockedUntil       = "account_locked_until"
        case joinedDate               = "joined_date"
        case createdAt                = "created_at"
        case updatedAt                = "updated_at"
    }

    // MARK: - Computed Properties

    var displayName: String { name ?? email }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    var displayRole: String {
        switch role {
        case .fleetManager:         "Fleet Manager"
        case .driver:               "Driver"
        case .maintenancePersonnel: "Maintenance"
        }
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
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
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
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
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
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
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
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
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
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
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
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
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
            failedLoginAttempts: 0,
            accountLockedUntil: nil,
            joinedDate: Date().addingTimeInterval(-86400 * 5),
            createdAt: Date().addingTimeInterval(-86400 * 5),
            updatedAt: Date().addingTimeInterval(-86400 * 5)
        ),
    ]
}

import Foundation
import SwiftUI

enum ApprovalStatus: String, CaseIterable {
    case pending  = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
}

struct StaffApplication: Identifiable {
    let id: UUID
    let name: String
    let email: String
    let role: UserRole
    let submittedDate: Date
    var status: ApprovalStatus
    var rejectionReason: String?

    // Personal details (for review)
    var phone: String
    var dateOfBirth: Date
    var gender: String
    var address: String
    var emergencyName: String
    var emergencyPhone: String

    // ── Driver-specific ──
    var aadhaarNumber: String
    var licenseNumber: String
    var licenseExpiry: Date

    // ── Maintenance-specific ──
    var certificationType: String?
    var certificationNumber: String?
    var issuingAuthority: String?
    var certExpiry: Date?
    var yearsOfExperience: Int?
    var specializations: [String]?

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    var daysAgo: String {
        let days = Calendar.current.dateComponents([.day], from: submittedDate, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    static let samples: [StaffApplication] = [
        // Driver sample (pending)
        StaffApplication(
            id: UUID(), name: "David Park", email: "david@fleet.com",
            role: .driver, submittedDate: Date().addingTimeInterval(-86400 * 2),
            status: .pending, rejectionReason: nil,
            phone: "+91 9876543210", dateOfBirth: Date().addingTimeInterval(-86400 * 365 * 28),
            gender: "Male", address: "42 Fleet Street, Mumbai 400001",
            emergencyName: "Jin Park", emergencyPhone: "+91 9876543211",
            aadhaarNumber: "2345 6789 0123", licenseNumber: "MH-0120230045678",
            licenseExpiry: Date().addingTimeInterval(86400 * 365 * 2),
            certificationType: nil, certificationNumber: nil, issuingAuthority: nil,
            certExpiry: nil, yearsOfExperience: nil, specializations: nil
        ),
        // Maintenance sample (pending)
        StaffApplication(
            id: UUID(), name: "Tom Bradley", email: "tom@fleet.com",
            role: .maintenancePersonnel, submittedDate: Date().addingTimeInterval(-86400 * 4),
            status: .pending, rejectionReason: nil,
            phone: "+91 8765432109", dateOfBirth: Date().addingTimeInterval(-86400 * 365 * 32),
            gender: "Male", address: "15 Workshop Lane, Pune 411001",
            emergencyName: "Sarah Bradley", emergencyPhone: "+91 8765432100",
            aadhaarNumber: "3456 7890 1234", licenseNumber: "",
            licenseExpiry: Date(),
            certificationType: "Diesel Mechanic", certificationNumber: "DM-2024-78901",
            issuingAuthority: "NSDC India", certExpiry: Date().addingTimeInterval(86400 * 365),
            yearsOfExperience: 8, specializations: ["Engine Repair", "Transmission", "Tyres"]
        ),
        // Driver sample (approved)
        StaffApplication(
            id: UUID(), name: "Priya Sharma", email: "priya@fleet.com",
            role: .driver, submittedDate: Date().addingTimeInterval(-86400 * 10),
            status: .approved, rejectionReason: nil,
            phone: "+91 7654321098", dateOfBirth: Date().addingTimeInterval(-86400 * 365 * 25),
            gender: "Female", address: "8 Ring Road, Delhi 110001",
            emergencyName: "Raj Sharma", emergencyPhone: "+91 7654321099",
            aadhaarNumber: "4567 8901 2345", licenseNumber: "DL-0120210012345",
            licenseExpiry: Date().addingTimeInterval(86400 * 365 * 3),
            certificationType: nil, certificationNumber: nil, issuingAuthority: nil,
            certExpiry: nil, yearsOfExperience: nil, specializations: nil
        ),
    ]
}

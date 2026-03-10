import Foundation

enum StaffRole: String {
    case driver = "Driver"
    case maintenance = "Maintenance"
}

enum StaffStatus: String {
    case active = "Active"
    case pendingApproval = "Pending Approval"
    case suspended = "Suspended"
}

struct StaffMember: Identifiable {
    let id: UUID
    let name: String
    let role: StaffRole
    var status: StaffStatus
    let email: String
    let joinedDate: Date

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    static let samples: [StaffMember] = [
        StaffMember(id: UUID(), name: "James Turner", role: .driver, status: .active, email: "james@fleet.com", joinedDate: Date().addingTimeInterval(-86400 * 120)),
        StaffMember(id: UUID(), name: "Maria Chen", role: .driver, status: .active, email: "maria@fleet.com", joinedDate: Date().addingTimeInterval(-86400 * 90)),
        StaffMember(id: UUID(), name: "David Park", role: .driver, status: .pendingApproval, email: "david@fleet.com", joinedDate: Date().addingTimeInterval(-86400 * 3)),
        StaffMember(id: UUID(), name: "Sarah Miller", role: .maintenance, status: .active, email: "sarah@fleet.com", joinedDate: Date().addingTimeInterval(-86400 * 200)),
        StaffMember(id: UUID(), name: "Ahmed Khan", role: .maintenance, status: .active, email: "ahmed@fleet.com", joinedDate: Date().addingTimeInterval(-86400 * 60)),
        StaffMember(id: UUID(), name: "Lisa Wong", role: .driver, status: .suspended, email: "lisa@fleet.com", joinedDate: Date().addingTimeInterval(-86400 * 180)),
        StaffMember(id: UUID(), name: "Tom Bradley", role: .maintenance, status: .pendingApproval, email: "tom@fleet.com", joinedDate: Date().addingTimeInterval(-86400 * 5)),
    ]
}

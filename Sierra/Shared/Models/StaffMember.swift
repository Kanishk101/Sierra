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

enum DriverAvailability: String {
    case available = "Available"
    case unavailable = "Unavailable"
    case busy = "On Trip"
}

struct StaffMember: Identifiable {
    let id: UUID
    let name: String
    let role: StaffRole
    var status: StaffStatus
    let email: String
    var phone: String
    var availability: DriverAvailability
    let joinedDate: Date
    var numberOfTrips: Int
    var tasksCompleted: Int
    var tasksAssigned: Int

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    static let driverDemoId = "driver_demo"

    static let samples: [StaffMember] = [
        StaffMember(id: UUID(uuidString: "D0000000-0000-0000-0000-000000000001")!, name: "James Turner", role: .driver, status: .active, email: "james@fleet.com", phone: "+91 98765 43210", availability: .available, joinedDate: Date().addingTimeInterval(-86400 * 120), numberOfTrips: 178, tasksCompleted: 0, tasksAssigned: 0),
        StaffMember(id: UUID(uuidString: "D0000000-0000-0000-0000-000000000002")!, name: "Maria Chen", role: .driver, status: .active, email: "maria@fleet.com", phone: "+91 91234 56789", availability: .available, joinedDate: Date().addingTimeInterval(-86400 * 90), numberOfTrips: 124, tasksCompleted: 0, tasksAssigned: 0),
        StaffMember(id: UUID(uuidString: "D0000000-0000-0000-0000-000000000003")!, name: "David Park", role: .driver, status: .pendingApproval, email: "david@fleet.com", phone: "+91 87654 32100", availability: .unavailable, joinedDate: Date().addingTimeInterval(-86400 * 3), numberOfTrips: 0, tasksCompleted: 0, tasksAssigned: 0),
        StaffMember(id: UUID(uuidString: "D0000000-0000-0000-0000-000000000004")!, name: "Sarah Miller", role: .maintenance, status: .active, email: "sarah@fleet.com", phone: "+91 99887 76655", availability: .available, joinedDate: Date().addingTimeInterval(-86400 * 200), numberOfTrips: 0, tasksCompleted: 87, tasksAssigned: 12),
        StaffMember(id: UUID(uuidString: "D0000000-0000-0000-0000-000000000005")!, name: "Ahmed Khan", role: .maintenance, status: .active, email: "ahmed@fleet.com", phone: "+91 88776 65544", availability: .available, joinedDate: Date().addingTimeInterval(-86400 * 60), numberOfTrips: 0, tasksCompleted: 34, tasksAssigned: 8),
        StaffMember(id: UUID(uuidString: "D0000000-0000-0000-0000-000000000006")!, name: "Lisa Wong", role: .driver, status: .suspended, email: "lisa@fleet.com", phone: "+91 77665 54433", availability: .unavailable, joinedDate: Date().addingTimeInterval(-86400 * 180), numberOfTrips: 0, tasksCompleted: 0, tasksAssigned: 0),
        StaffMember(id: UUID(uuidString: "D0000000-0000-0000-0000-000000000007")!, name: "Tom Bradley", role: .maintenance, status: .pendingApproval, email: "tom@fleet.com", phone: "+91 66554 43322", availability: .unavailable, joinedDate: Date().addingTimeInterval(-86400 * 5), numberOfTrips: 0, tasksCompleted: 0, tasksAssigned: 0),
    ]
}

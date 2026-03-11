import Foundation

// MARK: - Maintenance Status

enum MaintenanceStatus: String, Codable, CaseIterable {
    case open        = "Open"
    case inProgress  = "In Progress"
    case completed   = "Completed"
    case cancelled   = "Cancelled"
}

// MARK: - Maintenance Record

struct MaintenanceRecord: Identifiable, Codable {
    let id: UUID                  // SQL: maintenance_id
    var vehicleId: String         // SQL: vehicle_id (FK)
    var staffId: String?          // SQL: staff_id (FK)
    var issueReported: String?    // SQL: issue_reported
    var repairDetails: String?    // SQL: repair_details
    var partsUsed: String?        // SQL: parts_used
    var labourCost: Double        // SQL: labour_cost
    var status: MaintenanceStatus // SQL: status
    var createdAt: Date           // SQL: created_at

    // MARK: - Mock Data

    static let mockData: [MaintenanceRecord] = {
        let cal = Calendar.current
        let now = Date()
        return [
            MaintenanceRecord(
                id: UUID(),
                vehicleId: "A0000000-0000-0000-0000-000000000003",
                staffId: "D0000000-0000-0000-0000-000000000004",
                issueReported: "Brake pads worn, grinding noise",
                repairDetails: "Replaced front and rear brake pads",
                partsUsed: "2x Front pad set, 2x Rear pad set",
                labourCost: 2500.0,
                status: .inProgress,
                createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            MaintenanceRecord(
                id: UUID(),
                vehicleId: "A0000000-0000-0000-0000-000000000001",
                staffId: "D0000000-0000-0000-0000-000000000005",
                issueReported: "Routine 50,000 km service",
                repairDetails: "Oil change, filter replacement",
                partsUsed: "Engine oil 6L, oil filter, air filter",
                labourCost: 1800.0,
                status: .completed,
                createdAt: cal.date(byAdding: .day, value: -6, to: now) ?? now
            ),
        ]
    }()
}

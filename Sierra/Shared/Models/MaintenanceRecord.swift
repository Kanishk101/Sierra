import Foundation

// MARK: - Maintenance Record Status
// Maps to PostgreSQL enum: maintenance_record_status

enum MaintenanceRecordStatus: String, Codable, CaseIterable {
    case scheduled  = "Scheduled"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case cancelled  = "Cancelled"
}

// MARK: - MaintenanceRecord
// Maps to table: maintenance_records

struct MaintenanceRecord: Identifiable, Codable {
    // MARK: Primary key
    let id: UUID

    // MARK: Foreign keys
    var vehicleId: UUID                  // vehicle_id (FK → vehicles.id)
    var workOrderId: UUID                // work_order_id (FK → work_orders.id)
    var maintenanceTaskId: UUID          // maintenance_task_id (FK → maintenance_tasks.id)
    var performedById: UUID              // performed_by_id (FK → staff_members.id)

    // MARK: Details
    var issueReported: String            // issue_reported
    var repairDetails: String            // repair_details
    var odometerAtService: Double        // odometer_at_service

    // MARK: Costs
    var labourCost: Double               // labour_cost (default 0)
    var partsCost: Double                // parts_cost (default 0)
    let totalCost: Double                // total_cost (GENERATED)

    // MARK: Status & scheduling
    var status: MaintenanceRecordStatus  // status
    var serviceDate: Date                // service_date
    var nextServiceDue: Date?            // next_service_due

    // MARK: Timestamps
    var createdAt: Date                  // created_at

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId           = "vehicle_id"
        case workOrderId         = "work_order_id"
        case maintenanceTaskId   = "maintenance_task_id"
        case performedById       = "performed_by_id"
        case issueReported       = "issue_reported"
        case repairDetails       = "repair_details"
        case odometerAtService   = "odometer_at_service"
        case labourCost          = "labour_cost"
        case partsCost           = "parts_cost"
        case totalCost           = "total_cost"
        case status
        case serviceDate         = "service_date"
        case nextServiceDue      = "next_service_due"
        case createdAt           = "created_at"
    }

    // MARK: - Mock Data

    static let mockData: [MaintenanceRecord] = {
        let cal = Calendar.current
        let now = Date()
        let workOrderId1 = UUID(uuidString: "E0000000-0000-0000-0000-000000000001")!
        let workOrderId2 = UUID(uuidString: "E0000000-0000-0000-0000-000000000002")!
        let taskId1 = UUID(uuidString: "E1000000-0000-0000-0000-000000000001")!
        let taskId2 = UUID(uuidString: "E1000000-0000-0000-0000-000000000002")!
        return [
            MaintenanceRecord(
                id: UUID(),
                vehicleId: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
                workOrderId: workOrderId1,
                maintenanceTaskId: taskId1,
                performedById: UUID(uuidString: "D0000000-0000-0000-0000-000000000004")!,
                issueReported: "Brake pads worn, grinding noise",
                repairDetails: "Replaced front and rear brake pads",
                odometerAtService: 118400.0,
                labourCost: 2500.0,
                partsCost: 3200.0,
                totalCost: 0.0,
                status: .inProgress,
                serviceDate: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                nextServiceDue: cal.date(byAdding: .month, value: 6, to: now),
                createdAt: cal.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            MaintenanceRecord(
                id: UUID(),
                vehicleId: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
                workOrderId: workOrderId2,
                maintenanceTaskId: taskId2,
                performedById: UUID(uuidString: "D0000000-0000-0000-0000-000000000005")!,
                issueReported: "Routine 50,000 km service",
                repairDetails: "Oil change, filter replacement",
                odometerAtService: 87500.0,
                labourCost: 1800.0,
                partsCost: 2400.0,
                totalCost: 0.0,
                status: .completed,
                serviceDate: cal.date(byAdding: .day, value: -6, to: now) ?? now,
                nextServiceDue: cal.date(byAdding: .month, value: 3, to: now),
                createdAt: cal.date(byAdding: .day, value: -6, to: now) ?? now
            ),
        ]
    }()
}

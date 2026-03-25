import Foundation
import SwiftUI

// MARK: - Local Models (Self-contained, no external dependencies)

enum MTaskPriority: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"

    var color: Color {
        switch self {
        case .low:    return .gray
        case .medium: return Color(red: 0.95, green: 0.75, blue: 0.10)
        case .high:   return Color(red: 0.95, green: 0.55, blue: 0.10)
        case .urgent: return Color(red: 0.85, green: 0.18, blue: 0.15)
        }
    }

    var bgColor: Color { color.opacity(0.10) }
    var borderColor: Color { color.opacity(0.35) }

    var icon: String {
        switch self {
        case .low:    return "checkmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .high:   return "arrow.up.circle.fill"
        case .urgent: return "flame.fill"
        }
    }
}

enum MTaskStatus: String, CaseIterable {
    case pending    = "Pending"
    case assigned   = "Assigned"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case cancelled  = "Cancelled"

    var color: Color {
        switch self {
        case .pending:    return .orange
        case .assigned:   return .blue
        case .inProgress: return .purple
        case .completed:  return .green
        case .cancelled:  return .gray
        }
    }
}

enum MTaskType: String {
    case preventive = "Preventive"
    case corrective = "Corrective"
    case inspection = "Inspection"
    case emergency  = "Emergency"
}

struct MVehicle: Identifiable {
    let id: UUID
    let name: String
    let licensePlate: String
    let model: String
    let vin: String
    let odometer: Double
}

struct MWorkOrder: Identifiable {
    let id: UUID
    let maintenanceTaskId: UUID
    let vehicleId: UUID
    var status: MWorkOrderStatus
    var repairDescription: String
    var technicianNotes: String
    let createdAt: Date
}

enum MWorkOrderStatus: String, CaseIterable {
    case open       = "Open"
    case inProgress = "In Progress"
    case onHold     = "On Hold"
    case completed  = "Completed"
    case closed     = "Closed"

    var color: Color {
        switch self {
        case .open:       return .blue
        case .inProgress: return .purple
        case .onHold:     return .orange
        case .completed:  return .green
        case .closed:     return .gray
        }
    }
}

struct MMaintenanceTask: Identifiable {
    let id: UUID
    let title: String
    let taskDescription: String
    let taskType: MTaskType
    let vehicleId: UUID
    let priority: MTaskPriority
    var status: MTaskStatus
    let dueDate: Date
    let createdAt: Date
}

struct MUserProfile {
    let name: String
    let email: String
    let role: String
    let certificationType: String
    let certificationExpiry: String
    let yearsOfExperience: Int
    let specializations: [String]
    let isApproved: Bool
    var dateOfBirth: String
    var aadhaarNumber: String
    var phone: String
}

// MARK: - Static Data

enum StaticData {

    // MARK: - Vehicles
    static let vehicles: [MVehicle] = [
        MVehicle(id: UUID(uuidString: "A1B2C3D4-0001-0001-0001-000000000001")!,
                 name: "Fleet Truck Alpha",
                 licensePlate: "MH 04 AB 1234",
                 model: "Tata Prima 4028.S",
                 vin: "TATPRI001VIN2024",
                 odometer: 84320),
        MVehicle(id: UUID(uuidString: "A1B2C3D4-0002-0002-0002-000000000002")!,
                 name: "Fleet Van Beta",
                 licensePlate: "DL 05 CD 5678",
                 model: "Mahindra Supro",
                 vin: "MAHSUP002VIN2024",
                 odometer: 62100),
        MVehicle(id: UUID(uuidString: "A1B2C3D4-0003-0003-0003-000000000003")!,
                 name: "Tanker Gamma",
                 licensePlate: "KA 09 EF 9101",
                 model: "Ashok Leyland 2518",
                 vin: "ASHLYL003VIN2024",
                 odometer: 120500),
    ]

    // MARK: - Tasks
    static let tasks: [MMaintenanceTask] = [
        MMaintenanceTask(
            id: UUID(uuidString: "B1C2D3E4-0001-0001-0001-100000000001")!,
            title: "Engine Oil Change",
            taskDescription: "Perform full synthetic oil change and replace oil filter. Check fluid levels.",
            taskType: .preventive,
            vehicleId: UUID(uuidString: "A1B2C3D4-0001-0001-0001-000000000001")!,
            priority: .high,
            status: .inProgress,
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!
        ),
        MMaintenanceTask(
            id: UUID(uuidString: "B1C2D3E4-0002-0002-0002-100000000002")!,
            title: "Brake Pad Replacement",
            taskDescription: "Front and rear brake pads worn below minimum threshold. Replace all four sets.",
            taskType: .corrective,
            vehicleId: UUID(uuidString: "A1B2C3D4-0002-0002-0002-000000000002")!,
            priority: .urgent,
            status: .assigned,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!
        ),
        MMaintenanceTask(
            id: UUID(uuidString: "B1C2D3E4-0003-0003-0003-100000000003")!,
            title: "Tyre Rotation & Balancing",
            taskDescription: "Rotate all six tyres and balance wheels on the tanker for even wear.",
            taskType: .preventive,
            vehicleId: UUID(uuidString: "A1B2C3D4-0003-0003-0003-000000000003")!,
            priority: .medium,
            status: .pending,
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        MMaintenanceTask(
            id: UUID(uuidString: "B1C2D3E4-0004-0004-0004-100000000004")!,
            title: "Annual Safety Inspection",
            taskDescription: "Conduct full safety inspection as per RTO norms. Check lights, brakes, and steering.",
            taskType: .inspection,
            vehicleId: UUID(uuidString: "A1B2C3D4-0001-0001-0001-000000000001")!,
            priority: .high,
            status: .completed,
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        ),
        MMaintenanceTask(
            id: UUID(uuidString: "B1C2D3E4-0005-0005-0005-100000000005")!,
            title: "Coolant Flush & Refill",
            taskDescription: "Drain old coolant, flush system, and refill with fresh coolant mix.",
            taskType: .preventive,
            vehicleId: UUID(uuidString: "A1B2C3D4-0002-0002-0002-000000000002")!,
            priority: .low,
            status: .pending,
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        ),
        MMaintenanceTask(
            id: UUID(uuidString: "B1C2D3E4-0006-0006-0006-100000000006")!,
            title: "Emergency Fuel Leak Repair",
            taskDescription: "Fuel line leaking near injector rail. Isolate and repair immediately.",
            taskType: .emergency,
            vehicleId: UUID(uuidString: "A1B2C3D4-0003-0003-0003-000000000003")!,
            priority: .urgent,
            status: .inProgress,
            dueDate: Date(),
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        ),
    ]

    // MARK: - Work Orders
    static let workOrders: [MWorkOrder] = [
        MWorkOrder(
            id: UUID(),
            maintenanceTaskId: UUID(uuidString: "B1C2D3E4-0001-0001-0001-100000000001")!,
            vehicleId: UUID(uuidString: "A1B2C3D4-0001-0001-0001-000000000001")!,
            status: .inProgress,
            repairDescription: "Drained old oil. Replaced filter. Filling with 15W-40 synthetic.",
            technicianNotes: "Filter was heavily clogged. Recommend reducing service interval.",
            createdAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!
        ),
        MWorkOrder(
            id: UUID(),
            maintenanceTaskId: UUID(uuidString: "B1C2D3E4-0006-0006-0006-100000000006")!,
            vehicleId: UUID(uuidString: "A1B2C3D4-0003-0003-0003-000000000003")!,
            status: .open,
            repairDescription: "Leak identified at fuel injector O-ring. Sourcing replacement parts.",
            technicianNotes: "",
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        ),
    ]

    // MARK: - User Profile
    static let userProfile = MUserProfile(
        name: "Arjun Sharma",
        email: "arjun.sharma@fleet.co",
        role: "Maintenance Personnel",
        certificationType: "ASE Master Technician",
        certificationExpiry: "Dec 2026",
        yearsOfExperience: 7,
        specializations: ["Engine Overhaul", "Hydraulics", "Electrical Systems", "Diagnostics"],
        isApproved: true,
        dateOfBirth: "12 Aug 1990",
        aadhaarNumber: "XXXX XXXX 4821",
        phone: "+91 98765 43210"
    )

    // MARK: - Helper
    static func vehicle(for task: MMaintenanceTask) -> MVehicle? {
        vehicles.first { $0.id == task.vehicleId }
    }
}

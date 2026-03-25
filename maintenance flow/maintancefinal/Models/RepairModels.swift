import Foundation
import SwiftUI

// MARK: - Repair Task

struct RepairTask: Identifiable, Hashable {
    let id: UUID
    let assignedBy: String
    let title: String
    let description: String
    let vehicleId: UUID
    let priority: MTaskPriority
    var status: RepairStatus
    let dueDate: Date
    let createdAt: Date
    var estimatedMinutes: Int?
    var startedAt: Date?
    var completedAt: Date?
    var inventoryRequirements: [InventoryItem]
    var partsRequest: PartsRequest?
    var history: [RepairHistoryEntry]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RepairTask, rhs: RepairTask) -> Bool { lhs.id == rhs.id }
}

enum RepairStatus: String, CaseIterable {
    case assigned          = "Assigned"
    case partsRequested    = "Parts Requested"
    case partsReady        = "Parts Ready"
    case underMaintenance  = "Under Maintenance"
    case repairDone        = "Repair Done"

    var color: Color {
        switch self {
        case .assigned:         return .blue
        case .partsRequested:   return .orange
        case .partsReady:       return Color(red: 0.1, green: 0.7, blue: 0.4)
        case .underMaintenance: return .purple
        case .repairDone:       return .green
        }
    }

    var icon: String {
        switch self {
        case .assigned:         return "person.badge.clock"
        case .partsRequested:   return "shippingbox"
        case .partsReady:       return "checkmark.circle"
        case .underMaintenance: return "wrench.and.screwdriver"
        case .repairDone:       return "checkmark.seal.fill"
        }
    }
}

// MARK: - Inventory

struct InventoryItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let partNumber: String
    var quantity: Int
    var isAvailable: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: InventoryItem, rhs: InventoryItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Parts Request

struct PartsRequest: Identifiable {
    let id: UUID
    var items: [RequestedPart]
    var status: PartsRequestStatus
    let requestedAt: Date
    var fulfilledAt: Date?
}

struct RequestedPart: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var partNumber: String
    var quantity: Int
    var reason: String
    var isFromDropdown: Bool
    var isAvailable: Bool = false

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RequestedPart, rhs: RequestedPart) -> Bool { lhs.id == rhs.id }
}

enum PartsRequestStatus: String {
    case pending   = "Pending"
    case approved  = "Approved"
    case fulfilled = "Fulfilled"
    case rejected  = "Rejected"
}

// MARK: - History

struct RepairHistoryEntry: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let icon: String
    let color: Color
}

// MARK: - Service

struct ServiceTask: Identifiable, Hashable {
    let id: UUID
    let vehicleId: UUID
    let title: String
    let description: String
    let serviceType: ServiceType
    var status: ServiceStatus
    let scheduledDate: Date
    let lastServiceDate: Date?
    let nextServiceDate: Date?
    var checklistItems: [ServiceCheckItem]
    var requiredParts: [InventoryItem]
    let createdAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ServiceTask, rhs: ServiceTask) -> Bool { lhs.id == rhs.id }
}

enum ServiceType: String, CaseIterable {
    case sixMonthService  = "6-Month Service"
    case annualService    = "Annual Service"
    case oilChange        = "Oil Change"
    case tyreRotation     = "Tyre Rotation"
    case fullInspection   = "Full Inspection"
}

enum ServiceStatus: String, CaseIterable {
    case scheduled  = "Scheduled"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case overdue    = "Overdue"

    var color: Color {
        switch self {
        case .scheduled:  return .blue
        case .inProgress: return .purple
        case .completed:  return .green
        case .overdue:    return .red
        }
    }
}

struct ServiceCheckItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    var isChecked: Bool
    let category: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ServiceCheckItem, rhs: ServiceCheckItem) -> Bool { lhs.id == rhs.id }
}

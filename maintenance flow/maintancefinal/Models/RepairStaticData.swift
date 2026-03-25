import Foundation
import SwiftUI

// MARK: - Static Repair & Service Data

enum RepairStaticData {

    // MARK: - Common Parts Catalog (for dropdown)
    static let partsCatalog: [String] = [
        "Engine Oil Filter",
        "Air Filter",
        "Fuel Filter",
        "Brake Pads (Front)",
        "Brake Pads (Rear)",
        "Brake Disc",
        "Spark Plugs",
        "Timing Belt",
        "Serpentine Belt",
        "Alternator",
        "Starter Motor",
        "Radiator Coolant",
        "Transmission Fluid",
        "Power Steering Fluid",
        "Wiper Blades",
        "Battery",
        "Headlight Bulb",
        "Tyre (185/65 R15)",
        "Shock Absorber",
        "CV Joint",
        "Fuel Injector O-Ring",
        "Thermostat",
        "Water Pump",
        "EGR Valve",
        "Turbocharger Seal"
    ]

    // MARK: - Repair Tasks
    static var repairTasks: [RepairTask] = [
        RepairTask(
            id: UUID(uuidString: "B1000001-0001-0001-0001-100000000001")!,
            assignedBy: "Admin – Raj Kumar",
            title: "Brake Pad Replacement",
            description: "Front and rear brake pads worn below minimum threshold. Immediate replacement required. Vehicle is restricted from long-haul routes until resolved.",
            vehicleId: UUID(uuidString: "A1B2C3D4-0002-0002-0002-000000000002")!,
            priority: .urgent,
            status: .partsReady,
            dueDate: Calendar.current.date(byAdding: .hour, value: 6, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!,
            estimatedMinutes: nil,
            startedAt: nil,
            completedAt: nil,
            inventoryRequirements: [
                InventoryItem(id: UUID(), name: "Brake Pads (Front)", partNumber: "BP-F-001", quantity: 1, isAvailable: true),
                InventoryItem(id: UUID(), name: "Brake Pads (Rear)", partNumber: "BP-R-001", quantity: 1, isAvailable: true),
                InventoryItem(id: UUID(), name: "Brake Disc", partNumber: "BD-001", quantity: 2, isAvailable: true)
            ],
            partsRequest: PartsRequest(
                id: UUID(),
                items: [
                    RequestedPart(name: "Brake Pads (Front)", partNumber: "BP-F-001", quantity: 1, reason: "Worn below threshold", isFromDropdown: true, isAvailable: true),
                    RequestedPart(name: "Brake Pads (Rear)", partNumber: "BP-R-001", quantity: 1, reason: "Worn below threshold", isFromDropdown: true, isAvailable: true),
                    RequestedPart(name: "Brake Disc", partNumber: "BD-001", quantity: 2, reason: "Scored surface", isFromDropdown: true, isAvailable: true)
                ],
                status: .fulfilled,
                requestedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
                fulfilledAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!
            ),
            history: [
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!, title: "Task Assigned", detail: "Assigned by Admin – Raj Kumar", icon: "person.badge.plus", color: .blue),
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!, title: "Parts Requested", detail: "3 items submitted to admin", icon: "shippingbox", color: .orange),
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!, title: "Parts Ready", detail: "All 3 items available in inventory", icon: "checkmark.circle.fill", color: .green)
            ]
        ),
        RepairTask(
            id: UUID(uuidString: "B1000002-0002-0002-0002-100000000002")!,
            assignedBy: "Admin – Priya Nair",
            title: "Fuel Injector Leak",
            description: "Fuel leaking from injector rail O-ring. Vehicle is off-road. Diagnose, source seal kit, and repair.",
            vehicleId: UUID(uuidString: "A1B2C3D4-0003-0003-0003-000000000003")!,
            priority: .urgent,
            status: .underMaintenance,
            dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!,
            estimatedMinutes: 120,
            startedAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date())!,
            completedAt: nil,
            inventoryRequirements: [
                InventoryItem(id: UUID(), name: "Fuel Injector O-Ring", partNumber: "FIR-001", quantity: 6, isAvailable: true),
                InventoryItem(id: UUID(), name: "Fuel Filter", partNumber: "FF-001", quantity: 1, isAvailable: true)
            ],
            partsRequest: nil,
            history: [
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!, title: "Task Assigned", detail: "Assigned by Admin – Priya Nair", icon: "person.badge.plus", color: .blue),
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!, title: "Parts Requested", detail: "2 items submitted", icon: "shippingbox", color: .orange),
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!, title: "Parts Ready", detail: "All items available", icon: "checkmark.circle.fill", color: .green),
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .minute, value: -45, to: Date())!, title: "Work Started", detail: "ETA 2 hours", icon: "wrench.and.screwdriver.fill", color: .purple)
            ]
        ),
        RepairTask(
            id: UUID(uuidString: "B1000003-0003-0003-0003-100000000003")!,
            assignedBy: "Admin – Raj Kumar",
            title: "Engine Oil Change",
            description: "Overdue oil change. Replace engine oil and filter. Check all fluid levels and top up.",
            vehicleId: UUID(uuidString: "A1B2C3D4-0001-0001-0001-000000000001")!,
            priority: .high,
            status: .assigned,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!,
            estimatedMinutes: nil,
            startedAt: nil,
            completedAt: nil,
            inventoryRequirements: [],
            partsRequest: nil,
            history: [
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!, title: "Task Assigned", detail: "Assigned by Admin – Raj Kumar", icon: "person.badge.plus", color: .blue)
            ]
        ),
        RepairTask(
            id: UUID(uuidString: "B1000004-0004-0004-0004-100000000004")!,
            assignedBy: "Admin – Priya Nair",
            title: "Alternator Replacement",
            description: "Battery warning light on. Alternator output below spec. Replace unit and verify charging system.",
            vehicleId: UUID(uuidString: "A1B2C3D4-0002-0002-0002-000000000002")!,
            priority: .medium,
            status: .repairDone,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            estimatedMinutes: 90,
            startedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            completedAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
            inventoryRequirements: [
                InventoryItem(id: UUID(), name: "Alternator", partNumber: "ALT-001", quantity: 1, isAvailable: true)
            ],
            partsRequest: nil,
            history: [
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, title: "Task Assigned", detail: "Assigned by Admin – Priya Nair", icon: "person.badge.plus", color: .blue),
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, title: "Work Started", detail: "ETA 90 min", icon: "wrench.and.screwdriver.fill", color: .purple),
                RepairHistoryEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!, title: "Repair Done", detail: "Charging system verified OK", icon: "checkmark.seal.fill", color: .green)
            ]
        )
    ]

    // MARK: - Service Tasks
    static var serviceTasks: [ServiceTask] = [
        ServiceTask(
            id: UUID(uuidString: "C1000001-0001-0001-0001-200000000001")!,
            vehicleId: UUID(uuidString: "A1B2C3D4-0001-0001-0001-000000000001")!,
            title: "6-Month Scheduled Service",
            description: "Complete 6-month preventive maintenance for Fleet Truck Alpha. Follow FMS checklist.",
            serviceType: .sixMonthService,
            status: .scheduled,
            scheduledDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            lastServiceDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            nextServiceDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())!,
            checklistItems: sixMonthChecklist(),
            requiredParts: [
                InventoryItem(id: UUID(), name: "Engine Oil Filter", partNumber: "EOF-001", quantity: 1, isAvailable: true),
                InventoryItem(id: UUID(), name: "Air Filter", partNumber: "AF-001", quantity: 1, isAvailable: true),
                InventoryItem(id: UUID(), name: "Fuel Filter", partNumber: "FF-001", quantity: 1, isAvailable: false),
                InventoryItem(id: UUID(), name: "Wiper Blades", partNumber: "WB-001", quantity: 2, isAvailable: true),
                InventoryItem(id: UUID(), name: "Serpentine Belt", partNumber: "SB-001", quantity: 1, isAvailable: true)
            ],
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        ServiceTask(
            id: UUID(uuidString: "C1000002-0002-0002-0002-200000000002")!,
            vehicleId: UUID(uuidString: "A1B2C3D4-0003-0003-0003-000000000003")!,
            title: "Annual Full Inspection",
            description: "Annual service and RTO compliance inspection for Tanker Gamma.",
            serviceType: .annualService,
            status: .overdue,
            scheduledDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            lastServiceDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
            nextServiceDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!,
            checklistItems: sixMonthChecklist(),
            requiredParts: [
                InventoryItem(id: UUID(), name: "Air Filter", partNumber: "AF-001", quantity: 1, isAvailable: true),
                InventoryItem(id: UUID(), name: "Timing Belt", partNumber: "TB-001", quantity: 1, isAvailable: false),
                InventoryItem(id: UUID(), name: "Spark Plugs", partNumber: "SP-001", quantity: 6, isAvailable: true)
            ],
            createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        )
    ]

    static func sixMonthChecklist() -> [ServiceCheckItem] {
        let items: [(String, String)] = [
            ("Engine Oil Level", "Engine"),
            ("Oil Filter", "Engine"),
            ("Air Filter", "Engine"),
            ("Fuel Filter", "Fuel System"),
            ("Coolant Level", "Cooling"),
            ("Radiator Hoses", "Cooling"),
            ("Brake Fluid", "Brakes"),
            ("Brake Pads (Front)", "Brakes"),
            ("Brake Pads (Rear)", "Brakes"),
            ("Tyre Pressure", "Tyres"),
            ("Tyre Tread Depth", "Tyres"),
            ("Battery Terminals", "Electrical"),
            ("Headlights", "Electrical"),
            ("Tail Lights", "Electrical"),
            ("Wiper Blades", "Exterior"),
            ("Power Steering Fluid", "Steering"),
            ("Serpentine Belt", "Engine"),
            ("Transmission Fluid", "Transmission")
        ]
        return items.map {
            ServiceCheckItem(id: UUID(), name: $0.0, isChecked: false, category: $0.1)
        }
    }

    static func vehicle(for id: UUID) -> MVehicle? {
        StaticData.vehicles.first { $0.id == id }
    }
}

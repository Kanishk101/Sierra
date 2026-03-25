import Foundation
import SwiftUI

// MARK: - Task Detail ViewModel (Static Data)
@MainActor
@Observable
final class MaintenanceTaskDetailViewModel {

    var task: MMaintenanceTask
    var workOrder: MWorkOrder?
    var repairDescription: String = ""
    var estimatedCompletion: Date = Date().addingTimeInterval(86400)
    var technicianNotes: String = ""
    var labourCost: Double = 0
    var partsUsed: [PartRow] = []
    var isStartingWork = false
    var isCompleting = false
    var errorMessage: String?

    struct PartRow: Identifiable {
        let id = UUID()
        var name = ""
        var partNumber = ""
        var quantity = 1
        var unitCost: Double = 0
    }

    var computedPartsCost: Double {
        partsUsed.reduce(0) { $0 + ($1.unitCost * Double($1.quantity)) }
    }

    init(task: MMaintenanceTask) {
        self.task = task
        // Load existing work order from static data if any
        if let wo = StaticData.workOrders.first(where: { $0.maintenanceTaskId == task.id }) {
            self.workOrder = wo
            self.repairDescription = wo.repairDescription
            self.technicianNotes = wo.technicianNotes
        }
    }

    func startWork() {
        isStartingWork = true
        defer { isStartingWork = false }
        guard task.status == .assigned else { return }
        let newWO = MWorkOrder(
            id: UUID(),
            maintenanceTaskId: task.id,
            vehicleId: task.vehicleId,
            status: .open,
            repairDescription: "",
            technicianNotes: "",
            createdAt: Date()
        )
        workOrder = newWO
        task.status = .inProgress
    }

    func markComplete() -> Bool {
        isCompleting = true
        defer { isCompleting = false }
        task.status = .completed
        return true
    }

    func addPartRow() {
        partsUsed.append(PartRow())
    }
}

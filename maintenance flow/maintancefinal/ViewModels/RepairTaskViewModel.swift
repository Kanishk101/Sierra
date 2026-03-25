import Foundation
import SwiftUI
import Observation

@Observable
final class RepairTaskViewModel {

    var repairTasks: [RepairTask] = RepairStaticData.repairTasks
    var selectedFilter: RepairStatus? = nil

    var filteredTasks: [RepairTask] {
        guard let f = selectedFilter else { return repairTasks }
        return repairTasks.filter { $0.status == f }
    }

    var notificationCount: Int {
        repairTasks.filter { $0.status == .partsReady }.count
    }

    func updateTask(_ task: RepairTask) {
        if let idx = repairTasks.firstIndex(where: { $0.id == task.id }) {
            repairTasks[idx] = task
        }
    }
}

@Observable
final class RepairDetailViewModel {
    var task: RepairTask
    var showInventorySheet = false
    var showPartsRequestSheet = false
    var showEstimatedTimeSheet = false
    var estimatedDays: Int = 0
    var estimatedHours: Int = 1
    var estimatedMinutes: Int = 0
    var isStarting = false
    var isCompleting = false

    init(task: RepairTask) {
        self.task = task
    }

    var dueCountdown: String {
        guard task.status == .underMaintenance, let started = task.startedAt,
              let eta = task.estimatedMinutes else { return "" }
        let end = started.addingTimeInterval(Double(eta * 60))
        let remaining = end.timeIntervalSince(Date())
        if remaining <= 0 { return "Overdue" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m left" : "\(m)m left"
    }

    func submitPartsRequest(_ parts: [RequestedPart]) {
        var updated = task
        updated.partsRequest = PartsRequest(
            id: UUID(),
            items: parts,
            status: .pending,
            requestedAt: Date(),
            fulfilledAt: nil
        )
        updated.status = .partsRequested
        updated.history.append(RepairHistoryEntry(
            id: UUID(), date: Date(),
            title: "Parts Requested",
            detail: "\(parts.count) item(s) submitted to admin",
            icon: "shippingbox", color: .orange
        ))
        task = updated
    }

    func startWork() {
        isStarting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let totalMins = self.estimatedDays * 24 * 60 + self.estimatedHours * 60 + self.estimatedMinutes
            self.task.estimatedMinutes = totalMins
            self.task.startedAt = Date()
            self.task.status = .underMaintenance
            var etaLabel = ""
            if self.estimatedDays > 0 { etaLabel += "\(self.estimatedDays)d " }
            if self.estimatedHours > 0 { etaLabel += "\(self.estimatedHours)h " }
            etaLabel += "\(self.estimatedMinutes)m"
            self.task.history.append(RepairHistoryEntry(
                id: UUID(), date: Date(),
                title: "Work Started",
                detail: "ETA \(etaLabel.trimmingCharacters(in: .whitespaces))",
                icon: "wrench.and.screwdriver.fill", color: .purple
            ))
            self.isStarting = false
            self.showEstimatedTimeSheet = false
        }
    }

    func markRepairDone() {
        isCompleting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.task.completedAt = Date()
            self.task.status = .repairDone
            self.task.history.append(RepairHistoryEntry(
                id: UUID(), date: Date(),
                title: "Repair Done",
                detail: "Task completed successfully",
                icon: "checkmark.seal.fill", color: .green
            ))
            self.isCompleting = false
        }
    }
}

@Observable
final class ServiceTaskViewModel {
    var serviceTasks: [ServiceTask] = RepairStaticData.serviceTasks
    var selectedFilter: ServiceStatus? = nil

    var filteredTasks: [ServiceTask] {
        guard let f = selectedFilter else { return serviceTasks }
        return serviceTasks.filter { $0.status == f }
    }

    func updateTask(_ task: ServiceTask) {
        if let idx = serviceTasks.firstIndex(where: { $0.id == task.id }) {
            serviceTasks[idx] = task
        }
    }
}

import Foundation
import SwiftUI
import PhotosUI
import Supabase

@MainActor
@Observable
final class MaintenanceTaskDetailViewModel {

    let task: MaintenanceTask

    var workOrder: WorkOrder?
    var isLoadingWO = true
    var isStartingWork = false
    var errorMessage: String?

    var repairDescription = ""
    var estimatedCompletion = Date().addingTimeInterval(86400)
    var technicianNotes = ""
    var labourCost: Double = 0
    var partsUsed: [PartRow] = []
    var repairImageUrls: [String] = []
    var isUploadingImages = false
    var isCompleting = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

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

    init(task: MaintenanceTask) {
        self.task = task
    }

    func loadExistingWorkOrder() async {
        isLoadingWO = true
        do {
            if let existing = try await WorkOrderService.fetchWorkOrder(maintenanceTaskId: task.id) {
                workOrder = existing
                repairDescription = existing.repairDescription
                technicianNotes = existing.technicianNotes ?? ""
                labourCost = existing.labourCostTotal
                repairImageUrls = existing.repairImageUrls
                if let est = existing.estimatedCompletionAt { estimatedCompletion = est }
            }
        } catch {
            errorMessage = "Failed to load work order: \(error.localizedDescription)"
        }
        isLoadingWO = false
    }

    func startWork() async {
        guard task.status == .assigned else {
            errorMessage = "This task cannot be started — it is \(task.status.rawValue)"
            return
        }
        isStartingWork = true

        // Check if a work order already exists
        if let existing = AppDataStore.shared.workOrder(forMaintenanceTask: task.id) {
            hydrateFromWorkOrder(existing)
            isStartingWork = false
            return
        }

        do {
            let newWO = WorkOrder(
                id: UUID(),
                maintenanceTaskId: task.id,
                vehicleId: task.vehicleId,
                assignedToId: currentUserId,
                workOrderType: .repair,
                partsSubStatus: .none,
                status: .inProgress,
                repairDescription: "",
                labourCostTotal: 0,
                partsCostTotal: 0,
                totalCost: 0,
                startedAt: Date(),
                completedAt: nil,
                technicianNotes: nil,
                vinScanned: false,
                repairImageUrls: [],
                estimatedCompletionAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await AppDataStore.shared.addWorkOrder(newWO)

            // Update task status in-memory via AppDataStore
            var updatedTask = task
            updatedTask.status = .inProgress
            try await AppDataStore.shared.updateMaintenanceTask(updatedTask)

            workOrder = newWO
        } catch {
            errorMessage = "Failed to start work: \(error.localizedDescription)"
        }

        isStartingWork = false
    }

    func uploadRepairImages(_ items: [PhotosPickerItem]) async {
        isUploadingImages = true
        guard let woId = workOrder?.id else {
            isUploadingImages = false
            return
        }

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let fileName = "\(UUID().uuidString).jpg"
                let path = "repair-images/\(woId.uuidString)/\(fileName)"
                try await supabase.storage.from("sierra-uploads")
                    .upload(path, data: data, options: .init(contentType: "image/jpeg"))
                let url = try supabase.storage.from("sierra-uploads").getPublicURL(path: path).absoluteString
                repairImageUrls.append(url)
            } catch {
                print("[TaskDetailVM] Image upload error: \(error)")
            }
        }

        do {
            try await WorkOrderService.updateRepairImages(workOrderId: woId, imageUrls: repairImageUrls)
        } catch {
            print("[TaskDetailVM] Failed to update image URLs: \(error)")
        }

        isUploadingImages = false
    }

    func markComplete() async -> Bool {
        guard task.status == .inProgress || workOrder != nil else {
            errorMessage = "Task cannot be completed from \(task.status.rawValue)"
            return false
        }
        isCompleting = true
        defer { isCompleting = false }

        do {
            if var wo = workOrder {
                wo.repairDescription = repairDescription
                wo.labourCostTotal = labourCost
                wo.partsCostTotal = computedPartsCost
                wo.technicianNotes = technicianNotes
                wo.completedAt = Date()
                wo.estimatedCompletionAt = estimatedCompletion
                wo.status = .completed
                try await AppDataStore.shared.updateWorkOrder(wo)
            }

            try await AppDataStore.shared.completeMaintenanceTask(id: task.id)

            do {
                try await NotificationService.insertNotification(
                    recipientId: task.createdByAdminId,
                    type: .general,
                    title: "Maintenance Completed",
                    body: "Task '\(task.title)' has been completed.",
                    entityType: "maintenance_task",
                    entityId: task.id
                )
            } catch {
                print("[TaskDetailVM] Non-fatal: notification failed: \(error)")
            }

            return true
        } catch {
            errorMessage = "Failed to complete: \(error.localizedDescription)"
            return false
        }
    }

    func addPartRow() {
        partsUsed.append(PartRow())
    }

    private func hydrateFromWorkOrder(_ existing: WorkOrder) {
        workOrder = existing
        repairDescription = existing.repairDescription
        technicianNotes = existing.technicianNotes ?? ""
        labourCost = existing.labourCostTotal
        repairImageUrls = existing.repairImageUrls
        if let est = existing.estimatedCompletionAt { estimatedCompletion = est }
    }
}

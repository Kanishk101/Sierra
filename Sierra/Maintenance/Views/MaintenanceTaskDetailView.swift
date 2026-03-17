import SwiftUI
import PhotosUI
import Supabase

/// Detail view for a maintenance task — shows task info, vehicle card,
/// status timeline, work order form, and action buttons.
struct MaintenanceTaskDetailView: View {

    let task: MaintenanceTask
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var workOrder: WorkOrder?
    @State private var isLoadingWO = true
    @State private var isStartingWork = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Work order form
    @State private var repairDescription = ""
    @State private var estimatedCompletion = Date().addingTimeInterval(86400)
    @State private var technicianNotes = ""
    @State private var labourCost: Double = 0
    @State private var partsUsed: [PartRow] = []
    @State private var repairImageItems: [PhotosPickerItem] = []
    @State private var repairImageUrls: [String] = []
    @State private var isUploadingImages = false
    @State private var isCompleting = false
    @State private var showSparePartsSheet = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    struct PartRow: Identifiable {
        let id = UUID()
        var name: String = ""
        var partNumber: String = ""
        var quantity: Int = 1
        var unitCost: Double = 0
    }

    // Safeguard 6: computed total
    private var computedPartsCost: Double {
        partsUsed.reduce(0) { $0 + ($1.unitCost * Double($1.quantity)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                taskHeader
                vehicleCard
                statusTimeline
                Divider()

                // Safeguard 4: context-aware actions
                actionSection

                if workOrder != nil {
                    workOrderForm
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Task Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadExistingWorkOrder()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showSparePartsSheet) {
            if let wo = workOrder {
                SparePartsRequestSheet(maintenanceTaskId: task.id, workOrderId: wo.id)
            }
        }
    }

    // MARK: - Task Header

    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.title3.weight(.bold))
                Spacer()
                priorityBadge
            }
            Text(task.taskDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(task.taskType.rawValue, systemImage: "tag")
                Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day().year()), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var priorityBadge: some View {
        Text(task.priority.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(priorityColor, in: Capsule())
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    // MARK: - Vehicle Card

    private var vehicleCard: some View {
        let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
        return VStack(alignment: .leading, spacing: 8) {
            Text("VEHICLE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary).kerning(1)
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.title2).foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle?.name ?? "Unknown").font(.subheadline.weight(.medium))
                    Text("\(vehicle?.licensePlate ?? "") • \(vehicle?.model ?? "")").font(.caption).foregroundStyle(.secondary)
                    Text("VIN: \(vehicle?.vin ?? "N/A")").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    Text("Odometer: \(vehicle?.odometer ?? 0, specifier: "%.0f") km").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status Timeline

    private var statusTimeline: some View {
        let steps: [(String, MaintenanceTaskStatus)] = [
            ("Pending", .pending),
            ("Assigned", .assigned),
            ("In Progress", .inProgress),
            ("Completed", .completed)
        ]
        let currentIndex = steps.firstIndex(where: { $0.1 == task.status }) ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            Text("STATUS").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                .padding(.bottom, 8)

            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(idx <= currentIndex ? Color.orange : Color(.systemGray4))
                            .frame(width: 12, height: 12)
                        Text(step.0)
                            .font(.system(size: 9, weight: idx <= currentIndex ? .bold : .regular))
                            .foregroundStyle(idx <= currentIndex ? .primary : .secondary)
                    }
                    if idx < steps.count - 1 {
                        Rectangle()
                            .fill(idx < currentIndex ? Color.orange : Color(.systemGray4))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions (Safeguard 4: validate status before action)

    @ViewBuilder
    private var actionSection: some View {
        if task.status == .assigned && workOrder == nil {
            Button {
                Task { await startWork() }
            } label: {
                HStack {
                    if isStartingWork { ProgressView().tint(.white) }
                    Text("Start Work")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(SierraTheme.Colors.ember, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isStartingWork)
        }
    }

    // MARK: - Start Work (Safeguard 1: idempotent check + Safeguard 4: status validation)

    private func startWork() async {
        guard task.status == .assigned else {
            errorMessage = "This task cannot be started — it is \(task.status.rawValue)"
            showError = true
            return
        }
        isStartingWork = true

        // Check if work order already exists (Safeguard 1)
        do {
            if let existing = try await WorkOrderService.fetchWorkOrder(maintenanceTaskId: task.id) {
                workOrder = existing
                repairDescription = existing.repairDescription
                technicianNotes = existing.technicianNotes ?? ""
                labourCost = existing.labourCostTotal
                repairImageUrls = existing.repairImageUrls
                isStartingWork = false
                return
            }
        } catch {
            // Continue to create
        }

        do {
            let newWO = WorkOrder(
                id: UUID(),
                maintenanceTaskId: task.id,
                vehicleId: task.vehicleId,
                assignedToId: currentUserId,
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
            try await WorkOrderService.addWorkOrder(newWO)
            try await MaintenanceTaskService.updateMaintenanceTaskStatus(id: task.id, status: .inProgress)
            workOrder = newWO
        } catch {
            errorMessage = "Failed to start work: \(error.localizedDescription)"
            showError = true
        }
        isStartingWork = false
    }

    // MARK: - Work Order Form

    private var workOrderForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WORK ORDER").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Repair Description").font(.caption.weight(.medium))
                TextEditor(text: $repairDescription)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            DatePicker("Est. Completion", selection: $estimatedCompletion, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)

            // Parts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Parts Used").font(.caption.weight(.medium))
                    Spacer()
                    Button { partsUsed.append(PartRow()) } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.orange)
                    }
                }
                ForEach($partsUsed) { $part in
                    HStack(spacing: 8) {
                        TextField("Part", text: $part.name).textFieldStyle(.roundedBorder).font(.caption)
                        TextField("#", text: $part.partNumber).textFieldStyle(.roundedBorder).font(.caption).frame(width: 60)
                        Stepper("Qty: \(part.quantity)", value: $part.quantity, in: 1...100).font(.caption2)
                        TextField("Cost", value: $part.unitCost, format: .number).textFieldStyle(.roundedBorder).font(.caption).frame(width: 60)
                    }
                }
                // Safeguard 6: computed total, not manual
                Text("Parts Total: ₹\(computedPartsCost, specifier: "%.2f")")
                    .font(.caption.weight(.bold)).foregroundStyle(.orange)
            }

            Button("Request Spare Parts") {
                showSparePartsSheet = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SierraTheme.Colors.info)

            // Repair images (Safeguard 2: sequential upload)
            VStack(alignment: .leading, spacing: 8) {
                Text("Repair Images").font(.caption.weight(.medium))
                PhotosPicker(selection: $repairImageItems, maxSelectionCount: 5, matching: .images) {
                    Label("Add Photos", systemImage: "camera.fill")
                        .font(.subheadline)
                        .foregroundStyle(SierraTheme.Colors.info)
                }
                .onChange(of: repairImageItems) { _, items in
                    Task { await uploadRepairImages(items) }
                }
                if isUploadingImages {
                    ProgressView("Uploading images...")
                }
                if !repairImageUrls.isEmpty {
                    Text("\(repairImageUrls.count) image(s) uploaded").font(.caption).foregroundStyle(.green)
                }
            }

            // Labour cost
            HStack {
                Text("Labour Cost").font(.caption.weight(.medium))
                Spacer()
                TextField("₹", value: $labourCost, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 100)
            }

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("Technician Notes").font(.caption.weight(.medium))
                TextEditor(text: $technicianNotes)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            // Mark Complete
            if task.status == .inProgress || workOrder != nil {
                Button {
                    Task { await markComplete() }
                } label: {
                    HStack {
                        if isCompleting { ProgressView().tint(.white) }
                        Text("Mark Complete")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(SierraTheme.Colors.alpineMint, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isCompleting)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Upload Images (Safeguard 2: sequential for-loop)

    private func uploadRepairImages(_ items: [PhotosPickerItem]) async {
        isUploadingImages = true
        guard let woId = workOrder?.id else { isUploadingImages = false; return }

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let fileName = "\(UUID().uuidString).jpg"
                let path = "repair-images/\(woId.uuidString)/\(fileName)"
                try await supabase.storage.from("vehicle-images").upload(path, data: data, options: .init(contentType: "image/jpeg"))
                let url = try supabase.storage.from("vehicle-images").getPublicURL(path: path).absoluteString
                repairImageUrls.append(url)
            } catch {
                print("[TaskDetail] Image upload error: \(error)")
                // Non-fatal: continue with next image
            }
        }

        // Update work order with new images
        do {
            try await WorkOrderService.updateRepairImages(workOrderId: woId, imageUrls: repairImageUrls)
        } catch {
            print("[TaskDetail] Failed to update image URLs: \(error)")
        }
        isUploadingImages = false
    }

    // MARK: - Mark Complete

    private func markComplete() async {
        guard task.status == .inProgress || workOrder != nil else {
            errorMessage = "Task cannot be completed from \(task.status.rawValue)"
            showError = true
            return
        }
        isCompleting = true

        do {
            // Update work order
            if var wo = workOrder {
                wo.repairDescription = repairDescription
                wo.labourCostTotal = labourCost
                wo.partsCostTotal = computedPartsCost  // Safeguard 6
                wo.technicianNotes = technicianNotes
                wo.completedAt = Date()
                wo.estimatedCompletionAt = estimatedCompletion
                wo.status = .completed
                try await WorkOrderService.updateWorkOrder(wo)
            }

            // Update task
            try await MaintenanceTaskService.updateMaintenanceTaskStatus(id: task.id, status: .completed)

            // Notify fleet manager (Safeguard 3: non-fatal)
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
                print("[TaskDetail] Non-fatal: notification failed: \(error)")
            }

            dismiss()
        } catch {
            errorMessage = "Failed to complete: \(error.localizedDescription)"
            showError = true
        }
        isCompleting = false
    }

    // MARK: - Load Existing WO (Safeguard 1)

    private func loadExistingWorkOrder() async {
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
            print("[TaskDetail] WO load error: \(error)")
        }
        isLoadingWO = false
    }
}

import SwiftUI

/// FM's detail view for approving/rejecting a maintenance task.
struct MaintenanceApprovalDetailView: View {

    let task: MaintenanceTask
    var onUpdate: () -> Void

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStaffId: UUID?
    @State private var rejectionReason = ""
    @State private var isApproving = false
    @State private var isRejecting = false
    @State private var showRejectSheet = false
    @State private var workOrder: WorkOrder?
    @State private var errorMessage: String?
    @State private var showError = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    var availableStaff: [StaffMember] {
        store.staff.filter { $0.role == .maintenancePersonnel }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                taskDetails
                vehicleSection
                sourceSection

                if task.status == .pending {
                    assignAndApproveSection
                } else {
                    postApprovalSection
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Approval")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                workOrder = try await WorkOrderService.fetchWorkOrder(maintenanceTaskId: task.id)
            } catch {
                // Not found is ok
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showRejectSheet) {
            rejectSheet
        }
    }

    // MARK: - Task Details

    private var taskDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title).font(.title3.weight(.bold))
                Spacer()
                Text(task.priority.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(priorityColor(task.priority), in: Capsule())
            }
            Text(task.taskDescription)
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(task.taskType.rawValue, systemImage: "tag").font(.caption)
                Label(task.status.rawValue, systemImage: "circle.fill").font(.caption)
                    .foregroundStyle(statusColor(task.status))
                Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar").font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Vehicle

    private var vehicleSection: some View {
        let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
        return HStack(spacing: 12) {
            Image(systemName: "car.fill").font(.title2).foregroundStyle(.orange)
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle?.name ?? "Unknown").font(.subheadline.weight(.medium))
                Text("\(vehicle?.licensePlate ?? "") • \(vehicle?.model ?? "")").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Source

    @ViewBuilder
    private var sourceSection: some View {
        if task.sourceAlertId != nil {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text("Linked to Emergency Alert").font(.caption.weight(.medium))
                Spacer()
            }
            .padding(12)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        if task.sourceInspectionId != nil {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass").foregroundStyle(.blue)
                Text("Linked to Vehicle Inspection").font(.caption.weight(.medium))
                Spacer()
            }
            .padding(12)
            .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Assign & Approve (Safeguard 4: validate pending status)

    private var assignAndApproveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ASSIGN TO").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)

            Picker("Staff", selection: $selectedStaffId) {
                Text("Select...").tag(UUID?.none)
                ForEach(availableStaff) { member in
                    Text(member.name ?? member.email).tag(Optional(member.id))
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 12) {
                Button {
                    Task { await approveTask() }
                } label: {
                    HStack {
                        if isApproving { ProgressView().tint(.white) }
                        Text("Approve & Assign")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(selectedStaffId != nil ? SierraTheme.Colors.alpineMint : Color.gray, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedStaffId == nil || isApproving)

                Button {
                    showRejectSheet = true
                } label: {
                    Text("Reject")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Post Approval

    @ViewBuilder
    private var postApprovalSection: some View {
        if let wo = workOrder {
            VStack(alignment: .leading, spacing: 8) {
                Text("WORK ORDER").font(.caption.weight(.bold)).foregroundStyle(.secondary).kerning(1)
                HStack {
                    Label(wo.status.rawValue, systemImage: "circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(wo.status == .completed ? .green : .orange)
                    Spacer()
                    if let est = wo.estimatedCompletionAt {
                        Label("ETA: \(est.formatted(.dateTime.month(.abbreviated).day().hour().minute()))", systemImage: "clock")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if !wo.repairDescription.isEmpty {
                    Text(wo.repairDescription).font(.caption).foregroundStyle(.secondary)
                }
                if !wo.repairImageUrls.isEmpty {
                    Text("\(wo.repairImageUrls.count) repair image(s)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Approve (Safeguard 4: status check)

    private func approveTask() async {
        guard task.status == .pending else {
            errorMessage = "This task cannot be approved — it is \(task.status.rawValue)"
            showError = true
            return
        }
        guard let assigneeId = selectedStaffId else { return }
        isApproving = true

        do {
            try await MaintenanceTaskService.approveTask(
                taskId: task.id,
                approvedById: currentUserId,
                assignedToId: assigneeId
            )

            // Safeguard 3: non-fatal notifications
            do {
                try await NotificationService.insertNotification(
                    recipientId: assigneeId,
                    type: .general,
                    title: "New Maintenance Task",
                    body: "You have been assigned: \(task.title)",
                    entityType: "maintenance_task",
                    entityId: task.id
                )
            } catch {
                print("[Approval] Non-fatal: notification to assignee failed: \(error)")
            }

            do {
                try await NotificationService.insertNotification(
                    recipientId: task.createdByAdminId,
                    type: .general,
                    title: "Task Approved",
                    body: "'\(task.title)' has been approved and assigned.",
                    entityType: "maintenance_task",
                    entityId: task.id
                )
            } catch {
                print("[Approval] Non-fatal: notification to creator failed: \(error)")
            }

            onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to approve: \(error.localizedDescription)"
            showError = true
        }
        isApproving = false
    }

    // MARK: - Reject Sheet (Safeguard 4: status check)

    private var rejectSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Rejection Reason").font(.subheadline.weight(.medium))
                TextEditor(text: $rejectionReason)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)

                Button {
                    Task { await rejectTask() }
                } label: {
                    HStack {
                        if isRejecting { ProgressView().tint(.white) }
                        Text("Confirm Rejection")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(!rejectionReason.isEmpty ? Color.red : Color.gray, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(rejectionReason.isEmpty || isRejecting)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Reject Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRejectSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func rejectTask() async {
        guard task.status == .pending || task.status == .assigned else {
            errorMessage = "This task cannot be rejected — it is \(task.status.rawValue)"
            showError = true
            return
        }
        isRejecting = true

        do {
            try await MaintenanceTaskService.rejectTask(
                taskId: task.id,
                approvedById: currentUserId,
                reason: rejectionReason
            )

            // Safeguard 3: non-fatal notification
            do {
                try await NotificationService.insertNotification(
                    recipientId: task.createdByAdminId,
                    type: .general,
                    title: "Task Rejected",
                    body: "'\(task.title)' was rejected: \(rejectionReason)",
                    entityType: "maintenance_task",
                    entityId: task.id
                )
            } catch {
                print("[Approval] Non-fatal: rejection notification failed: \(error)")
            }

            showRejectSheet = false
            onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to reject: \(error.localizedDescription)"
            showError = true
        }
        isRejecting = false
    }

    // MARK: - Helpers

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low: return .gray; case .medium: return .blue; case .high: return .orange; case .urgent: return .red
        }
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s {
        case .pending: return .orange; case .assigned: return .blue; case .inProgress: return .purple
        case .completed: return .green; case .cancelled: return .gray
        }
    }
}

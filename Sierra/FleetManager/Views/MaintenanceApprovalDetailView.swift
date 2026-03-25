import SwiftUI

/// Admin detail view for a maintenance task.
/// Includes approval, assignment, phases, ETA, and spare-parts approvals.
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
    @State private var showVehicleSheet = false
    @State private var showWorkOrderSheet = false

    @State private var fetchedWorkOrder: WorkOrder?
    @State private var loadedPhases = false

    @State private var rejectPartTarget: SparePartsRequest?

    @State private var errorMessage: String?
    @State private var showError = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var availableStaff: [StaffMember] {
        store.staff.filter {
            $0.role == .maintenancePersonnel
                && $0.status == .active
                && $0.availability == .available
        }
    }

    private var workOrder: WorkOrder? {
        store.workOrder(forMaintenanceTask: task.id) ?? fetchedWorkOrder
    }

    private var vehicle: Vehicle? {
        store.vehicle(for: task.vehicleId)
    }

    private var phases: [WorkOrderPhase] {
        guard let wo = workOrder else { return [] }
        return store.phases(forWorkOrder: wo.id)
    }

    private var spareParts: [SparePartsRequest] {
        store.sparePartsRequests(forTask: task.id).sorted { $0.createdAt > $1.createdAt }
    }

    private var donePhases: Int { phases.filter(\.isCompleted).count }

    private var progressValue: Double {
        let base: Double
        switch task.status {
        case .pending: base = 0.15
        case .assigned: base = 0.32
        case .inProgress: base = 0.55
        case .completed: base = 1.0
        case .cancelled: base = 0.0
        }
        if phases.isEmpty { return base }
        let phaseProgress = Double(donePhases) / Double(phases.count)
        return max(base, phaseProgress)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusStripCard
                overviewCard
                vehicleCard
                timelineCard
                phaseCard
                partsCard
                assignmentCard
                progressCard
                actionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Task Overview")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .sheet(isPresented: $showRejectSheet) { rejectSheet }
        .sheet(isPresented: $showVehicleSheet) {
            if let vehicle {
                VehicleQuickStatusSheet(vehicle: vehicle)
                    .environment(store)
            }
        }
        .sheet(isPresented: $showWorkOrderSheet) {
            WorkOrderDetailSheet(task: task)
                .environment(store)
        }
        .sheet(item: $rejectPartTarget) { part in
            RejectPartReasonSheet(part: part) { reason in
                Task {
                    try? await store.rejectSparePartsRequest(id: part.id, reviewedBy: currentUserId, reason: reason)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    private var statusStripCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(task.status))
                .frame(width: 10, height: 10)

            Text(task.status.rawValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor(task.status))

            Spacer()

            Text(task.priority.rawValue)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(priorityColor(task.priority))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(priorityColor(task.priority).opacity(0.12), in: Capsule())
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("MNT-\(task.id.uuidString.prefix(8).uppercased())")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.appOrange)
                }
                Spacer()
                typeBadge
            }

            Text(task.taskDescription)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)

            Rectangle()
                .fill(Color.appDivider.opacity(0.6))
                .frame(height: 1)

            HStack(spacing: 12) {
                Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                if let eta = workOrder?.estimatedCompletionAt {
                    Label("ETA \(eta.formatted(.dateTime.month(.abbreviated).day().hour().minute()))", systemImage: "clock")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var vehicleCard: some View {
        if let vehicle {
            Button {
                showVehicleSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                        .frame(width: 34, height: 34)
                        .background(Color.appOrange.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vehicle.licensePlate)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.appOrange)
                        Text("\(vehicle.name) · \(vehicle.model)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(14)
                .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status Timeline")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            ForEach(Array(timelineStages.enumerated()), id: \.offset) { index, stage in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Image(systemName: stage.complete ? "checkmark.circle.fill" : (stage.current ? "circle.inset.filled" : "circle"))
                            .font(.system(size: 16))
                            .foregroundStyle(stage.complete ? .green : (stage.current ? Color.appOrange : Color.appDivider))
                        if index != timelineStages.count - 1 {
                            Rectangle()
                                .fill(stage.complete ? Color.green.opacity(0.35) : Color.appDivider.opacity(0.7))
                                .frame(width: 2, height: 20)
                        }
                    }
                    Text(stage.label)
                        .font(.system(size: 13, weight: stage.current ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(stage.complete || stage.current ? Color.appTextPrimary : Color.appTextSecondary)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private var phaseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Phases")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                if !phases.isEmpty {
                    Text("\(donePhases)/\(phases.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(donePhases == phases.count ? .green : Color.appOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((donePhases == phases.count ? Color.green : Color.appOrange).opacity(0.12), in: Capsule())
                }
            }

            if !loadedPhases {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if phases.isEmpty {
                Text("Phases will appear once work starts.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(phases) { phase in
                    HStack(spacing: 10) {
                        Image(systemName: phase.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(phase.isCompleted ? .green : Color.appDivider)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                            if let desc = phase.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.appTextSecondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }
                    if phase.id != phases.last?.id {
                        Rectangle()
                            .fill(Color.appDivider.opacity(0.6))
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private var partsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Parts Requested")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(spareParts.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
            }

            if spareParts.isEmpty {
                Text("No spare parts requests for this task.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                ForEach(spareParts) { part in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(part.partName)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                if let pn = part.partNumber, !pn.isEmpty {
                                    Text("Part #\(pn)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                            Spacer()
                            Text("x\(part.quantity)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appOrange)
                        }

                        HStack(spacing: 8) {
                            statusPill(for: part.status)
                            Spacer()
                            if part.status == .pending {
                                Button {
                                    rejectPartTarget = part
                                } label: {
                                    Text("Reject")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.1), in: Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { try? await store.approveSparePartsRequest(id: part.id, reviewedBy: currentUserId) }
                                } label: {
                                    Text("Approve")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.black, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if part.id != spareParts.last?.id {
                        Rectangle()
                            .fill(Color.appDivider.opacity(0.6))
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assignment")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            if let assigneeId = task.assignedToId, let staff = store.staffMember(for: assigneeId) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                    Text(staff.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(Color.appTextPrimary)
            } else {
                Text("No technician assigned yet.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
            }

            if task.status == .pending {
                Picker("Assign To", selection: $selectedStaffId) {
                    Text("Select available staff").tag(UUID?.none)
                    ForEach(availableStaff) { member in
                        Text(member.displayName).tag(Optional(member.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if workOrder != nil {
                Button {
                    showWorkOrderSheet = true
                } label: {
                    Text("Open Full Work Order")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Task Progress")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text("\(Int(progressValue * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.appDivider.opacity(0.8))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(task.status == .completed ? Color.green : Color.appOrange)
                        .frame(width: geo.size.width * progressValue)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private var actionCard: some View {
        if task.status == .pending {
            HStack(spacing: 10) {
                Button {
                    showRejectSheet = true
                } label: {
                    Text("Reject")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await approveTask() }
                } label: {
                    HStack(spacing: 8) {
                        if isApproving { ProgressView().tint(.white) }
                        Text("Approve & Assign")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedStaffId != nil ? Color.black : Color.gray, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedStaffId == nil || isApproving)
            }
            .padding(.top, 4)
        }
    }

    private var typeBadge: some View {
        let isService = task.taskType == .scheduled
        let color: Color = isService ? .blue : Color.appOrange
        let icon = isService ? "calendar.badge.checkmark" : "wrench.and.screwdriver.fill"
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(isService ? "Service" : "Repair")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    private func statusPill(for status: SparePartsRequestStatus) -> some View {
        let tint: Color
        switch status {
        case .pending: tint = Color.appOrange
        case .approved: tint = .green
        case .rejected: tint = .red
        case .fulfilled: tint = .blue
        }
        return Text(status.rawValue)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var timelineStages: [(label: String, complete: Bool, current: Bool)] {
        let currentIndex: Int
        switch task.status {
        case .pending: currentIndex = 0
        case .assigned: currentIndex = 1
        case .inProgress: currentIndex = 2
        case .completed: currentIndex = 3
        case .cancelled: currentIndex = 0
        }

        let labels = ["Reported", "Assigned", "In Progress", "Completed"]
        return labels.enumerated().map { index, label in
            (label, index < currentIndex || task.status == .completed, index == currentIndex && task.status != .completed)
        }
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s {
        case .pending: return Color.appOrange
        case .assigned: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .gray
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low: return .green
        case .medium: return .blue
        case .high: return Color.appOrange
        case .urgent: return .red
        }
    }

    private func loadData() async {
        do {
            if let wo = try await WorkOrderService.fetchWorkOrder(maintenanceTaskId: task.id) {
                fetchedWorkOrder = wo
                if store.workOrders.first(where: { $0.id == wo.id }) == nil {
                    store.workOrders.append(wo)
                }
                await store.loadWorkOrderPhases(workOrderId: wo.id)
            }
        } catch {
            // Work order may not exist yet for pending requests.
        }
        loadedPhases = true
    }

    private func approveTask() async {
        guard task.status == .pending else {
            errorMessage = "This task is already \(task.status.rawValue)."
            showError = true
            return
        }
        guard let assigneeId = selectedStaffId else { return }

        isApproving = true
        defer { isApproving = false }

        do {
            try await MaintenanceTaskService.approveTask(
                taskId: task.id,
                approvedById: currentUserId,
                assignedToId: assigneeId
            )

            do {
                try await NotificationService.insertNotification(
                    recipientId: assigneeId,
                    type: .general,
                    title: "New Maintenance Task",
                    body: "You were assigned: \(task.title)",
                    entityType: "maintenance_task",
                    entityId: task.id
                )
            } catch {
                print("[MaintenanceApprovalDetailView] Non-fatal assignee notify error: \(error)")
            }

            onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to approve task: \(error.localizedDescription)"
            showError = true
        }
    }

    private var rejectSheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Provide a rejection reason")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                TextEditor(text: $rejectionReason)
                    .frame(minHeight: 110)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)

                Button {
                    Task { await rejectTask() }
                } label: {
                    HStack(spacing: 8) {
                        if isRejecting { ProgressView().tint(.white) }
                        Text("Confirm Rejection")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(rejectionReason.isEmpty ? Color.gray : Color.red, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(rejectionReason.isEmpty || isRejecting)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 18)
            .background(Color.appSurface.ignoresSafeArea())
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
            errorMessage = "This task is already \(task.status.rawValue)."
            showError = true
            return
        }

        isRejecting = true
        defer { isRejecting = false }

        do {
            try await MaintenanceTaskService.rejectTask(
                taskId: task.id,
                approvedById: currentUserId,
                reason: rejectionReason
            )

            showRejectSheet = false
            onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to reject task: \(error.localizedDescription)"
            showError = true
        }
    }
}

private struct RejectPartReasonSheet: View {
    let part: SparePartsRequest
    let onConfirm: (String) -> Void

    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add rejection reason for \(part.partName).")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)

                TextEditor(text: $reason)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onConfirm(trimmed)
                    dismiss()
                } label: {
                    Text("Reject Part")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(trimmedReason.isEmpty ? Color.gray : Color.red, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(trimmedReason.isEmpty)

                Spacer()
            }
            .padding(16)
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Reject Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

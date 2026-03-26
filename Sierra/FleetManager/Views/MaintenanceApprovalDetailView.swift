import SwiftUI

/// Admin detail view for a maintenance task.
/// Sierra design system: no description in overview, driver dual-button actions,
/// clean timeline, appCardBg throughout.
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
    @State private var showAssigneeDetails = false
    @State private var showVehicleDetails = false
    @State private var expandedPhases: Set<UUID> = []

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var availableStaff: [StaffMember] {
        store.staff.filter { $0.role == .maintenancePersonnel && $0.status == .active && $0.availability == .available }
    }

    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) ?? fetchedWorkOrder }
    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var phases: [WorkOrderPhase] { guard let wo = workOrder else { return [] }; return store.phases(forWorkOrder: wo.id) }
    private var spareParts: [SparePartsRequest] { store.sparePartsRequests(forTask: task.id).sorted { $0.createdAt > $1.createdAt } }
    private var donePhases: Int { phases.filter(\.isCompleted).count }

    private var progressValue: Double {
        let base: Double
        switch task.status {
        case .pending: base = 0.15; case .assigned: base = 0.32
        case .inProgress: base = 0.55; case .completed: base = 1.0; case .cancelled: base = 0.0
        }
        guard !phases.isEmpty else { return base }
        return max(base, Double(donePhases) / Double(phases.count))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusStripCard
                overviewCard
                assignmentFleetCard
                timelineCard
                if !spareParts.isEmpty { partsCard }
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
        .sheet(isPresented: $showWorkOrderSheet) {
            WorkOrderDetailSheet(task: task).environment(store)
        }
        .sheet(item: $rejectPartTarget) { part in
            RejectPartReasonSheet(part: part) { reason in
                Task { try? await store.rejectSparePartsRequest(id: part.id, reviewedBy: currentUserId, reason: reason) }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Status Strip

    private var statusStripCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(statusColor(task.status)).frame(width: 8, height: 8)
                    Text(task.status.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor(task.status))
                }
                Spacer()
                Text(task.priority.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(priorityColor(task.priority))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(priorityColor(task.priority).opacity(0.12), in: Capsule())
            }

            HStack {
                Text("Task Progress")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("\(Int(progressValue * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.appDivider.opacity(0.8))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(task.status == .completed ? Color.green : Color.appOrange)
                        .frame(width: geo.size.width * progressValue)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Overview Card (NO description)

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

            Rectangle().fill(Color.appDivider.opacity(0.6)).frame(height: 1)

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar").font(.system(size: 11))
                    Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.appTextSecondary)
                Spacer()
                if let eta = workOrder?.estimatedCompletionAt {
                    HStack(spacing: 5) {
                        Image(systemName: "clock").font(.system(size: 11))
                        Text("ETA \(etaInHoursMinutes(to: eta))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Vehicle Card

    @ViewBuilder
    private var vehicleCard: some View {
        if let vehicle {
            Button { showVehicleSheet = true } label: {
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
                .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Assignment + Fleet Card

    private var assignmentFleetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assigned & Working On")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            if let assigneeId = task.assignedToId, let staff = store.staffMember(for: assigneeId) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showAssigneeDetails.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.appOrange.opacity(0.12)).frame(width: 32, height: 32)
                            Text(staff.initials).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                        }
                        Text(staff.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Text("Assigned")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1), in: Capsule())
                    }
                }
                .buttonStyle(.plain)

                if showAssigneeDetails {
                    VStack(alignment: .leading, spacing: 6) {
                        labeledValue("Role", "Maintenance Personnel")
                        labeledValue("Status", staff.status.rawValue)
                        labeledValue("Availability", staff.availability.rawValue)
                        if let phone = staff.phone, !phone.isEmpty { labeledValue("Phone", phone) }
                    }
                    .padding(10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if let vehicle {
                Rectangle().fill(Color.appDivider.opacity(0.6)).frame(height: 1)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showVehicleDetails.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appOrange)
                        Text(vehicle.licensePlate)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.appOrange)
                        Text("\(vehicle.name) \(vehicle.model)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if showVehicleDetails {
                    VStack(alignment: .leading, spacing: 6) {
                        labeledValue("VIN", vehicle.vin)
                        labeledValue("Manufacturer", vehicle.manufacturer)
                        labeledValue("Year", "\(vehicle.year)")
                        labeledValue("Odometer", "\(Int(vehicle.odometer)) km")
                    }
                    .padding(10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Timeline Card (Unified)

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                Spacer()
            }

            ForEach(Array(timelineStages.enumerated()), id: \.offset) { index, stage in
                VStack(alignment: .leading, spacing: 8) {
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.label)
                                .font(.system(size: 13, weight: stage.current ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(stage.complete || stage.current ? Color.appTextPrimary : Color.appTextSecondary)
                            if let ts = timestamp(for: stage.label) {
                                Text(ts.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                    }

                    if stage.label == "In Progress", !phases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(phases) { phase in
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        if expandedPhases.contains(phase.id) {
                                            expandedPhases.remove(phase.id)
                                        } else {
                                            expandedPhases.insert(phase.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: phase.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16))
                                            .foregroundStyle(phase.isCompleted ? .green : Color.appDivider)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(phase.title)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.appTextPrimary)
                                            if let mins = phase.estimatedMinutes {
                                                Text("ETA \(mins / 60)h \(mins % 60)m")
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                                    .foregroundStyle(Color.appTextSecondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)

                                if expandedPhases.contains(phase.id) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        labeledValue("Completion", phase.isCompleted ? "Completed" : "Pending")
                                        if let completedAt = phase.completedAt {
                                            labeledValue("Completed At", completedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                        }
                                        if let desc = phase.description, !desc.isEmpty {
                                            labeledValue("Details", desc)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.leading, 26)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Parts Card

    private var partsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Parts Requested").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(spareParts.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Color.appOrange.opacity(0.1), in: Capsule())
            }

            ForEach(Array(spareParts.enumerated()), id: \.element.id) { idx, part in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.partName).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                            if let pn = part.partNumber, !pn.isEmpty {
                                Text("Part #\(pn)").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                        Text("×\(part.quantity)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                    }
                    HStack(spacing: 8) {
                        statusPill(for: part.status)
                        Spacer()
                        if part.status == .pending {
                            Button { rejectPartTarget = part } label: {
                                Text("Reject").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.red)
                                    .padding(.horizontal, 10).padding(.vertical, 6).background(Color.red.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button { Task { try? await store.approveSparePartsRequest(id: part.id, reviewedBy: currentUserId) } } label: {
                                Text("Approve").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background(Color.appTextPrimary, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if idx < spareParts.count - 1 { Divider() }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Assignment Card

    private var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assignment").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)

            if let assigneeId = task.assignedToId, let staff = store.staffMember(for: assigneeId) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.appOrange.opacity(0.12)).frame(width: 32, height: 32)
                        Text(staff.initials).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                    }
                    Text(staff.displayName).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Text("Assigned").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.1), in: Capsule())
                }
            } else if task.status == .pending {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select available technician")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                    Picker("Assign To", selection: $selectedStaffId) {
                        Text("Choose technician…").tag(UUID?.none)
                        ForEach(availableStaff) { member in
                            Text(member.displayName).tag(Optional(member.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDivider.opacity(0.6), lineWidth: 1))
                    .tint(Color.appOrange)

                    if availableStaff.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(.orange)
                            Text("No available maintenance personnel right now.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
            } else {
                Text("No technician assigned yet.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                if workOrder != nil {
                    Button { showWorkOrderSheet = true } label: {
                        Text("Open Full Work Order")
                            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Color.appTextPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Progress Card

    private var progressCard: some View { EmptyView() }

    // MARK: - Action Card — driver dual-button pattern

    @ViewBuilder
    private var actionCard: some View {
        if task.status == .pending {
            HStack(spacing: 12) {
                // Left: Reject (red outline)
                Button { showRejectSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle").font(.system(size: 13, weight: .semibold))
                        Text("Reject").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().fill(Color.red.opacity(0.08)))
                    .overlay(Capsule().stroke(Color.red.opacity(0.22), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                // Right: Approve & Assign (black filled)
                Button { Task { await approveTask() } } label: {
                    HStack(spacing: 6) {
                        if isApproving { ProgressView().tint(.white).scaleEffect(0.8) }
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 13, weight: .semibold))
                        Text("Approve & Assign").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().fill(selectedStaffId != nil ? Color.appTextPrimary : Color.appDivider))
                }
                .buttonStyle(.plain)
                .disabled(selectedStaffId == nil || isApproving)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private var typeBadge: some View {
        let isService = task.taskType == .scheduled
        let color: Color = isService ? .blue : Color.appOrange
        let icon = isService ? "calendar.badge.checkmark" : "wrench.and.screwdriver.fill"
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(isService ? "Service" : "Repair").font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 5).background(color.opacity(0.12), in: Capsule())
    }

    private func statusPill(for status: SparePartsRequestStatus) -> some View {
        let tint: Color
        switch status { case .pending: tint = Color.appOrange; case .approved: tint = .green; case .rejected: tint = .red; case .fulfilled: tint = .blue }
        return Text(status.rawValue).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4).background(tint.opacity(0.12), in: Capsule())
    }

    private var timelineStages: [(label: String, complete: Bool, current: Bool)] {
        let currentIndex: Int
        switch task.status { case .pending: currentIndex = 0; case .assigned: currentIndex = 1; case .inProgress: currentIndex = 2; case .completed: currentIndex = 3; case .cancelled: currentIndex = 0 }
        return ["Reported", "Assigned", "In Progress", "Completed"].enumerated().map { index, label in
            (label, index < currentIndex || task.status == .completed, index == currentIndex && task.status != .completed)
        }
    }

    private func etaInHoursMinutes(to eta: Date) -> String {
        let interval = max(0, Int(eta.timeIntervalSinceNow))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func timestamp(for stage: String) -> Date? {
        switch stage {
        case "Reported":
            return task.createdAt
        case "Assigned":
            return task.approvedAt
        case "In Progress":
            return workOrder?.startedAt
        case "Completed":
            return task.completedAt ?? workOrder?.completedAt
        default:
            return nil
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s { case .pending: Color.appOrange; case .assigned: .blue; case .inProgress: .purple; case .completed: .green; case .cancelled: .gray }
    }
    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p { case .low: .green; case .medium: .blue; case .high: Color.appOrange; case .urgent: .red }
    }

    private func loadData() async {
        do {
            if let wo = try await WorkOrderService.fetchWorkOrder(maintenanceTaskId: task.id) {
                fetchedWorkOrder = wo
                if store.workOrders.first(where: { $0.id == wo.id }) == nil { store.workOrders.append(wo) }
                await store.loadWorkOrderPhases(workOrderId: wo.id)
            }
        } catch {}
        loadedPhases = true
    }

    private func approveTask() async {
        guard task.status == .pending, let assigneeId = selectedStaffId else { return }
        isApproving = true; defer { isApproving = false }
        do {
            try await MaintenanceTaskService.approveTask(taskId: task.id, approvedById: currentUserId, assignedToId: assigneeId)
            try? await NotificationService.insertNotification(recipientId: assigneeId, type: .general, title: "New Maintenance Task", body: "You were assigned: \(task.title)", entityType: "maintenance_task", entityId: task.id)
            onUpdate(); dismiss()
        } catch {
            errorMessage = "Failed to approve task: \(error.localizedDescription)"; showError = true
        }
    }

    private var rejectSheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Provide a rejection reason").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.appCardBg).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appDivider, lineWidth: 1)).frame(minHeight: 110)
                    if rejectionReason.isEmpty { Text("Reason for rejection…").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary.opacity(0.5)).padding(14) }
                    TextEditor(text: $rejectionReason).frame(minHeight: 110).padding(10).background(Color.clear)
                }
                .padding(.horizontal, 16)
                Button { Task { await rejectTask() } } label: {
                    HStack(spacing: 8) {
                        if isRejecting { ProgressView().tint(.white) }
                        Text("Confirm Rejection").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(rejectionReason.isEmpty ? Color.gray : Color.red, in: Capsule())
                }
                .buttonStyle(.plain).disabled(rejectionReason.isEmpty || isRejecting).padding(.horizontal, 16)
                Spacer()
            }
            .padding(.top, 18)
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Reject Task").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showRejectSheet = false }.foregroundStyle(Color.appOrange) } }
        }
        .presentationDetents([.medium])
    }

    private func rejectTask() async {
        guard task.status == .pending || task.status == .assigned else { return }
        isRejecting = true; defer { isRejecting = false }
        do {
            try await MaintenanceTaskService.rejectTask(taskId: task.id, approvedById: currentUserId, reason: rejectionReason)
            showRejectSheet = false; onUpdate(); dismiss()
        } catch {
            errorMessage = "Failed to reject task: \(error.localizedDescription)"; showError = true
        }
    }
}

// MARK: - Reject Part Reason Sheet

private struct RejectPartReasonSheet: View {
    let part: SparePartsRequest
    let onConfirm: (String) -> Void

    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss
    private var trimmed: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add rejection reason for \(part.partName).")
                    .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.appCardBg).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appDivider, lineWidth: 1)).frame(minHeight: 120)
                    if reason.isEmpty { Text("Reason…").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary.opacity(0.5)).padding(14) }
                    TextEditor(text: $reason).frame(minHeight: 120).padding(10).background(Color.clear)
                }
                Button { onConfirm(trimmed); dismiss() } label: {
                    Text("Reject Part").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(trimmed.isEmpty ? Color.gray : Color.red, in: Capsule())
                }
                .disabled(trimmed.isEmpty)
                Spacer()
            }
            .padding(16)
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle("Reject Part").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Color.appOrange) } }
        }
        .presentationDetents([.medium])
    }
}

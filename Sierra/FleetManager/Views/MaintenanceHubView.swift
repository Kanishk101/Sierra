import SwiftUI

// MARK: - MaintenanceHubView
/// Admin-facing maintenance panel.
/// Follows Sierra design system: appCardBg cards, driver dual-button pattern,
/// no description text in list, filter chips, coloured stat pills.

struct MaintenanceHubView: View {
    @Environment(AppDataStore.self) private var store

    enum RequestTypeFilter: String, CaseIterable {
        case all = "All"; case repair = "Repair"; case service = "Service"
    }
    enum StatusFilter: String, CaseIterable {
        case pending = "Pending"; case active = "Active"; case completed = "Completed"
    }

    @State private var requestType: RequestTypeFilter = .all
    @State private var statusFilter: StatusFilter = .active
    @State private var searchText = ""
    @State private var selectedTask: MaintenanceTask?
    @State private var vehicleSheetVehicle: Vehicle?
    @State private var showInventoryAdmin = false
    @State private var rejectPartTarget: SparePartsRequest?

    private var adminId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var allTasks: [MaintenanceTask] {
        store.maintenanceTasks.sorted {
            if $0.status == .pending && $1.status != .pending { return true }
            if $0.status != .pending && $1.status == .pending { return false }
            return $0.dueDate < $1.dueDate
        }
    }

    private var filteredTasks: [MaintenanceTask] {
        allTasks.filter { matchesRequestType($0) && matchesStatus($0) && (searchText.isEmpty || matchesSearch($0)) }
    }

    private var repairTasks: [MaintenanceTask]  { filteredTasks.filter { $0.taskType != .scheduled } }
    private var serviceTasks: [MaintenanceTask] { filteredTasks.filter { $0.taskType == .scheduled } }

    private var pendingPartRequests: [SparePartsRequest] {
        store.sparePartsRequests.filter { $0.status == .pending }.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalCount: Int     { store.maintenanceTasks.count }
    private var urgentCount: Int    { store.maintenanceTasks.filter { $0.priority == .urgent && ($0.status == .pending || $0.status == .assigned || $0.status == .inProgress) }.count }
    private var completedCount: Int { store.maintenanceTasks.filter { $0.status == .completed }.count }

    var body: some View {
        VStack(spacing: 0) {
            summaryRow
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            filterChips.padding(.bottom, 6)

            if filteredTasks.isEmpty && pendingPartRequests.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        tasksSections
                        if !pendingPartRequests.isEmpty { partsApprovalSection }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 28)
                }
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search task, vehicle…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInventoryAdmin = true } label: {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                }
            }
            ToolbarItem(placement: .topBarTrailing) { filterMenu }
        }
        .navigationDestination(item: $selectedTask) { task in
            MaintenanceApprovalDetailView(task: task) { Task { await store.loadAll() } }
        }
        .sheet(item: $vehicleSheetVehicle) { v in VehicleQuickStatusSheet(vehicle: v).environment(store) }
        .sheet(item: $rejectPartTarget) { part in
            RejectReasonSheet(
                title: "Reject Part Request",
                subtitle: "Give a reason so maintenance staff can proceed correctly.",
                placeholder: "Reason for rejection",
                confirmTitle: "Reject Part",
                confirmColor: .red
            ) { reason in
                guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { try? await store.rejectSparePartsRequest(id: part.id, reviewedBy: adminId, reason: reason) }
            }
        }
        .sheet(isPresented: $showInventoryAdmin) { InventoryAdminView().environment(store) }
        .task { if store.maintenanceTasks.isEmpty || store.workOrders.isEmpty { await store.loadAll() } }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryCard(value: totalCount,     label: "Total",     icon: "list.bullet.rectangle.fill", color: Color.appOrange)
            summaryCard(value: urgentCount,    label: "Urgent",    icon: "flame.fill",                 color: .red)
            summaryCard(value: completedCount, label: "Completed", icon: "checkmark.seal.fill",        color: .green)
        }
    }

    private func summaryCard(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text("\(value)").font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatusFilter.allCases, id: \.self) { f in
                    chipButton(title: f.rawValue, isSelected: statusFilter == f, style: .orange) { statusFilter = f }
                }
                Divider().frame(height: 20)
                ForEach(RequestTypeFilter.allCases, id: \.self) { f in
                    chipButton(title: f.rawValue, isSelected: requestType == f, style: .ghost) { requestType = f }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private enum ChipStyle { case orange, ghost }
    private func chipButton(title: String, isSelected: Bool, style: ChipStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? (style == .orange ? .white : Color.appOrange) : Color.appTextPrimary)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected
                        ? (style == .orange ? Color.appOrange : Color.appOrange.opacity(0.1))
                        : Color.appCardBg
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? (style == .orange ? Color.clear : Color.appOrange.opacity(0.3)) : Color.appDivider.opacity(0.4),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Type", selection: $requestType) {
                ForEach(RequestTypeFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if requestType != .all || statusFilter != .active {
                Divider()
                Button("Reset Filters") { requestType = .all; statusFilter = .active }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.appTextPrimary)
        }
    }

    // MARK: - Task Sections

    @ViewBuilder
    private var tasksSections: some View {
        if requestType != .service, !repairTasks.isEmpty {
            taskSection(title: "Repair Requests", tasks: repairTasks)
        }
        if requestType != .repair, !serviceTasks.isEmpty {
            taskSection(title: "Service Requests", tasks: serviceTasks)
        }
    }

    private func taskSection(title: String, tasks: [MaintenanceTask]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
            }
            ForEach(tasks) { task in
                AdminMaintenanceTaskCard(
                    task: task,
                    vehicle: store.vehicle(for: task.vehicleId),
                    workOrder: store.workOrder(forMaintenanceTask: task.id),
                    phaseSummary: phaseSummary(for: task),
                    onOpenDetail: { selectedTask = task },
                    onOpenVehicle: { if let v = store.vehicle(for: task.vehicleId) { vehicleSheetVehicle = v } }
                )
            }
        }
    }

    // MARK: - Parts Approval

    private var partsApprovalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Parts Approval")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(pendingPartRequests.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
            }
            ForEach(pendingPartRequests) { part in
                let relatedTask = store.maintenanceTasks.first(where: { $0.id == part.maintenanceTaskId })
                AdminSparePartApprovalCard(
                    part: part,
                    task: relatedTask,
                    vehicle: relatedTask.flatMap { store.vehicle(for: $0.vehicleId) },
                    requester: store.staffMember(for: part.requestedById),
                    onApprove: { Task { try? await store.approveSparePartsRequest(id: part.id, reviewedBy: adminId) } },
                    onReject: { rejectPartTarget = part },
                    onOpenTask: { if let t = relatedTask { selectedTask = t } }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 40)
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.35))
            Text("No requests found")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text("Try changing status or filter options.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func matchesRequestType(_ t: MaintenanceTask) -> Bool {
        switch requestType { case .all: true; case .repair: t.taskType != .scheduled; case .service: t.taskType == .scheduled }
    }
    private func matchesStatus(_ t: MaintenanceTask) -> Bool {
        switch statusFilter {
        case .pending: t.status == .pending
        case .active: t.status == .assigned || t.status == .inProgress
        case .completed: t.status == .completed || t.status == .cancelled
        }
    }
    private func matchesSearch(_ t: MaintenanceTask) -> Bool {
        let q = searchText.lowercased()
        let v = store.vehicle(for: t.vehicleId)
        return "MNT-\(t.id.uuidString.prefix(8)) \(t.title) \(v?.licensePlate ?? "") \(v?.name ?? "")".lowercased().contains(q)
    }
    private func phaseSummary(for task: MaintenanceTask) -> String {
        guard let wo = store.workOrder(forMaintenanceTask: task.id) else {
            return task.status == .pending ? "Awaiting approval" : "No work order"
        }
        let phases = store.phases(forWorkOrder: wo.id)
        guard !phases.isEmpty else { return wo.status.rawValue }
        return "\(phases.filter(\.isCompleted).count)/\(phases.count) phases"
    }
}

// MARK: - Admin Task Card

private struct AdminMaintenanceTaskCard: View {
    let task: MaintenanceTask
    let vehicle: Vehicle?
    let workOrder: WorkOrder?
    let phaseSummary: String
    var onOpenDetail: () -> Void
    var onOpenVehicle: () -> Void

    private var taskIdText: String { "MNT-\(task.id.uuidString.prefix(8).uppercased())" }
    private var isPending: Bool { task.status == .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Row 1: ID · type chip · status
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "number").font(.system(size: 10, weight: .bold))
                    Text(taskIdText).font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color.appOrange)

                HStack(spacing: 3) {
                    Image(systemName: task.taskType == .scheduled ? "calendar" : "wrench.and.screwdriver")
                        .font(.system(size: 9, weight: .semibold))
                    Text(task.taskType == .scheduled ? "Service" : "Repair")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.appDivider.opacity(0.3), in: Capsule())

                Spacer()
                statusBadge
            }

            // Row 2: Title + priority
            HStack(alignment: .top) {
                Text(task.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                priorityBadge
            }

            // Row 3: Vehicle pill
            if let v = vehicle {
                Button(action: onOpenVehicle) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appOrange)
                        Text(v.licensePlate).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.appOrange)
                        Text(v.name).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.appOrange.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // Row 4: Phase summary + date
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "list.number").font(.system(size: 11))
                    Text(phaseSummary).font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.appTextSecondary)
                Spacer()
                if let eta = workOrder?.estimatedCompletionAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 11))
                        Text(eta.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.appTextSecondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 11))
                        Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
            }

            Rectangle().fill(Color.appDivider.opacity(0.6)).frame(height: 1)

            // Dual-button row — exact driver flow pattern
            HStack(spacing: 12) {
                Button(action: onOpenDetail) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 13, weight: .semibold))
                        Text("View Details").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.appOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.appOrange.opacity(0.08)))
                    .overlay(Capsule().stroke(Color.appOrange.opacity(0.25), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                if isPending {
                    Button(action: onOpenDetail) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 13, weight: .semibold))
                            Text("Approve").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.appTextPrimary))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 5) {
                        Circle().fill(statusTint).frame(width: 6, height: 6)
                        Text(task.status.rawValue).font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(statusTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(statusTint.opacity(0.09)))
                    .overlay(Capsule().stroke(statusTint.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(statusTint).frame(width: 6, height: 6)
            Text(task.status.rawValue).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(statusTint)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(statusTint.opacity(0.12), in: Capsule())
    }

    private var priorityBadge: some View {
        let c = priorityColor(task.priority)
        return HStack(spacing: 3) {
            Image(systemName: priorityIcon(task.priority)).font(.system(size: 9))
            Text(task.priority.rawValue).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(c)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(c.opacity(0.1), in: Capsule())
    }

    private var statusTint: Color {
        switch task.status {
        case .pending: Color.appOrange; case .assigned: .blue
        case .inProgress: .purple; case .completed: .green; case .cancelled: .gray
        }
    }
    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p { case .low: .green; case .medium: .blue; case .high: .orange; case .urgent: .red }
    }
    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p { case .low: "arrow.down"; case .medium: "minus"; case .high: "arrow.up"; case .urgent: "exclamationmark.2" }
    }
}

// MARK: - Spare Part Approval Card

private struct AdminSparePartApprovalCard: View {
    let part: SparePartsRequest
    let task: MaintenanceTask?
    let vehicle: Vehicle?
    let requester: StaffMember?
    var onApprove: () -> Void
    var onReject: () -> Void
    var onOpenTask: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(part.partName).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                    if let pn = part.partNumber, !pn.isEmpty {
                        Text("Part #\(pn)").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
                Text("×\(part.quantity)")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Color.appOrange.opacity(0.1), in: Capsule())
            }

            if let t = task {
                Button(action: onOpenTask) {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver").font(.system(size: 11))
                        Text(t.title).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 10))
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.appDivider.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                if let v = vehicle {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill").font(.system(size: 11))
                        Text(v.licensePlate).font(.system(size: 11, weight: .bold, design: .monospaced))
                    }.foregroundStyle(Color.appOrange)
                }
                if let r = requester {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill").font(.system(size: 11))
                        Text(r.displayName).font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(1)
                    }.foregroundStyle(Color.appTextSecondary)
                }
            }

            Rectangle().fill(Color.appDivider.opacity(0.6)).frame(height: 1)

            HStack(spacing: 12) {
                Button(action: onReject) {
                    Text("Reject").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.red)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(Color.red.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.red.opacity(0.2), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                Button(action: onApprove) {
                    Text("Approve").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(Color.appTextPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appCardBg).shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Reject Reason Sheet

private struct RejectReasonSheet: View {
    let title: String
    let subtitle: String
    let placeholder: String
    let confirmTitle: String
    let confirmColor: Color
    let onConfirm: (String) -> Void

    @State private var reason = ""
    @Environment(\.dismiss) private var dismiss
    private var trimmed: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appCardBg)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appDivider, lineWidth: 1))
                        .frame(minHeight: 130)
                    if reason.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appTextSecondary.opacity(0.5))
                            .padding(14)
                    }
                    TextEditor(text: $reason)
                        .frame(minHeight: 130)
                        .padding(10)
                        .background(Color.clear)
                }

                Button {
                    onConfirm(trimmed); dismiss()
                } label: {
                    Text(confirmTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(trimmed.isEmpty ? Color.gray : confirmColor, in: Capsule())
                }
                .disabled(trimmed.isEmpty)

                Spacer()
            }
            .padding(20)
            .background(Color.appSurface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appOrange)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

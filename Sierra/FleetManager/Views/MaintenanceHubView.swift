import SwiftUI

// MARK: - MaintenanceHubView
/// Admin-facing maintenance panel embedded in VehicleListView's "Maintenance" segment.
/// Driver-style minimalist UI: light background, floating cards, clear primary actions.

struct MaintenanceHubView: View {
    @Environment(AppDataStore.self) private var store
    private let canvasColor = Color(UIColor.secondarySystemBackground)

    enum RequestTypeFilter: String, CaseIterable {
        case all = "All"
        case repair = "Repair"
        case service = "Service"
    }

    enum StatusFilter: String, CaseIterable {
        case pending = "Pending"
        case active = "Active"
        case completed = "Completed"
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
        allTasks.filter { task in
            if !matchesRequestType(task) { return false }
            if !matchesStatus(task) { return false }
            if !searchText.isEmpty, !matchesSearch(task) { return false }
            return true
        }
    }

    private var repairTasks: [MaintenanceTask] {
        filteredTasks.filter { $0.taskType != .scheduled }
    }

    private var serviceTasks: [MaintenanceTask] {
        filteredTasks.filter { $0.taskType == .scheduled }
    }

    private var pendingPartRequests: [SparePartsRequest] {
        store.sparePartsRequests
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var totalTasksCount: Int { store.maintenanceTasks.count }

    private var urgentCount: Int {
        store.maintenanceTasks.filter {
            $0.priority == .urgent && ($0.status == .pending || $0.status == .assigned || $0.status == .inProgress)
        }.count
    }

    private var completedCount: Int {
        store.maintenanceTasks.filter { $0.status == .completed }.count
    }

    var body: some View {
        VStack(spacing: 12) {
            summaryRow

            if filteredTasks.isEmpty && pendingPartRequests.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        tasksSections
                        if !pendingPartRequests.isEmpty {
                            partsApprovalSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.top, 10)
        .background(canvasColor.ignoresSafeArea())
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search task ID, vehicle, or title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInventoryAdmin = true
                } label: {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appOrange)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
        .navigationDestination(item: $selectedTask) { task in
            MaintenanceApprovalDetailView(task: task) {
                Task { await store.loadAll() }
            }
        }
        .sheet(item: $vehicleSheetVehicle) { vehicle in
            VehicleQuickStatusSheet(vehicle: vehicle)
                .environment(store)
        }
        .sheet(item: $rejectPartTarget) { part in
            RejectReasonSheet(
                title: "Reject Part Request",
                subtitle: "Add a reason so maintenance staff can proceed correctly.",
                placeholder: "Reason",
                confirmTitle: "Reject Part",
                confirmColor: .red
            ) { reason in
                guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task {
                    try? await store.rejectSparePartsRequest(id: part.id, reviewedBy: adminId, reason: reason)
                }
            }
        }
        .sheet(isPresented: $showInventoryAdmin) {
            InventoryAdminView()
                .environment(store)
        }
        .task {
            if store.maintenanceTasks.isEmpty || store.workOrders.isEmpty { await store.loadAll() }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryCard(value: totalTasksCount, label: "Total", icon: "list.bullet.rectangle.fill", color: Color.appOrange)
            summaryCard(value: urgentCount, label: "Urgent", icon: "flame.fill", color: .red)
            summaryCard(value: completedCount, label: "Completed", icon: "checkmark.seal.fill", color: .green)
        }
        .padding(.horizontal, 16)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Type", selection: $requestType) {
                ForEach(RequestTypeFilter.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            if requestType != .all || statusFilter != .active {
                Divider()
                Button("Reset Filters") {
                    requestType = .all
                    statusFilter = .active
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.appTextPrimary)
        }
    }

    private func summaryCard(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

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
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
            }

            ForEach(tasks) { task in
                AdminMaintenanceTaskCard(
                    task: task,
                    vehicle: store.vehicle(for: task.vehicleId),
                    workOrder: store.workOrder(forMaintenanceTask: task.id),
                    phaseSummary: phaseSummary(for: task),
                    onOpenDetail: { selectedTask = task },
                    onOpenVehicle: {
                        if let v = store.vehicle(for: task.vehicleId) {
                            vehicleSheetVehicle = v
                        }
                    }
                )
            }
        }
    }

    private var partsApprovalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Parts Approval")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text("\(pendingPartRequests.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
            }

            ForEach(pendingPartRequests) { part in
                let relatedTask = store.maintenanceTasks.first(where: { $0.id == part.maintenanceTaskId })
                let vehicle = relatedTask.flatMap { store.vehicle(for: $0.vehicleId) }
                AdminSparePartApprovalCard(
                    part: part,
                    task: relatedTask,
                    vehicle: vehicle,
                    requester: store.staffMember(for: part.requestedById),
                    onApprove: {
                        Task { try? await store.approveSparePartsRequest(id: part.id, reviewedBy: adminId) }
                    },
                    onReject: {
                        rejectPartTarget = part
                    },
                    onOpenTask: {
                        if let t = relatedTask { selectedTask = t }
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 28)
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.35))
            Text("No requests found")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text("Try changing status or filter options.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func matchesRequestType(_ task: MaintenanceTask) -> Bool {
        switch requestType {
        case .all: return true
        case .repair: return task.taskType != .scheduled
        case .service: return task.taskType == .scheduled
        }
    }

    private func matchesStatus(_ task: MaintenanceTask) -> Bool {
        switch statusFilter {
        case .pending: return task.status == .pending
        case .active: return task.status == .assigned || task.status == .inProgress
        case .completed: return task.status == .completed || task.status == .cancelled
        }
    }

    private func matchesSearch(_ task: MaintenanceTask) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }

        let idText = shortTaskId(task).lowercased()
        let titleText = task.title.lowercased()
        let descText = task.taskDescription.lowercased()
        let vehicle = store.vehicle(for: task.vehicleId)
        let vehicleText = "\(vehicle?.licensePlate ?? "") \(vehicle?.name ?? "") \(vehicle?.model ?? "")".lowercased()

        return idText.contains(q) || titleText.contains(q) || descText.contains(q) || vehicleText.contains(q)
    }

    private func shortTaskId(_ task: MaintenanceTask) -> String {
        "MNT-\(task.id.uuidString.prefix(8).uppercased())"
    }

    private func phaseSummary(for task: MaintenanceTask) -> String {
        guard let wo = store.workOrder(forMaintenanceTask: task.id) else {
            return task.status == .pending ? "Awaiting approval" : "No work order"
        }
        let phases = store.phases(forWorkOrder: wo.id)
        guard !phases.isEmpty else {
            return wo.status.rawValue
        }
        let done = phases.filter(\.isCompleted).count
        return "\(done)/\(phases.count) phases complete"
    }
}

// MARK: - Task Card

private struct AdminMaintenanceTaskCard: View {
    let task: MaintenanceTask
    let vehicle: Vehicle?
    let workOrder: WorkOrder?
    let phaseSummary: String
    var onOpenDetail: () -> Void
    var onOpenVehicle: () -> Void

    private var taskIdText: String { "MNT-\(task.id.uuidString.prefix(8).uppercased())" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Text("#")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appOrange)
                    Image(systemName: "number")
                        .font(.system(size: 11, weight: .bold))
                    Text(taskIdText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color.appTextSecondary)

                HStack(spacing: 4) {
                    Image(systemName: task.taskType == .scheduled ? "calendar" : "wrench.and.screwdriver")
                        .font(.system(size: 10, weight: .semibold))
                    Text(task.taskType == .scheduled ? "Service" : "Repair")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemFill), in: Capsule())

                Spacer()

                statusBadge
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    Text(task.taskDescription)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }
            }

            if let vehicle {
                Button(action: onOpenVehicle) {
                    HStack(spacing: 10) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.appOrange)
                            .frame(width: 26, height: 26)
                            .background(Color.appOrange.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vehicle.licensePlate)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.appOrange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appOrange.opacity(0.12), in: Capsule())
                            Text("\(vehicle.name) · \(vehicle.model)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.appOrange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Label(phaseSummary, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                if let eta = workOrder?.estimatedCompletionAt {
                    Label(eta.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                } else {
                    Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Rectangle()
                .fill(Color.appDivider.opacity(0.6))
                .frame(height: 1)

            HStack(spacing: 8) {
                Spacer()
                Button(action: onOpenDetail) {
                    Text("View Details")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var statusBadge: some View {
        let tint: Color
        switch task.status {
        case .pending: tint = Color.appOrange
        case .assigned: tint = .blue
        case .inProgress: tint = .blue
        case .completed: tint = .green
        case .cancelled: tint = .secondary
        }

        return HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(task.status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - Spare Part Card

private struct AdminSparePartApprovalCard: View {
    let part: SparePartsRequest
    let task: MaintenanceTask?
    let vehicle: Vehicle?
    let requester: StaffMember?
    var onApprove: () -> Void
    var onReject: () -> Void
    var onOpenTask: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(part.partName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    if let number = part.partNumber, !number.isEmpty {
                        Text("Part #\(number)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
                Text("x\(part.quantity)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
            }

            if let task {
                Button(action: onOpenTask) {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver")
                        Text(task.title)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                if let vehicle {
                    Label(vehicle.licensePlate, systemImage: "car.fill")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.appOrange)
                }
                if let requester {
                    Label(requester.displayName, systemImage: "person.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Button(action: onReject) {
                    Text("Reject")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onApprove) {
                    Text("Approve")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)

                TextEditor(text: $reason)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        Group {
                            if reason.isEmpty {
                                HStack {
                                    Text(placeholder)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.appTextSecondary.opacity(0.7))
                                        .padding(.leading, 14)
                                        .padding(.top, 18)
                                    Spacer()
                                }
                            }
                        }
                    )

                Button {
                    onConfirm(reason)
                    dismiss()
                } label: {
                    Text(confirmTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(confirmColor, in: Capsule())
                }

                Spacer()
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.97, blue: 0.98).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

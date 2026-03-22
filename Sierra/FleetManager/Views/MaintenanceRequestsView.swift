import SwiftUI

// MARK: - Top-level section

enum MaintenanceSection: String, CaseIterable {
    case tasks      = "Tasks"
    case spareParts = "Spare Parts"
    case history    = "History"
}

// MARK: - Sub-filters

enum TaskApprovalFilter: String, CaseIterable {
    case pending  = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
    case all      = "All"
}

enum SparePartsFilter: String, CaseIterable {
    case pending  = "Pending"
    case reviewed = "Reviewed"
    case all      = "All"
}

/// Wrapper to disambiguate navigation destinations (tasks use plain UUID, records use this).
struct MaintenanceRecordDestination: Hashable {
    let id: UUID
}

/// Fleet manager view of maintenance tasks, spare parts requests, and history.
struct MaintenanceRequestsView: View {

    @Environment(AppDataStore.self) private var store
    @State private var selectedSection: MaintenanceSection = .tasks

    // Tasks state
    @State private var taskFilter: TaskApprovalFilter = .pending
    @State private var tasks: [MaintenanceTask] = []
    @State private var isLoadingTasks = false

    // Spare parts state
    @State private var sparePartsFilter: SparePartsFilter = .pending
    @State private var rejectTarget: SparePartsRequest? = nil
    @State private var rejectionReason = ""
    @State private var showRejectAlert = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    var body: some View {
        VStack(spacing: 0) {
            // Top-level segment
            Picker("Section", selection: $selectedSection) {
                ForEach(MaintenanceSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let error = store.loadError {
                SierraErrorView(message: error) {
                    await store.loadAll()
                }
            } else {
                switch selectedSection {
                case .tasks:      tasksSection
                case .spareParts: sparePartsSection
                case .history:    historySection
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadAllTasks() }
        .refreshable { await loadAllTasks() }
        .navigationDestination(for: UUID.self) { taskId in
            if let task = tasks.first(where: { $0.id == taskId }) {
                MaintenanceApprovalDetailView(task: task) {
                    Task { await loadAllTasks() }
                }
            }
        }
        .navigationDestination(for: MaintenanceRecordDestination.self) { dest in
            if let record = store.maintenanceRecords.first(where: { $0.id == dest.id }) {
                MaintenanceHistoryDetailView(record: record)
            }
        }
        .alert("Reject Spare Part", isPresented: $showRejectAlert) {
            TextField("Reason for rejection", text: $rejectionReason)
            Button("Reject", role: .destructive) {
                guard let req = rejectTarget else { return }
                Task {
                    try? await store.rejectSparePartsRequest(id: req.id, reviewedBy: currentUserId, reason: rejectionReason)
                    rejectionReason = ""
                    rejectTarget = nil
                }
            }
            Button("Cancel", role: .cancel) {
                rejectionReason = ""
                rejectTarget = nil
            }
        } message: {
            if let req = rejectTarget {
                Text("Reject \"\(req.partName)\" request?")
            }
        }
    }

    // MARK: - Tasks Section (existing logic preserved)

    private var filteredTasks: [MaintenanceTask] {
        switch taskFilter {
        case .pending:  return tasks.filter { $0.status == .pending }
        case .approved: return tasks.filter { $0.status == .assigned || $0.status == .inProgress || $0.status == .completed }
        case .rejected: return tasks.filter { $0.status == .cancelled }
        case .all:      return tasks
        }
    }

    private var tasksSection: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $taskFilter) {
                ForEach(TaskApprovalFilter.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if isLoadingTasks && tasks.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredTasks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No \(taskFilter.rawValue.lowercased()) tasks")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredTasks) { task in
                        NavigationLink(value: task.id) {
                            taskRow(task)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Spare Parts Section

    private var filteredSparePartsRequests: [SparePartsRequest] {
        switch sparePartsFilter {
        case .pending:  return store.sparePartsRequests.filter { $0.status == .pending }
        case .reviewed: return store.sparePartsRequests.filter { $0.status != .pending }
        case .all:      return store.sparePartsRequests
        }
    }

    private var sparePartsSection: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $sparePartsFilter) {
                ForEach(SparePartsFilter.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            let requests = filteredSparePartsRequests
            if requests.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No \(sparePartsFilter.rawValue.lowercased()) spare parts requests")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(requests) { req in
                        sparePartRow(req)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if req.status == .pending {
                                    Button {
                                        rejectTarget = req
                                        showRejectAlert = true
                                    } label: {
                                        Label("Reject", systemImage: "xmark.circle")
                                    }
                                    .tint(.red)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if req.status == .pending {
                                    Button {
                                        Task {
                                            try? await store.approveSparePartsRequest(id: req.id, reviewedBy: currentUserId)
                                        }
                                    } label: {
                                        Label("Approve", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - History Section

    private var sortedRecords: [MaintenanceRecord] {
        store.maintenanceRecords.sorted { $0.serviceDate > $1.serviceDate }
    }

    private var historySection: some View {
        Group {
            let records = sortedRecords
            if records.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No maintenance history")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink(value: MaintenanceRecordDestination(id: record.id)) {
                            historyRow(record)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Row Builders

    private func taskRow(_ task: MaintenanceTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                priorityBadge(task.priority)
            }
            HStack(spacing: 12) {
                let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
                Text(vehicle?.licensePlate ?? "Vehicle")
                    .font(.caption).foregroundStyle(.secondary)

                let raisedBy = store.staff.first(where: { $0.id == task.createdByAdminId })
                if let name = raisedBy?.name {
                    Text("by \(name)").font(.caption).foregroundStyle(.tertiary)
                }

                Spacer()

                Text(task.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            statusBadge(task.status)
        }
        .padding(.vertical, 4)
    }

    private func sparePartRow(_ req: SparePartsRequest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(req.partName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                sparePartsStatusBadge(req.status)
            }

            HStack(spacing: 12) {
                Text("Qty: \(req.quantity)")
                    .font(.caption).foregroundStyle(.secondary)

                if let cost = req.estimatedUnitCost {
                    Text("₹\(cost * Double(req.quantity), specifier: "%.0f")")
                        .font(.caption.weight(.medium)).foregroundStyle(.primary)
                }

                Spacer()

                Text(req.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                let requester = store.staffMember(for: req.requestedById)
                Text("By \(requester?.name ?? "Unknown")")
                    .font(.caption).foregroundStyle(.secondary)

                if let task = store.maintenanceTasks.first(where: { $0.id == req.maintenanceTaskId }) {
                    Text("• \(task.title)")
                        .font(.caption).foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if !req.reason.isEmpty {
                Text(req.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func historyRow(_ record: MaintenanceRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                let vehicle = store.vehicle(for: record.vehicleId)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle?.name ?? "Unknown Vehicle")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let plate = vehicle?.licensePlate {
                        Text(plate)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(record.serviceDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Text(record.issueReported)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                let performer = store.staffMember(for: record.performedById)
                Text(performer?.name ?? "Unknown")
                    .font(.caption).foregroundStyle(.tertiary)

                Spacer()

                Text("₹\(record.totalCost, specifier: "%.0f")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Badges

    private func priorityBadge(_ p: TaskPriority) -> some View {
        Text(p.rawValue)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(priorityColor(p), in: Capsule())
    }

    private func statusBadge(_ s: MaintenanceTaskStatus) -> some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor(s)).frame(width: 6, height: 6)
            Text(s.rawValue).font(.caption2.weight(.medium)).foregroundStyle(statusColor(s))
        }
    }

    private func sparePartsStatusBadge(_ s: SparePartsRequestStatus) -> some View {
        let color: Color = switch s {
        case .pending:   .orange
        case .approved:  .green
        case .rejected:  .red
        case .fulfilled: .blue
        }
        return Text(s.rawValue)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color, in: Capsule())
    }

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

    // MARK: - Load

    private func loadAllTasks() async {
        isLoadingTasks = true
        do {
            tasks = try await MaintenanceTaskService.fetchAllMaintenanceTasks()
        } catch {
            print("[MaintRequests] Error: \(error)")
        }
        isLoadingTasks = false
    }
}

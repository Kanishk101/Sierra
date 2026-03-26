import SwiftUI

// MARK: - ServiceTaskListView

struct ServiceTaskListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedFilter: MaintenanceTaskStatus? = nil
    @State private var searchText = ""
    @State private var showProfile = false

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var serviceTasks: [MaintenanceTask] {
        store.maintenanceTasks.filter { task in
            guard task.assignedToId == currentUserId else { return false }
            if let workOrder = store.workOrder(forMaintenanceTask: task.id) { return workOrder.workOrderType == .service }
            return task.taskType == .scheduled
        }
    }

    private var filteredTasks: [MaintenanceTask] {
        serviceTasks.filter { task in
            if let f = selectedFilter {
                if f == .assigned {
                    if !task.isEffectivelyAssigned { return false }
                } else if task.status != f {
                    return false
                }
            }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty { return true }
            let vehicle = store.vehicle(for: task.vehicleId)
            let idText = "MNT-\(task.id.uuidString.prefix(8).uppercased())".lowercased()
            let blob = "\(task.title) \(vehicle?.licensePlate ?? "") \(vehicle?.name ?? "")".lowercased()
            return idText.contains(q) || blob.contains(q)
        }
    }

    private var isFilterActive: Bool { selectedFilter != nil }
    private var totalCount: Int     { serviceTasks.count }
    private var activeCount: Int    { serviceTasks.filter { $0.isEffectivelyAssigned || $0.status == .inProgress }.count }
    private var completedCount: Int { serviceTasks.filter { $0.status == .completed }.count }

    var body: some View {
        VStack(spacing: 0) {
            searchBar.padding(.top, 12).padding(.bottom, 8)
            summaryRow.padding(.bottom, 6)

            if filteredTasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredTasks) { task in
                            NavigationLink(value: task) { TaskCard(task: task, store: store) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 28)
                }
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { filterMenuButton }
            ToolbarItem(placement: .topBarLeading)  { profileButton  }
        }
        .navigationDestination(for: MaintenanceTask.self) { MaintenanceTaskDetailView(task: $0) }
        .sheet(isPresented: $showProfile) { MaintenanceProfileView().environment(store) }
        .task { await store.loadMaintenanceData(staffId: currentUserId) }
        .refreshable { await store.loadMaintenanceData(staffId: currentUserId) }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.appTextSecondary)
            TextField("Search task ID, vehicle, title…", text: $searchText)
                .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                .font(.system(size: 14, weight: .medium, design: .rounded))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Capsule().fill(Color.appCardBg))
        .overlay(Capsule().stroke(Color.appDivider.opacity(0.45), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Summary Row (coloured pills — no boring uniform grey boxes)

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryPill(value: totalCount,     label: "Total",  tint: Color.appOrange, icon: "list.bullet.rectangle.fill")
            summaryPill(value: activeCount,    label: "Active", tint: .blue,           icon: "clock.fill")
            summaryPill(value: completedCount, label: "Done",   tint: .green,          icon: "checkmark.seal.fill")
        }
        .padding(.horizontal, 20)
    }

    private func summaryPill(value: Int, label: String, tint: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text("\(value)").font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(tint.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Filter Menu

    private var filterMenuButton: some View {
        Menu {
            Button { selectedFilter = nil } label: { Label("All", systemImage: selectedFilter == nil ? "checkmark" : "") }
            Divider()
            ForEach(MaintenanceTaskStatus.allCases, id: \.self) { status in
                Button { selectedFilter = (selectedFilter == status) ? nil : status } label: {
                    Label(status.rawValue, systemImage: selectedFilter == status ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.appOrange)
        }
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        Button { showProfile = true } label: {
            if let staffer = store.staff.first(where: { $0.id == AuthManager.shared.currentUser?.id }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.appOrange, Color.appDeepOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Text(staffer.initials).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
            } else {
                Image(systemName: "person.circle.fill").font(.system(size: 28)).foregroundStyle(Color.appOrange)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 60)
            Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle" : "calendar.badge.checkmark")
                .font(.system(size: 48, weight: .light)).foregroundStyle(Color.appOrange.opacity(0.3))
            Text(isFilterActive ? "No Matches" : "No Service Tasks")
                .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Color.appTextPrimary).padding(.top, 6)
            Text(isFilterActive ? "Try a different filter." : "No assigned service tasks right now.")
                .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(Color.appTextSecondary).multilineTextAlignment(.center)
            if isFilterActive {
                Button { selectedFilter = nil } label: {
                    Text("Clear Filter").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Color.appOrange)
                        .padding(.horizontal, 20).padding(.vertical, 10).background(Color.appOrange.opacity(0.1), in: Capsule())
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Shared Task Card
/// Used by ServiceTaskListView, RepairTaskListView, and MaintenanceHomeView.
/// — No task description shown (per design spec)
/// — Shows: ID · status · title · priority · vehicle pill · due date / ETA

struct TaskCard: View {
    let task: MaintenanceTask
    let store: AppDataStore

    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }
    private var taskIdText: String { "MNT-\(task.id.uuidString.prefix(8).uppercased())" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Row 1: ID + status
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "number").font(.system(size: 10, weight: .bold))
                    Text(taskIdText).font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color.appOrange)
                Spacer()
                statusPill
            }

            // Row 2: Title + priority
            HStack(alignment: .top) {
                Text(task.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                priorityPill
            }

            // Row 3: Vehicle pill
            if let v = vehicle {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.appOrange)
                    Text(v.licensePlate).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.appOrange)
                    Text(v.name).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextSecondary).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.appOrange.opacity(0.07), in: Capsule())
            }

            // Divider
            Rectangle().fill(Color.appDivider.opacity(0.6)).frame(height: 1)

            // Row 4: Due date + ETA
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "calendar").font(.system(size: 11))
                    Text(task.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.appTextSecondary)
                Spacer()
                if let eta = workOrder?.estimatedCompletionAt {
                    HStack(spacing: 5) {
                        Image(systemName: "clock").font(.system(size: 11))
                        Text("ETA \(eta.formatted(.dateTime.day().month(.abbreviated).hour().minute()))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1)
                    }
                    .foregroundStyle(Color.appTextSecondary)
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

    private var statusPill: some View {
        let t = statusColor(task.status)
        return HStack(spacing: 4) {
            Circle().fill(t).frame(width: 6, height: 6)
            Text(task.status.rawValue).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(t)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(t.opacity(0.12), in: Capsule())
    }

    private var priorityPill: some View {
        let c = priorityColor(task.priority)
        return HStack(spacing: 3) {
            Image(systemName: priorityIcon(task.priority)).font(.system(size: 9))
            Text(task.priority.rawValue).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(c)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(c.opacity(0.1), in: Capsule())
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s { case .pending: .gray; case .assigned: .blue; case .inProgress: .purple; case .completed: .green; case .cancelled: .red }
    }
    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p { case .low: .green; case .medium: .blue; case .high: .orange; case .urgent: .red }
    }
    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p { case .low: "arrow.down"; case .medium: "minus"; case .high: "arrow.up"; case .urgent: "exclamationmark.2" }
    }
}

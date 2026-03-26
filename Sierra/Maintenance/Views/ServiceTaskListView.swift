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
            // Backend-safe fallback:
            // show scheduled/service tasks even before a work order row exists.
            if let workOrder = store.workOrder(forMaintenanceTask: task.id) {
                return workOrder.workOrderType == .service
            }
            return task.taskType == .scheduled
        }
    }

    private var filteredTasks: [MaintenanceTask] {
        serviceTasks.filter { task in
            if let f = selectedFilter, task.status != f { return false }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty { return true }

            let vehicle = store.vehicle(for: task.vehicleId)
            let idText = "MNT-\(task.id.uuidString.prefix(8).uppercased())".lowercased()
            let blob = "\(task.title) \(task.taskDescription) \(vehicle?.licensePlate ?? "") \(vehicle?.name ?? "")".lowercased()
            return idText.contains(q) || blob.contains(q)
        }
    }

    private var isFilterActive: Bool { selectedFilter != nil }
    private var totalCount: Int { serviceTasks.count }
    private var activeCount: Int { serviceTasks.filter { $0.status == .assigned || $0.status == .inProgress }.count }
    private var completedCount: Int { serviceTasks.filter { $0.status == .completed }.count }

    var body: some View {
        VStack(spacing: 10) {
            searchBar
            summaryRow

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTasks) { task in
                        NavigationLink(value: task) {
                            TaskCard(task: task, store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .overlay {
            if filteredTasks.isEmpty { emptyState }
        }
        .background(Color.appSurface.ignoresSafeArea())
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { filterMenuButton }
            ToolbarItem(placement: .topBarLeading) { profileButton }
        }
        .navigationDestination(for: MaintenanceTask.self) { task in
            MaintenanceTaskDetailView(task: task)
        }
        .sheet(isPresented: $showProfile) {
            MaintenanceProfileView()
                .environment(store)
        }
        .task {
            await store.loadMaintenanceData(staffId: currentUserId)
        }
        .refreshable {
            await store.loadMaintenanceData(staffId: currentUserId)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextSecondary)
            TextField("Search task ID, vehicle, title", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(Color.appCardBg)
        )
        .overlay(
            Capsule()
                .stroke(Color.appDivider.opacity(0.45), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryBox(value: totalCount, label: "Total", icon: "list.bullet.rectangle.fill", tint: .appOrange)
            summaryBox(value: activeCount, label: "Active", icon: "clock.fill", tint: .blue)
            summaryBox(value: completedCount, label: "Done", icon: "checkmark.seal.fill", tint: .green)
        }
        .padding(.horizontal, 16)
    }

    private func summaryBox(value: Int, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text("\(value)")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Toolbar Filter

    private var filterMenuButton: some View {
        Menu {
            Button {
                selectedFilter = nil
            } label: {
                Label("All", systemImage: selectedFilter == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(MaintenanceTaskStatus.allCases, id: \.self) { status in
                Button {
                    selectedFilter = (selectedFilter == status) ? nil : status
                } label: {
                    Label(status.rawValue, systemImage: selectedFilter == status ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle\(isFilterActive ? ".fill" : "")")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.appOrange)
        }
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        Button { showProfile = true } label: {
            if let staffer = store.staff.first(where: { $0.id == AuthManager.shared.currentUser?.id }) {
                let initials = initials(for: staffer.name ?? "MP")
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appOrange, Color.appDeepOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Text(initials)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.appOrange)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle" : "calendar.badge.checkmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text(isFilterActive ? "No Matches" : "No Service Tasks")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text(isFilterActive ? "Try a different filter." : "No assigned service tasks right now.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            if isFilterActive {
                Button { selectedFilter = nil } label: {
                    Text("Clear Filter")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appOrange)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.appOrange.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(40)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        switch parts.count {
        case 0:  return "?"
        case 1:  return String(parts[0].prefix(2)).uppercased()
        default: return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
    }
}

// MARK: - Shared Task Card (minimalist, used by both Service and Repair lists)

struct TaskCard: View {
    let task: MaintenanceTask
    let store: AppDataStore

    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }
    private var taskIdText: String { "MNT-\(task.id.uuidString.prefix(8).uppercased())" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                HStack(spacing: 5) {
                    Image(systemName: "number")
                        .font(.system(size: 10, weight: .bold))
                    Text(taskIdText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color.appOrange)
                Spacer()
                statusPill
            }

            HStack(alignment: .top) {
                Text(task.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                Spacer()
                priorityPill
            }

            if let v = vehicle {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.appOrange)
                    Text(v.licensePlate)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.appOrange)
                    Text(v.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.appOrange.opacity(0.08), in: Capsule())
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(task.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.appTextSecondary)

                Spacer()

                if let eta = workOrder?.estimatedCompletionAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(eta.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(1)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.appDivider.opacity(0.35), lineWidth: 1)
        )
    }

    private var statusPill: some View {
        let tint = statusColor(task.status)
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

    private var priorityPill: some View {
        HStack(spacing: 3) {
            Image(systemName: priorityIcon(task.priority))
                .font(.system(size: 9))
            Text(task.priority.rawValue)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(priorityColor(task.priority))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(priorityColor(task.priority).opacity(0.1), in: Capsule())
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s {
        case .pending:    return .gray
        case .assigned:   return .blue
        case .inProgress: return .purple
        case .completed:  return .green
        case .cancelled:  return .red
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low:    return .green
        case .medium: return .blue
        case .high:   return .orange
        case .urgent: return .red
        }
    }

    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
}

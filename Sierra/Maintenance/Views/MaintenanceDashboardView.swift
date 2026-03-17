import SwiftUI

/// Full maintenance dashboard showing assigned tasks with filters.
/// Replaces the skeleton placeholder.
struct MaintenanceDashboardView: View {
    @State private var selectedTab: MaintenanceTab = .tasks
    @State private var viewModel = MaintenanceDashboardViewModel()
    @State private var showNotifications = false
    @Environment(AppDataStore.self) private var store

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    enum MaintenanceTab: Int, CaseIterable {
        case tasks, workOrders, vinScanner, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tasksTab
                .tag(MaintenanceTab.tasks)
                .tabItem {
                    Image(systemName: "list.clipboard.fill")
                    Text("Tasks")
                }

            comingSoonTab(icon: "doc.text.fill", title: "Work Orders", subtitle: "Your work orders and repair logs will be managed here.")
                .tag(MaintenanceTab.workOrders)
                .tabItem {
                    Image(systemName: "doc.plaintext.fill")
                    Text("Work Orders")
                }

            comingSoonTab(icon: "barcode.viewfinder", title: "VIN Scanner", subtitle: "Scan vehicle VIN barcodes for quick lookup.")
                .tag(MaintenanceTab.vinScanner)
                .tabItem {
                    Image(systemName: "barcode.viewfinder")
                    Text("VIN Scanner")
                }

            profileTab
                .tag(MaintenanceTab.profile)
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
        }
        .tint(.orange)
    }

    // MARK: - Tasks Tab

    private var tasksTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Vehicle chips
                if !viewModel.uniqueVehicleIds.isEmpty {
                    vehicleChips
                }

                // Task list
                if viewModel.isLoading && viewModel.assignedTasks.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Tasks")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text("\(viewModel.filteredTasks.count)")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                }
            }
            .task {
                await viewModel.loadTasks(for: currentUserId)
            }
            .refreshable {
                await viewModel.refresh(for: currentUserId)
            }
            .navigationDestination(for: UUID.self) { taskId in
                if let task = viewModel.assignedTasks.first(where: { $0.id == taskId }) {
                    MaintenanceTaskDetailView(task: task)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNotifications = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill").font(.body).foregroundStyle(.primary)
                            if store.unreadNotificationCount > 0 {
                                Text("\(store.unreadNotificationCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(.red, in: Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationCentreView()
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        Picker("Filter", selection: Binding(
            get: { viewModel.selectedFilter },
            set: { viewModel.filterByStatus($0) }
        )) {
            ForEach(MaintenanceDashboardViewModel.TaskFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Vehicle Chips

    private var vehicleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "All Vehicles", isSelected: viewModel.selectedVehicleFilter == nil) {
                    viewModel.filterByVehicle(nil)
                }
                ForEach(viewModel.uniqueVehicleIds, id: \.self) { vId in
                    let vehicle = store.vehicles.first(where: { $0.id == vId })
                    chipButton(
                        label: vehicle?.licensePlate ?? vId.uuidString.prefix(8).description,
                        isSelected: viewModel.selectedVehicleFilter == vId
                    ) {
                        viewModel.filterByVehicle(vId)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.secondarySystemBackground), in: Capsule())
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            ForEach(viewModel.filteredTasks) { task in
                NavigationLink(value: task.id) {
                    taskRow(task)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func taskRow(_ task: MaintenanceTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    let vehicle = store.vehicles.first(where: { $0.id == task.vehicleId })
                    Text("\(vehicle?.name ?? "Vehicle") • \(vehicle?.licensePlate ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                priorityBadge(task.priority)
            }

            HStack(spacing: 12) {
                statusBadge(task.status)
                Spacer()
                Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timeAgo(task.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        Text(priority.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priorityColor(priority), in: Capsule())
    }

    private func statusBadge(_ status: MaintenanceTaskStatus) -> some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor(status)).frame(width: 6, height: 6)
            Text(status.rawValue)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor(status))
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private func statusColor(_ s: MaintenanceTaskStatus) -> Color {
        switch s {
        case .pending: return .orange
        case .assigned: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.orange.opacity(0.4))
            Text("No tasks match this filter")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Coming Soon (unchanged)

    private func comingSoonTab(icon: String, title: String, subtitle: String) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.orange.opacity(0.5))
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 48)
                Text("Coming Soon")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    // MARK: - Profile Tab

    private var profileTab: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                let user = AuthManager.shared.currentUser
                let initials = (user?.name ?? "M").prefix(2).uppercased()
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    )
                VStack(spacing: 6) {
                    Text(user?.name ?? "Maintenance Staff").font(.title3.weight(.semibold))
                    Text(user?.email ?? "").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "wrench.fill").font(.caption2)
                    Text("Maintenance Personnel").font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color.blue.opacity(0.06), in: Capsule())

                HStack(spacing: 8) {
                    Image(systemName: user?.isApproved == true ? "checkmark.seal.fill" : "clock.fill")
                        .foregroundStyle(user?.isApproved == true ? .green : .orange)
                    Text(user?.isApproved == true ? "Approved" : "Pending Approval").font(.subheadline)
                }
                .padding(16).frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

                Spacer()
                Button {
                    AuthManager.shared.signOut()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right").font(.caption)
                        Text("Sign Out").font(.subheadline)
                    }
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}

#Preview {
    MaintenanceDashboardView()
}

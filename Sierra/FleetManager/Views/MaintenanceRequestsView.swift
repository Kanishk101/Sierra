import SwiftUI

/// Fleet manager view of all maintenance tasks for review.
struct MaintenanceRequestsView: View {

    enum ApprovalTab: String, CaseIterable {
        case pending = "Pending"
        case approved = "Approved"
        case rejected = "Rejected"
        case all = "All"
    }

    @State private var selectedTab: ApprovalTab = .pending
    @State private var tasks: [MaintenanceTask] = []
    @State private var isLoading = false
    @Environment(AppDataStore.self) private var store

    var filteredTasks: [MaintenanceTask] {
        switch selectedTab {
        case .pending: return tasks.filter { $0.status == .pending }
        case .approved: return tasks.filter { $0.status == .assigned || $0.status == .inProgress || $0.status == .completed }
        case .rejected: return tasks.filter { $0.status == .cancelled }
        case .all: return tasks
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(ApprovalTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if isLoading && tasks.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredTasks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No \(selectedTab.rawValue.lowercased()) tasks")
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadAllTasks()
        }
        .refreshable {
            await loadAllTasks()
        }
        .navigationDestination(for: UUID.self) { taskId in
            if let task = tasks.first(where: { $0.id == taskId }) {
                MaintenanceApprovalDetailView(task: task) {
                    Task { await loadAllTasks() }
                }
            }
        }
    }

    // MARK: - Task Row

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
        isLoading = true
        do {
            tasks = try await MaintenanceTaskService.fetchAllMaintenanceTasks()
        } catch {
            print("[MaintRequests] Error: \(error)")
        }
        isLoading = false
    }
}

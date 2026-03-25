import SwiftUI

// MARK: - RepairTaskListView

struct RepairTaskListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedFilter: MaintenanceTaskStatus? = nil

    private var currentUserId: UUID { AuthManager.shared.currentUser?.id ?? UUID() }

    private var tasks: [MaintenanceTask] {
        store.maintenanceTasks.filter { $0.assignedToId == currentUserId }
    }

    private var filteredTasks: [MaintenanceTask] {
        guard let f = selectedFilter else { return tasks }
        return tasks.filter { $0.status == f }
    }

    /// Count of tasks whose work order has parts ready or approved
    private var partsReadyCount: Int {
        tasks.filter { task in
            guard let wo = store.workOrder(forMaintenanceTask: task.id) else { return false }
            return wo.partsSubStatus == .ready || wo.partsSubStatus == .approved
        }.count
    }

    private var isFilterActive: Bool { selectedFilter != nil }

    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()
            VStack(spacing: 0) {
                // Filter row
                filterRow
                if filteredTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                countBadge
            }
            if partsReadyCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    notificationBell
                }
            }
        }
        .navigationDestination(for: MaintenanceTask.self) { task in
            MaintenanceTaskDetailView(task: task)
        }
    }

    // MARK: - Filter Row (standalone button on the right)

    private var filterRow: some View {
        HStack {
            Spacer()
            Menu {
                Button {
                    selectedFilter = nil
                } label: {
                    Label("All Tasks", systemImage: selectedFilter == nil ? "checkmark" : "")
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
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle\(isFilterActive ? ".fill" : "")")
                        .font(.system(size: 15))
                    Text(selectedFilter?.rawValue ?? "Filter")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(isFilterActive ? .white : Color.appOrange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isFilterActive ? Color.appOrange : Color.appOrange.opacity(0.1),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        isFilterActive ? Color.clear : Color.appOrange.opacity(0.3),
                        lineWidth: 0.8
                    )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Count Badge

    private var countBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "number").font(.caption2)
            Text("\(filteredTasks.count)").font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.appOrange)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.appOrange.opacity(0.1), in: Capsule())
    }

    // MARK: - Notification Bell

    private var notificationBell: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .foregroundStyle(Color.appOrange)
            Circle()
                .fill(Color.red)
                .frame(width: 14, height: 14)
                .overlay(
                    Text("\(partsReadyCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                )
                .offset(x: 6, y: -6)
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredTasks) { task in
                    NavigationLink(value: task) {
                        RepairTaskCard(task: task, store: store)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle" : "wrench.and.screwdriver")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text(isFilterActive ? "No Tasks Match Filter" : "No Repair Tasks")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text(isFilterActive
                 ? "Try clearing the filter to see all tasks."
                 : "You have no assigned repair tasks right now.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if isFilterActive {
                Button {
                    selectedFilter = nil
                } label: {
                    Text("Clear Filter")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appOrange)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.appOrange.opacity(0.1), in: Capsule())
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Repair Task Card (matches reference exactly)

struct RepairTaskCard: View {
    let task: MaintenanceTask
    let store: AppDataStore

    private var vehicle: Vehicle? { store.vehicle(for: task.vehicleId) }
    private var workOrder: WorkOrder? { store.workOrder(forMaintenanceTask: task.id) }

    var body: some View {
        HStack(spacing: 0) {
            // Priority accent bar
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                // Title row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                        if let v = vehicle {
                            HStack(spacing: 4) {
                                Text(v.model).font(.caption)
                                Text("•").font(.caption)
                                Text(v.licensePlate).font(.caption)
                            }
                            .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    Spacer()
                    priorityBadge
                }

                // Parts-ready banner
                if let wo = workOrder, wo.partsSubStatus == .ready || wo.partsSubStatus == .approved {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill").font(.caption2)
                        Text("Parts are ready — tap to start work")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.1, green: 0.7, blue: 0.4), in: RoundedRectangle(cornerRadius: 8))
                } else if let wo = workOrder, wo.partsSubStatus == .partiallyReady {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.and.arrow.backward").font(.caption2)
                        Text("Some parts ready — others on order")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 8))
                }

                // Status + date row
                HStack(spacing: 8) {
                    statusChip
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.caption2)
                        Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }

                // Under-maintenance countdown
                if task.status == .inProgress, let wo = workOrder, let eta = wo.estimatedCompletionAt {
                    let remaining = eta.timeIntervalSince(Date())
                    let isOverdue = remaining <= 0
                    HStack(spacing: 5) {
                        Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock.fill")
                            .font(.caption2)
                        Text(isOverdue ? "Overdue" : countdownText(remaining))
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(isOverdue ? .red : .purple)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((isOverdue ? Color.red : Color.purple).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Priority Badge

    private var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon).font(.system(size: 9))
            Text(task.priority.rawValue).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(priorityColor)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(priorityColor.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(priorityColor.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - Status Chip

    private var statusChip: some View {
        HStack(spacing: 5) {
            Image(systemName: statusIcon).font(.system(size: 9))
            Text(statusDisplayText).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(statusColor)
    }

    // MARK: - Helpers

    private var priorityColor: Color {
        switch task.priority {
        case .low:    return .green
        case .medium: return .blue
        case .high:   return .orange
        case .urgent: return .red
        }
    }

    private var priorityIcon: String {
        switch task.priority {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    /// Composite display status considering both task status and parts sub-status
    private var statusDisplayText: String {
        if task.status == .assigned, let wo = workOrder {
            switch wo.partsSubStatus {
            case .requested:      return "Parts Requested"
            case .partiallyReady: return "Parts Partially Ready"
            case .approved, .ready: return "Parts Ready"
            case .orderPlaced:    return "Parts On Order"
            default: break
            }
        }
        return task.status.rawValue
    }

    private var statusColor: Color {
        switch task.status {
        case .pending:    return .gray
        case .assigned:
            if let wo = workOrder {
                switch wo.partsSubStatus {
                case .requested:      return .orange
                case .partiallyReady: return .orange
                case .approved, .ready: return Color(red: 0.1, green: 0.7, blue: 0.4)
                case .orderPlaced:    return .orange
                default: break
                }
            }
            return .blue
        case .inProgress: return .purple
        case .completed:  return .green
        case .cancelled:  return .red
        }
    }

    private var statusIcon: String {
        switch task.status {
        case .pending:    return "clock"
        case .assigned:
            if let wo = workOrder, wo.partsSubStatus != .none {
                return wo.partsSubStatus.icon
            }
            return "person.badge.clock"
        case .inProgress: return "wrench.and.screwdriver"
        case .completed:  return "checkmark.seal.fill"
        case .cancelled:  return "xmark.circle"
        }
    }

    private func countdownText(_ remaining: TimeInterval) -> String {
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        return h > 0 ? "Due in \(h)h \(m)m" : "Due in \(m)m"
    }
}

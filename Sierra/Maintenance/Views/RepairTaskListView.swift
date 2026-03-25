import SwiftUI

// MARK: - RepairTaskListView

struct RepairTaskListView: View {

    @Environment(AppDataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedStatus: MaintenanceTaskStatus? = nil
    @State private var hasAppeared = false

    private var personnelId: UUID? { AuthManager.shared.currentUser?.id }

    private var myTasks: [MaintenanceTask] {
        guard let id = personnelId else { return [] }
        return store.maintenanceTasks
            .filter { $0.assignedToId == id }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var filtered: [MaintenanceTask] {
        myTasks.filter { task in
            if let s = selectedStatus, task.status != s { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return task.title.lowercased().contains(q)
                    || task.taskDescription.lowercased().contains(q)
                    || (store.vehicle(for: task.vehicleId)?.licensePlate.lowercased().contains(q) ?? false)
            }
            return true
        }
    }

    private var isFilterActive: Bool { selectedStatus != nil }

    // Notification count = tasks where parts are ready
    private var partsReadyCount: Int {
        myTasks.filter { task in
            guard let wo = store.workOrder(forMaintenanceTask: task.id) else { return false }
            return wo.partsSubStatus == .ready || wo.partsSubStatus == .approved
        }.count
    }

    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                if filtered.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks, vehicle…")
        .toolbar {
            // Count badge on the left
            ToolbarItem(placement: .topBarLeading) {
                countBadge
            }
            // Filter menu + optional notification bell on the right
            ToolbarItemGroup(placement: .topBarTrailing) {
                if partsReadyCount > 0 {
                    notificationBell
                }
                filterMenu
            }
        }
        .navigationDestination(for: MaintenanceTask.self) { task in
            MaintenanceTaskDetailView(task: task)
                .environment(store)
        }
        .task {
            if let id = personnelId, store.maintenanceTasks.isEmpty {
                await store.loadMaintenanceData(staffId: id)
            }
        }
        .refreshable {
            if let id = personnelId { await store.loadMaintenanceData(staffId: id) }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { hasAppeared = true }
            }
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if let status = selectedStatus {
                    filterBanner(status)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, task in
                    NavigationLink(value: task) {
                        RepairTaskCard(
                            task: task,
                            vehicle: store.vehicle(for: task.vehicleId),
                            workOrder: store.workOrder(forMaintenanceTask: task.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 30)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(Double(index) * 0.06 + 0.1),
                        value: hasAppeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
    }

    // MARK: - Count Badge

    private var countBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "number").font(.caption2)
            Text("\(filtered.count)").font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.appOrange)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.appOrange.opacity(0.1), in: Capsule())
    }

    // MARK: - Notification Bell (parts ready)

    private var notificationBell: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .font(.system(size: 17, weight: .semibold))
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

    // MARK: - Filter Menu (iOS-native)

    private var filterMenu: some View {
        Menu {
            Section("Filter by Status") {
                Button {
                    withAnimation(.spring(response: 0.4)) { selectedStatus = nil }
                } label: {
                    Label("All Tasks", systemImage: selectedStatus == nil ? "checkmark.circle.fill" : "square.grid.2x2")
                }
                ForEach([MaintenanceTaskStatus.assigned, .inProgress, .completed], id: \.self) { status in
                    Button {
                        withAnimation(.spring(response: 0.4)) { selectedStatus = status }
                    } label: {
                        Label(status.rawValue, systemImage: selectedStatus == status ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            if isFilterActive {
                Divider()
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.4)) { selectedStatus = nil }
                } label: {
                    Label("Clear Filter", systemImage: "xmark.circle")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isFilterActive ? Color.appOrange.opacity(0.12) : Color.clear)
                    .frame(width: 36, height: 36)
                Image(systemName: isFilterActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.appOrange)
            }
        }
    }

    // MARK: - Filter Banner

    private func filterBanner(_ status: MaintenanceTaskStatus) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text("Showing: \(status.rawValue)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                withAnimation(.spring(response: 0.4)) { selectedStatus = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
            }
        }
        .foregroundStyle(Color.appOrange)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle" : "wrench.and.screwdriver")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.4))
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
                    withAnimation(.spring(response: 0.4)) { selectedStatus = nil }
                } label: {
                    Text("Clear Filter")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.appOrange))
                }
            }
            Spacer()
        }
    }
}

// MARK: - RepairTaskCard

struct RepairTaskCard: View {

    let task: MaintenanceTask
    let vehicle: Vehicle?
    let workOrder: WorkOrder?

    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return Color(red: 0.85, green: 0.18, blue: 0.15)
        case .high:   return Color.appOrange
        case .medium: return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .low:    return Color.appTextSecondary
        }
    }

    private var priorityIcon: String {
        switch task.priority {
        case .urgent: return "flame.fill"
        case .high:   return "exclamationmark.triangle.fill"
        case .medium: return "arrow.right.circle.fill"
        case .low:    return "minus.circle.fill"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .pending:    return Color(red: 0.20, green: 0.50, blue: 0.90)
        case .assigned:   return Color.appOrange
        case .inProgress: return SierraTheme.Colors.alpineMint
        case .completed:  return Color.appTextSecondary
        case .cancelled:  return SierraTheme.Colors.danger
        }
    }

    private var statusIcon: String {
        switch task.status {
        case .pending:    return "clock"
        case .assigned:   return "person.fill.checkmark"
        case .inProgress: return "wrench.fill"
        case .completed:  return "checkmark.seal.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }

    private var partsSubStatus: PartsSubStatus {
        workOrder?.partsSubStatus ?? .none
    }

    private var showPartsReadyBanner: Bool {
        partsSubStatus == .ready || partsSubStatus == .approved
    }

    private var showPartsPartialBanner: Bool {
        partsSubStatus == .partiallyReady
    }

    private var showPartsRequestedBanner: Bool {
        partsSubStatus == .requested || partsSubStatus == .orderPlaced
    }

    // Countdown for in-progress tasks
    private var isOverdue: Bool {
        guard task.status == .inProgress,
              let eta = workOrder?.estimatedCompletionAt else { return false }
        return eta < Date()
    }

    private var remainingTime: TimeInterval? {
        guard task.status == .inProgress,
              let eta = workOrder?.estimatedCompletionAt else { return nil }
        return eta.timeIntervalSince(Date())
    }

    var body: some View {
        HStack(spacing: 0) {
            // Priority accent bar
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: SierraTheme.Radius.card,
                        bottomLeadingRadius: SierraTheme.Radius.card
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                // Top row: title + priority badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                        if let v = vehicle {
                            HStack(spacing: 4) {
                                Text(v.manufacturer).font(.caption)
                                Text("•").font(.caption)
                                Text(v.licensePlate).font(.caption)
                            }
                            .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    Spacer()
                    priorityBadge
                }

                // Parts ready banner (green)
                if showPartsReadyBanner {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill").font(.caption2)
                        Text("Parts are ready — tap to start work")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.1, green: 0.7, blue: 0.4), in: RoundedRectangle(cornerRadius: 8))
                }

                // Parts partially ready banner (orange)
                if showPartsPartialBanner {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.and.arrow.backward").font(.caption2)
                        Text("Parts partially available — some on order")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                // Status + due date row
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: statusIcon).font(.system(size: 9))
                        Text(task.status.rawValue).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(statusColor)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.caption2)
                        Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                    }
                    .foregroundStyle(
                        task.dueDate < Date() && task.status != .completed ? .red : Color.appTextSecondary
                    )
                }

                // In-progress countdown
                if task.status == .inProgress, let remaining = remainingTime {
                    HStack(spacing: 5) {
                        Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock.fill")
                            .font(.caption2)
                        Text(isOverdue ? "Overdue" : countdownText(abs(remaining)))
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
        .clipShape(RoundedRectangle(cornerRadius: SierraTheme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon).font(.system(size: 9))
            Text(task.priority.rawValue).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(priorityColor)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(priorityColor.opacity(0.1), in: Capsule())
        .overlay(Capsule().strokeBorder(priorityColor.opacity(0.25), lineWidth: 0.5))
    }

    private func countdownText(_ remaining: TimeInterval) -> String {
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        return h > 0 ? "Due in \(h)h \(m)m" : "Due in \(m)m"
    }
}

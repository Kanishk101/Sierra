import SwiftUI

struct RepairTaskListView: View {
    @State private var viewModel = RepairTaskViewModel()
    @State private var selectedStatus: RepairStatus? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    filterChips
                    if viewModel.filteredTasks.isEmpty {
                        emptyState
                    } else {
                        taskList
                    }
                }
            }
            .navigationTitle("Repair Tasks")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    countBadge
                }
                if viewModel.notificationCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        notificationBell
                    }
                }
            }
            .navigationDestination(for: RepairTask.self) { task in
                RepairTaskDetailView(task: task, onUpdate: { updated in
                    viewModel.updateTask(updated)
                })
            }
        }
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "All")
                ForEach(RepairStatus.allCases, id: \.self) { status in
                    filterChip(status, label: status.rawValue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(_ status: RepairStatus?, label: String) -> some View {
        let isSelected = viewModel.selectedFilter == status
        return Button {
            viewModel.selectedFilter = status
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color.appTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.appOrange : Color.appCardBg, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5))
        }
    }

    // MARK: - List
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredTasks) { task in
                    NavigationLink(value: task) {
                        RepairTaskCard(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
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
                    Text("\(viewModel.notificationCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                )
                .offset(x: 6, y: -6)
        }
    }

    private var countBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "number").font(.caption2)
            Text("\(viewModel.filteredTasks.count)").font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.appOrange)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.appOrange.opacity(0.1), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text("No repair tasks")
                .font(.subheadline).foregroundStyle(Color.appTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Repair Task Card

struct RepairTaskCard: View {
    let task: RepairTask

    var body: some View {
        let vehicle = RepairStaticData.vehicle(for: task.vehicleId)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(task.priority.color)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 10) {
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

                // Notification banner for parts ready
                if task.status == .partsReady {
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

                // Under maintenance countdown
                if task.status == .underMaintenance, let started = task.startedAt, let eta = task.estimatedMinutes {
                    let end = started.addingTimeInterval(Double(eta * 60))
                    let remaining = end.timeIntervalSince(Date())
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

    private var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: task.priority.icon).font(.system(size: 9))
            Text(task.priority.rawValue).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(task.priority.color)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(task.priority.bgColor)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(task.priority.borderColor, lineWidth: 0.5))
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            Image(systemName: task.status.icon).font(.system(size: 9))
            Text(task.status.rawValue).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(task.status.color)
    }

    private func countdownText(_ remaining: TimeInterval) -> String {
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        return h > 0 ? "Due in \(h)h \(m)m" : "Due in \(m)m"
    }
}

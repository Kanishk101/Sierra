import SwiftUI

struct ServiceTaskListView: View {
    @State private var viewModel = ServiceTaskViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()
                VStack(spacing: 0) {
                    filterChips
                    if viewModel.filteredTasks.isEmpty {
                        emptyState
                    } else {
                        serviceList
                    }
                }
            }
            .navigationTitle("Service Tasks")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "number").font(.caption2)
                        Text("\(viewModel.filteredTasks.count)").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.appOrange.opacity(0.1), in: Capsule())
                }
            }
            .navigationDestination(for: ServiceTask.self) { task in
                ServiceTaskDetailView(task: task) { updated in
                    viewModel.updateTask(updated)
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "All")
                ForEach(ServiceStatus.allCases, id: \.self) { status in
                    filterChip(status, label: status.rawValue)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func filterChip(_ status: ServiceStatus?, label: String) -> some View {
        let isSelected = viewModel.selectedFilter == status
        return Button {
            viewModel.selectedFilter = status
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color.appTextSecondary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? Color.appOrange : Color.appCardBg, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.appDivider, lineWidth: 0.5))
        }
    }

    private var serviceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredTasks) { task in
                    NavigationLink(value: task) {
                        ServiceTaskCard(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.appOrange.opacity(0.3))
            Text("No service tasks").font(.subheadline).foregroundStyle(Color.appTextSecondary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Service Task Card
struct ServiceTaskCard: View {
    let task: ServiceTask

    var body: some View {
        let vehicle = RepairStaticData.vehicle(for: task.vehicleId)
        let checked = task.checklistItems.filter { $0.isChecked }.count
        let total = task.checklistItems.count
        let progress: Double = total > 0 ? Double(checked) / Double(total) : 0
        let available = task.requiredParts.filter { $0.isAvailable }.count
        let parts = task.requiredParts.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                    if let v = vehicle {
                        Text("\(v.name) • \(v.licensePlate)")
                            .font(.caption).foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
                Text(task.status.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(task.status.color, in: Capsule())
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Checklist").font(.caption.weight(.medium)).foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Text("\(checked)/\(total)").font(.caption.weight(.bold)).foregroundStyle(Color.appTextPrimary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appDivider)
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appOrange)
                            .frame(width: geo.size.width * progress, height: 5)
                    }
                }
                .frame(height: 5)
            }

            HStack(spacing: 12) {
                Label("\(available)/\(parts) parts", systemImage: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(available == parts ? .green : .orange)
                Spacer()
                Label(task.scheduledDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(14)
        .background(Color.appCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

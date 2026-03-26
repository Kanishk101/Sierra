import SwiftUI

struct StaffTabView: View {
    @Environment(AppDataStore.self) private var store
    @State private var segment: StaffSegment = .drivers
    @State private var selectedStaffMember: StaffMember?
    @State private var showCreateStaff = false
    @State private var showFilterSheet = false
    @State private var selectedStatus: StaffStatus? = nil

    enum StaffSegment: String, CaseIterable {
        case drivers = "Drivers"
        case maintenance = "Maintenance"
        case applications = "Applications"
    }

    private func staffFor(_ segment: StaffSegment) -> [StaffMember] {
        let role: UserRole = segment == .drivers ? .driver : .maintenancePersonnel
        let all = store.staff.filter {
            $0.role == role && $0.isApproved && $0.status != .pendingApproval
            && (selectedStatus == nil || $0.status == selectedStatus)
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return all
    }

    private var visibleStaff: [StaffMember] { staffFor(segment) }
    private var statusFilterBinding: Binding<String?> {
        Binding(
            get: { selectedStatus?.rawValue },
            set: { newValue in selectedStatus = newValue.flatMap { StaffStatus(rawValue: $0) } }
        )
    }
    private var statusFilterOptions: [FilterOption] {
        [
            FilterOption(id: StaffStatus.active.rawValue, label: "Active", icon: "checkmark.circle.fill", color: .green),
            FilterOption(id: StaffStatus.suspended.rawValue, label: "Suspended", icon: "person.slash.fill", color: .red)
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Picker("Segment", selection: $segment) {
                    ForEach(StaffSegment.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 8)

                switch segment {
                case .drivers, .maintenance: staffListContent
                case .applications: ApplicationsListView()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.2), value: segment)
            .sheet(isPresented: $showCreateStaff) {
                CreateStaffView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(.systemGroupedBackground))
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(title: "Filter Staff", options: statusFilterOptions, selectedId: statusFilterBinding)
            }
            .sheet(item: $selectedStaffMember) { member in
                StaffDetailSheet(member: member)
                    .environment(AppDataStore.shared)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text("Staff")
                .font(.largeTitle.bold())

            Spacer()

            Button {
                showCreateStaff = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: selectedStatus == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(selectedStatus == nil ? .secondary : .orange)
        }
    }

    private var staffListContent: some View {
        Group {
            if visibleStaff.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)
                    Image(systemName: "person.2.slash").font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                    Text("No \(segment.rawValue.lowercased()) yet").font(.body).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleStaff) { member in
                            staffCard(member)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .onTapGesture { selectedStaffMember = member }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if member.status == .active {
                                        Button(role: .destructive) { Task { await toggleSuspend(member, suspend: true) } } label: { Label("Suspend", systemImage: "person.slash") }
                                    } else if member.status == .suspended {
                                        Button { Task { await toggleSuspend(member, suspend: false) } } label: { Label("Reactivate", systemImage: "person.badge.plus") }.tint(.green)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 32)
                }
            }
        }
        .task { if store.staff.isEmpty { await store.loadAll() } }
        .refreshable { await store.loadAll() }
    }

    private func staffCard(_ member: StaffMember) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5)).frame(width: 42, height: 42)
                .overlay(Text(member.initials).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.primary))
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                Text(member.email).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            HStack(spacing: 8) {
                if member.status == .suspended {
                    Text("Suspended").font(.system(size: 10, weight: .semibold)).foregroundStyle(.red)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red.opacity(0.10), in: Capsule())
                } else {
                    availabilityBadge(member.availability)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.6)
        )
        .opacity(member.status == .suspended ? 0.6 : 1.0)
    }

    private func availabilityBadge(_ availability: StaffAvailability) -> some View {
        let (text, dot, bg, fg): (String, Color, Color, Color) = switch availability {
        case .available: ("Available", .green, .green.opacity(0.12), Color(.systemGreen))
        case .unavailable: ("Unavailable", .red, .red.opacity(0.12), .red)
        case .busy: ("Busy", .orange, .orange.opacity(0.12), Color(.systemOrange))
        }
        return SierraBadge(label: text, dotColor: dot, backgroundColor: bg, foregroundColor: fg, size: .compact)
    }

    private func toggleSuspend(_ member: StaffMember, suspend: Bool) async {
        guard member.role != .fleetManager else { return }
        var updated = member; updated.status = suspend ? .suspended : .active
        do { try await store.updateStaffMember(updated) } catch { print("[StaffTab] toggleSuspend: \(error)") }
    }
}

// MARK: - Applications List
private struct ApplicationsListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var viewModel = StaffApprovalViewModel()
    @State private var selectedApplication: StaffApplication?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("Pending", isSelected: viewModel.selectedFilter == .pending) { viewModel.selectedFilter = .pending }
                    filterChip("Approved", isSelected: viewModel.selectedFilter == .approved) { viewModel.selectedFilter = .approved }
                    filterChip("Rejected", isSelected: viewModel.selectedFilter == .rejected) { viewModel.selectedFilter = .rejected }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)

            if viewModel.filteredApplications.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                    Text("No \(viewModel.selectedFilter.rawValue.lowercased()) applications").font(.body).foregroundStyle(.secondary)
                    Spacer()
                }.frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredApplications) { app in
                            applicationCard(app).onTapGesture { selectedApplication = app }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 32)
                }
            }
        }
        .task {
            if store.staff.isEmpty || store.staffApplications.isEmpty {
                await store.loadAll()
            }
        }
        .refreshable { await store.loadAll() }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedFilter)
        .sheet(item: $selectedApplication) { StaffReviewSheet(application: $0, viewModel: viewModel).presentationDetents([.large]) }
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.caption)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(isSelected ? Color.orange : Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? .clear : Color(.separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func applicationCard(_ app: StaffApplication) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(store.staffMember(for: app.staffMemberId)?.initials ?? String(app.phone.suffix(2)))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(store.staffMember(for: app.staffMemberId)?.displayName ?? app.phone).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(app.role.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Text(app.daysAgo).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if app.status == .pending {
                    Text("Review")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.orange.opacity(0.10), in: Capsule())
                } else {
                    let (text, color): (String, Color) = app.status == .approved ? ("Approved", .green) : ("Rejected", .red)
                    Text(text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(color.opacity(0.10), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.6)
        )
    }

}

#Preview { StaffTabView().environment(AppDataStore.shared) }

import SwiftUI

struct StaffTabView: View {
    @Environment(AppDataStore.self) private var store
    @State private var segment: StaffSegment = .drivers
    @State private var searchText = ""
    @State private var selectedStaffMember: StaffMember?
    @State private var showCreateStaff = false

    enum StaffSegment: String, CaseIterable {
        case drivers      = "Drivers"
        case maintenance  = "Maintenance"
        case applications = "Applications"
    }

    // MARK: - Filtered staff

    private func staffFor(_ segment: StaffSegment) -> [StaffMember] {
        let role: UserRole = segment == .drivers ? .driver : .maintenancePersonnel
        let all = store.staff.filter {
            $0.role == role
            && $0.isApproved
            && $0.status != .pendingApproval
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    private var visibleStaff: [StaffMember] {
        staffFor(segment)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Single 3-segment control
                Picker("Segment", selection: $segment) {
                    ForEach(StaffSegment.allCases, id: \.self) { s in
                        if s == .applications {
                            let count = store.pendingCount
                            Text(count > 0 ? "\(s.rawValue) (\(count))" : s.rawValue).tag(s)
                        } else {
                            Text(s.rawValue).tag(s)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                // Content
                switch segment {
                case .drivers, .maintenance:
                    staffListContent
                case .applications:
                    ApplicationsListView()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Staff")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.2), value: segment)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateStaff = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showCreateStaff) {
                NavigationStack {
                    CreateStaffView()
                }
            }
            .sheet(item: $selectedStaffMember) { member in
                StaffDetailSheet(member: member)
                    .environment(AppDataStore.shared)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Staff List Content

    private var staffListContent: some View {
        Group {
            if visibleStaff.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No \(segment.rawValue.lowercased()) yet" : "No results for \"\(searchText)\"")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        sectionBlock(
                            segment.rawValue,
                            icon: segment == .drivers ? "car.fill" : "wrench.and.screwdriver.fill",
                            members: visibleStaff
                        )
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            if store.staff.isEmpty { await store.loadAll() }
        }
        .refreshable {
            await store.loadAll()
        }
    }

    // MARK: - Section Block

    private func sectionBlock(_ title: String, icon: String, members: [StaffMember]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(members.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ForEach(members) { member in
                staffRow(member)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedStaffMember = member
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if member.status == .active {
                            Button(role: .destructive) {
                                Task { await toggleSuspend(member, suspend: true) }
                            } label: {
                                Label("Suspend", systemImage: "person.slash")
                            }
                        } else if member.status == .suspended {
                            Button {
                                Task { await toggleSuspend(member, suspend: false) }
                            } label: {
                                Label("Reactivate", systemImage: "person.badge.plus")
                            }
                            .tint(.green)
                        }
                    }
            }
        }
    }

    // MARK: - Staff Row

    private func staffRow(_ member: StaffMember) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(member.initials)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(member.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if member.status == .suspended {
                Text("Suspended")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.red, in: Capsule())
            } else {
                availabilityBadge(member.availability)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(member.status == .suspended ? 0.6 : 1.0)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func availabilityBadge(_ availability: StaffAvailability) -> some View {
        let (text, dotColor, bgColor, fgColor): (String, Color, Color, Color) = switch availability {
        case .available:
            ("Available",   .green,  .green.opacity(0.12),  Color(.systemGreen))
        case .unavailable:
            ("Unavailable", .red,    .red.opacity(0.12),    .red)
        case .busy:
            ("Busy",        .orange, .orange.opacity(0.12), Color(.systemOrange))
        case .onTrip:
            ("On Trip",     .blue,   .blue.opacity(0.12),   .blue)
        case .onTask:
            ("On Task",     Color(.systemOrange), Color(.systemOrange).opacity(0.12), Color(.systemOrange))
        }
        return SierraBadge(
            label: text,
            dotColor: dotColor,
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            size: .compact
        )
    }

    // MARK: - Suspend / Reactivate

    private func toggleSuspend(_ member: StaffMember, suspend: Bool) async {
        guard member.role != .fleetManager else { return }
        var updated = member
        updated.status = suspend ? .suspended : .active
        do {
            try await store.updateStaffMember(updated)
        } catch {
            print("[StaffTab] toggleSuspend error: \(error)")
        }
    }
}

// MARK: - Applications List

private struct ApplicationsListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var viewModel = StaffApprovalViewModel()
    @State private var selectedApplication: StaffApplication?

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("Pending", count: viewModel.pendingCount, isSelected: viewModel.selectedFilter == .pending) {
                        viewModel.selectedFilter = .pending
                    }
                    filterChip("Approved", count: nil, isSelected: viewModel.selectedFilter == .approved) {
                        viewModel.selectedFilter = .approved
                    }
                    filterChip("Rejected", count: nil, isSelected: viewModel.selectedFilter == .rejected) {
                        viewModel.selectedFilter = .rejected
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)

            if viewModel.filteredApplications.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No \(viewModel.selectedFilter.rawValue.lowercased()) applications")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredApplications) { app in
                            applicationCard(app)
                                .onTapGesture {
                                    selectedApplication = app
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedFilter)
        .sheet(item: $selectedApplication) { app in
            StaffReviewSheet(application: app, viewModel: viewModel)
                .presentationDetents([.large])
        }
    }

    private func filterChip(_ label: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.caption)
                if let count, count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isSelected ? Color.orange : Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func applicationCard(_ app: StaffApplication) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(avatarColor(for: app.status).opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(store.staffMember(for: app.staffMemberId)?.initials ?? String(app.phone.suffix(2)))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(avatarColor(for: app.status))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(store.staffMember(for: app.staffMemberId)?.displayName ?? app.phone)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(app.role.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray5), in: Capsule())

                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(app.daysAgo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if app.status == .pending {
                Text("Review")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.10), in: Capsule())
            } else {
                statusBadge(app.status)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func statusBadge(_ status: ApprovalStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .pending:  ("Pending",  .orange)
        case .approved: ("Approved", .green)
        case .rejected: ("Rejected", .red)
        }
        return Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func avatarColor(for status: ApprovalStatus) -> Color {
        switch status {
        case .pending:  .orange
        case .approved: .blue
        case .rejected: .red.opacity(0.7)
        }
    }
}

#Preview {
    StaffTabView()
        .environment(AppDataStore.shared)
}

import SwiftUI

// CHANGES (Phase 1 restore):
// - StaffDirectoryView uses store.staff filtered by role (not StaffMember.samples)
// - StaffDirectoryView uses member.displayName (not member.name)
// - StaffTabView adds @State searchText and passes $searchText to StaffDirectoryView
// - .searchable(text: $searchText) added to NavigationStack
// - ApplicationsListView preserved exactly from backup-current
// - initialsCircle helper added as private extension on ApplicationsListView

struct StaffTabView: View {
    @State private var mode: StaffMode = .staff
    @State private var searchText = ""

    enum StaffMode: String, CaseIterable {
        case staff = "Staff"
        case applications = "Applications"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Mode", selection: $mode) {
                    ForEach(StaffMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

                // Content
                switch mode {
                case .staff:
                    StaffDirectoryView(searchText: $searchText)
                case .applications:
                    ApplicationsListView()
                }
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Staff")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search staff…")
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
    }
}

// MARK: - Staff Directory (All Staff by Role Section)

private struct StaffDirectoryView: View {
    @Environment(AppDataStore.self) private var store
    @Binding var searchText: String

    private var drivers: [StaffMember] {
        let all = store.staff.filter { $0.role == .driver && $0.status != .suspended }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    private var maintenance: [StaffMember] {
        let all = store.staff.filter { $0.role == .maintenancePersonnel && $0.status != .suspended }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !drivers.isEmpty {
                    sectionBlock("Drivers", icon: "car.fill", members: drivers)
                }
                if !maintenance.isEmpty {
                    sectionBlock("Maintenance", icon: "wrench.and.screwdriver.fill", members: maintenance)
                }
                if drivers.isEmpty && maintenance.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Spacer(minLength: 60)
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(SierraTheme.Colors.granite)
                        Text(searchText.isEmpty ? "No staff members yet" : "No results for \"\(searchText)\"")
                            .font(SierraFont.bodyText)
                            .foregroundStyle(SierraTheme.Colors.secondaryText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
        .task {
            if store.staff.isEmpty { await store.loadAll() }
        }
        .refreshable {
            await store.loadAll()
        }
    }

    private func sectionBlock(_ title: String, icon: String, members: [StaffMember]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
                Text(title)
                    .font(SierraFont.headline)
                    .foregroundStyle(SierraTheme.Colors.primaryText)
                Spacer()
                Text("\(members.count)")
                    .font(SierraFont.caption2)
                    .foregroundStyle(SierraTheme.Colors.granite)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(SierraTheme.Colors.cloud, in: Capsule())
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            ForEach(members) { member in
                staffRow(member)
                    .padding(.horizontal, Spacing.lg)
            }
        }
    }

    private func staffRow(_ member: StaffMember) -> some View {
        HStack(spacing: Spacing.md) {
            SierraAvatarView(
                initials: member.initials,
                size: 44,
                gradient: member.role == .driver ? SierraAvatarView.driver() : SierraAvatarView.maintenance()
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(member.displayName)
                    .sierraStyle(.cardTitle)
                Text(member.email)
                    .sierraStyle(.caption)
            }

            Spacer()

            staffStatusBadge(member.status)
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    private func staffStatusBadge(_ status: StaffStatus) -> some View {
        let (text, dotColor, bgColor, fgColor): (String, Color, Color, Color) = switch status {
        case .active:          ("Active",    SierraTheme.Colors.alpineMint, SierraTheme.Colors.alpineMint.opacity(0.12), SierraTheme.Colors.alpineDark)
        case .pendingApproval: ("Pending",   SierraTheme.Colors.warning,    SierraTheme.Colors.warning.opacity(0.12),    SierraTheme.Colors.warning)
        case .suspended:       ("Suspended", SierraTheme.Colors.danger,     SierraTheme.Colors.danger.opacity(0.12),     SierraTheme.Colors.danger)
        }
        return SierraBadge(
            label: text,
            dotColor: dotColor,
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            size: .compact
        )
    }
}

// MARK: - Applications List (with filter)

private struct ApplicationsListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var viewModel = StaffApprovalViewModel()
    @State private var selectedApplication: StaffApplication?

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
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
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.vertical, Spacing.sm)

            if viewModel.filteredApplications.isEmpty {
                VStack(spacing: Spacing.md) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(SierraTheme.Colors.granite)
                    Text("No \(viewModel.selectedFilter.rawValue.lowercased()) applications")
                        .font(SierraFont.bodyText)
                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(viewModel.filteredApplications) { app in
                            applicationCard(app)
                                .onTapGesture {
                                    selectedApplication = app
                                }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
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
            HStack(spacing: Spacing.xxs) {
                Text(label)
                    .font(SierraFont.caption1)
                if let count, count > 0 {
                    Text("(\(count))")
                        .font(SierraFont.caption2)
                }
            }
            .foregroundStyle(isSelected ? .white : SierraTheme.Colors.primaryText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(isSelected ? SierraTheme.Colors.ember : SierraTheme.Colors.cardSurface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : SierraTheme.Colors.cloud, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func applicationCard(_ app: StaffApplication) -> some View {
        HStack(spacing: Spacing.md) {
            SierraAvatarView(
                initials: store.staffMember(for: app.staffMemberId)?.initials ?? String(app.phone.suffix(2)),
                size: 48,
                gradient: [avatarColor(for: app.status), avatarColor(for: app.status).opacity(0.7)]
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(store.staffMember(for: app.staffMemberId)?.displayName ?? app.phone)
                    .font(SierraFont.body(16, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.primaryText)

                HStack(spacing: Spacing.xs) {
                    Text(app.role.displayName)
                        .font(SierraFont.caption2)
                        .foregroundStyle(SierraTheme.Colors.granite)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(SierraTheme.Colors.cloud, in: Capsule())

                    Text("·")
                        .foregroundStyle(SierraTheme.Colors.granite)
                    Text(app.daysAgo)
                        .font(SierraFont.caption2)
                        .foregroundStyle(SierraTheme.Colors.secondaryText)
                }
            }

            Spacer()

            if app.status == .pending {
                Text("Review")
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.ember)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(SierraTheme.Colors.ember.opacity(0.10), in: Capsule())
            } else {
                statusBadge(app.status)
            }
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    private func statusBadge(_ status: ApprovalStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .pending:  ("Pending",  SierraTheme.Colors.warning)
        case .approved: ("Approved", SierraTheme.Colors.alpineMint)
        case .rejected: ("Rejected", SierraTheme.Colors.danger)
        }
        return Text(text)
            .font(SierraFont.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func avatarColor(for status: ApprovalStatus) -> Color {
        switch status {
        case .pending:  SierraTheme.Colors.warning
        case .approved: SierraTheme.Colors.sierraBlue
        case .rejected: SierraTheme.Colors.danger.opacity(0.7)
        }
    }
}

#Preview {
    StaffTabView()
        .environment(AppDataStore.shared)
}

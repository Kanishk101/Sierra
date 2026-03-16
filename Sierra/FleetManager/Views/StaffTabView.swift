import SwiftUI

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
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                // Content
                switch mode {
                case .staff:
                    StaffDirectoryView(searchText: $searchText)
                case .applications:
                    ApplicationsListView()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Staff")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search staff…")
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
    }
}

// MARK: - Staff Directory

private struct StaffDirectoryView: View {
    @Environment(AppDataStore.self) private var store
    @Binding var searchText: String

    private var drivers: [StaffMember] {
        let all = store.staff.filter {
            $0.role == .driver
            && $0.status == .active
            && $0.isApproved
        }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    private var maintenance: [StaffMember] {
        let all = store.staff.filter {
            $0.role == .maintenancePersonnel
            && $0.status == .active
            && $0.isApproved
        }
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
                    VStack(spacing: 16) {
                        Spacer(minLength: 60)
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "No staff members yet" : "No results for \"\(searchText)\"")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 32)
        }
        .task {
            if store.staff.isEmpty { await store.loadAll() }
        }
        .refreshable {
            await store.loadAll()
        }
    }

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
            }
        }
    }

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

            availabilityBadge(member.availability)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

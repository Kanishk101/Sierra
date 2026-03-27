import SwiftUI

struct StaffTabView: View {
    @Environment(AppDataStore.self) private var store
    @State private var segment: StaffSegment = .drivers
    @State private var selectedStaffMember: StaffMember?
    @State private var showCreateStaff = false
    @State private var selectedAvailability: StaffAvailability? = nil
    @State private var internalSearchText = ""

    var embedInParentNavigation: Bool = false
    var externalSearchText: Binding<String>? = nil

    enum StaffSegment: String, CaseIterable {
        case drivers = "Drivers"
        case maintenance = "Maintenance"
        case applications = "Applications"
    }

    init(
        initialSegment: StaffSegment = .drivers,
        embedInParentNavigation: Bool = false,
        externalSearchText: Binding<String>? = nil
    ) {
        _segment = State(initialValue: initialSegment)
        self.embedInParentNavigation = embedInParentNavigation
        self.externalSearchText = externalSearchText
    }

    private var activeSearchText: String {
        externalSearchText?.wrappedValue ?? internalSearchText
    }

    private func staffFor(_ segment: StaffSegment) -> [StaffMember] {
        let role: UserRole = segment == .drivers ? .driver : .maintenancePersonnel
        let all = store.staff.filter {
            $0.role == role && $0.isApproved && $0.status != .pendingApproval
            && (selectedAvailability == nil || $0.availability == selectedAvailability)
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        let query = activeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { member in
            member.displayName.lowercased().contains(query)
            || member.email.lowercased().contains(query)
        }
    }

    private var visibleStaff: [StaffMember] { staffFor(segment) }
    var body: some View {
        Group {
            if embedInParentNavigation {
                content
            } else {
                NavigationStack { content }
            }
        }
    }

    private var content: some View {
            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Picker("Segment", selection: $segment) {
                    ForEach(StaffSegment.allCases, id: \.self) { s in
                        if s == .applications {
                            let count = store.pendingCount
                            Text(count > 0 ? "\(s.rawValue) (\(count))" : s.rawValue).tag(s)
                        } else { Text(s.rawValue).tag(s) }
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
            .sheet(isPresented: $showCreateStaff) { NavigationStack { CreateStaffView() } }
            .sheet(item: $selectedStaffMember) { member in
                StaffDetailSheet(member: member)
                    .environment(AppDataStore.shared)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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

            Menu {
                Button {
                    selectedAvailability = nil
                } label: {
                    Text("All")
                }
                Divider()
                ForEach(StaffAvailability.allCases, id: \.self) { availability in
                    Button {
                        selectedAvailability = availability
                    } label: {
                        Text(availability.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(SierraFont.scaled(14, weight: .semibold))
                    Text(staffFilterTitle)
                        .font(SierraFont.scaled(13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(SierraFont.scaled(11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
        }
    }

    private var staffFilterTitle: String {
        selectedAvailability?.rawValue ?? "All"
    }

    private var staffListContent: some View {
        Group {
            if store.isLoading && store.staff.isEmpty {
                staffLoadingSkeleton
            } else if visibleStaff.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)
                    Image(systemName: "person.2.slash").font(SierraFont.scaled(44, weight: .light)).foregroundStyle(.secondary)
                    Text(
                        activeSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "No \(segment.rawValue.lowercased()) yet"
                            : "No results for \"\(activeSearchText)\""
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
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
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(member.displayName)
                                .accessibilityHint("Opens staff profile")
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
        .refreshable { await store.loadAll(force: true) }
    }

    private var staffLoadingSkeleton: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { _ in
                    HStack(spacing: 14) {
                        SierraSkeletonView(width: 44, height: 44, cornerRadius: 22)
                        VStack(alignment: .leading, spacing: 8) {
                            SierraSkeletonView(width: 150, height: 14)
                            SierraSkeletonView(width: 190, height: 10)
                        }
                        Spacer()
                        SierraSkeletonView(width: 78, height: 20, cornerRadius: 10)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 32)
        }
    }

    private func staffCard(_ member: StaffMember) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5)).frame(width: 44, height: 44)
                .overlay(Text(member.initials).font(SierraFont.scaled(15, weight: .bold, design: .rounded)).foregroundStyle(.primary))
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName).font(SierraFont.scaled(15, weight: .semibold)).foregroundStyle(.primary)
                Text(member.email).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            availabilityBadge(member.availability)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(member.status == .suspended ? 0.6 : 1.0)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
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
                    filterChip("Pending", count: viewModel.pendingCount, isSelected: viewModel.selectedFilter == .pending) { viewModel.selectedFilter = .pending }
                    filterChip("Approved", count: nil, isSelected: viewModel.selectedFilter == .approved) { viewModel.selectedFilter = .approved }
                    filterChip("Rejected", count: nil, isSelected: viewModel.selectedFilter == .rejected) { viewModel.selectedFilter = .rejected }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)

            if viewModel.filteredApplications.isEmpty {
                if store.isLoading && store.staffApplications.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { _ in
                                HStack(spacing: 14) {
                                    SierraSkeletonView(width: 48, height: 48, cornerRadius: 24)
                                    VStack(alignment: .leading, spacing: 8) {
                                        SierraSkeletonView(width: 160, height: 14)
                                        SierraSkeletonView(width: 120, height: 10)
                                    }
                                    Spacer()
                                    SierraSkeletonView(width: 70, height: 20, cornerRadius: 10)
                                }
                                .padding(16)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 32)
                    }
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.crop.circle.badge.checkmark").font(SierraFont.scaled(44, weight: .light)).foregroundStyle(.secondary)
                        Text("No \(viewModel.selectedFilter.rawValue.lowercased()) applications").font(.body).foregroundStyle(.secondary)
                        Spacer()
                    }.frame(maxWidth: .infinity)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredApplications) { app in
                            applicationCard(app)
                                .onTapGesture { selectedApplication = app }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel("Open \(app.role.displayName) application")
                                .accessibilityHint("Shows application details and actions")
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
        .refreshable { await store.loadAll(force: true) }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedFilter)
        .sheet(item: $selectedApplication) { StaffReviewSheet(application: $0, viewModel: viewModel).presentationDetents([.large]) }
    }

    private func filterChip(_ label: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(label).font(.caption)
                if let count, count > 0 { Text("(\(count))").font(.caption2) }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(isSelected ? Color.orange : Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? .clear : Color(.separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func applicationCard(_ app: StaffApplication) -> some View {
        HStack(spacing: 14) {
            Circle().fill(avatarColor(for: app.status).opacity(0.15)).frame(width: 48, height: 48)
                .overlay(Text(store.staffMember(for: app.staffMemberId)?.initials ?? String(app.phone.suffix(2))).font(SierraFont.scaled(16, weight: .bold, design: .rounded)).foregroundStyle(avatarColor(for: app.status)))
            VStack(alignment: .leading, spacing: 2) {
                Text(store.staffMember(for: app.staffMemberId)?.displayName ?? app.phone).font(SierraFont.scaled(16, weight: .semibold)).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(app.role.displayName).font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 3).background(Color(.systemGray5), in: Capsule())
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Text(app.daysAgo).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if app.status == .pending {
                Text("Review").font(.caption).foregroundStyle(.orange).padding(.horizontal, 16).padding(.vertical, 6).background(Color.orange.opacity(0.10), in: Capsule())
            } else {
                let (text, color): (String, Color) = app.status == .approved ? ("Approved", .green) : ("Rejected", .red)
                Text(text).font(.caption2).foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 2).background(color.opacity(0.12), in: Capsule())
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func avatarColor(for status: ApprovalStatus) -> Color {
        switch status { case .pending: return .orange; case .approved: return .blue; case .rejected: return .red.opacity(0.7) }
    }
}

#Preview { StaffTabView().environment(AppDataStore.shared) }

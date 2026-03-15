import SwiftUI

struct StaffListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedSegment: UserRole = .driver
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedMember: StaffMember?

    private var filteredStaff: [StaffMember] {
        // Only show staff who are fully active & approved.
        // Pending-approval and suspended members are handled
        // in PendingApprovalsView, not here.
        let byRole = store.staff.filter {
            $0.role != .fleetManager
            && $0.role == selectedSegment
            && $0.status == .active
            && $0.isApproved
        }
        guard !searchText.isEmpty else { return byRole }
        let q = searchText.lowercased()
        return byRole.filter {
            $0.displayName.lowercased().contains(q) || $0.email.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    Picker("Role", selection: $selectedSegment) {
                        Text("Drivers").tag(UserRole.driver)
                        Text("Maintenance").tag(UserRole.maintenancePersonnel)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)

                    if filteredStaff.isEmpty {
                        Spacer()
                        VStack(spacing: Spacing.md) {
                            Image(systemName: selectedSegment == .driver ? "person.fill" : "wrench.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(SierraTheme.Colors.granite)
                            Text(
                                searchText.isEmpty
                                    ? "No \(selectedSegment == .driver ? "drivers" : "maintenance staff") yet"
                                    : "No results for \"\(searchText)\""
                            )
                            .font(SierraFont.bodyText)
                            .foregroundStyle(SierraTheme.Colors.secondaryText)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredStaff) { member in
                                Button {
                                    selectedMember = member
                                } label: {
                                    staffRow(member)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: Spacing.md, bottom: 6, trailing: Spacing.md))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await store.loadAll() }
                    }
                }
                .background(SierraTheme.Colors.appBackground.ignoresSafeArea())

                SierraFAB { showAddSheet = true }
                    .padding(.trailing, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Staff")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name or email\u{2026}")
            .animation(.easeInOut(duration: 0.25), value: selectedSegment)
            .sheet(isPresented: $showAddSheet) {
                CreateStaffView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedMember) { member in
                StaffDetailSheet(member: member)
                    .environment(AppDataStore.shared)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                if store.staff.isEmpty { await store.loadAll() }
            }
        }
    }

    // MARK: - Staff Row

    private func staffRow(_ member: StaffMember) -> some View {
        HStack(spacing: Spacing.md) {
            SierraAvatarView(
                initials: member.initials,
                size: 44,
                gradient: avatarGradient(for: member)
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(member.displayName)
                    .sierraStyle(.cardTitle)
                Text(member.email)
                    .sierraStyle(.caption)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Availability is the primary status shown in the list
                availabilityBadge(member.availability)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.granite.opacity(0.4))
            }
        }
        .padding(Spacing.md)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    // MARK: - Availability Badge

    private func availabilityBadge(_ availability: StaffAvailability) -> some View {
        let (text, dot, bg, fg): (String, Color, Color, Color) = switch availability {
        case .available:
            ("Available",   SierraTheme.Colors.alpineMint,  SierraTheme.Colors.alpineMint.opacity(0.12),  SierraTheme.Colors.alpineDark)
        case .unavailable:
            ("Unavailable", SierraTheme.Colors.danger,      SierraTheme.Colors.danger.opacity(0.12),      SierraTheme.Colors.danger)
        case .busy:
            ("Busy",        SierraTheme.Colors.ember,       SierraTheme.Colors.ember.opacity(0.12),       SierraTheme.Colors.emberDark)
        case .onTrip:
            ("On Trip",     SierraTheme.Colors.sierraBlue,  SierraTheme.Colors.sierraBlue.opacity(0.12),  SierraTheme.Colors.sierraBlue)
        case .onTask:
            ("On Task",     SierraTheme.Colors.warning,     SierraTheme.Colors.warning.opacity(0.12),     SierraTheme.Colors.warning)
        }
        return SierraBadge(label: text, dotColor: dot, backgroundColor: bg, foregroundColor: fg, size: .compact)
    }

    private func avatarGradient(for member: StaffMember) -> [Color] {
        switch member.role {
        case .driver:               SierraAvatarView.driver()
        case .maintenancePersonnel: SierraAvatarView.maintenance()
        case .fleetManager:         SierraAvatarView.driver()
        }
    }
}

// MARK: - Staff Detail Sheet

struct StaffDetailSheet: View {
    let member: StaffMember
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var assignedVehicle: Vehicle? {
        store.vehicles.first { $0.assignedDriverId == member.id.uuidString }
    }

    private var activeTrip: Trip? {
        guard member.role == .driver else { return nil }
        return store.activeTrip(forDriverId: member.id)
    }

    private var tripCount: Int {
        store.trips(forDriver: member.id).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    heroSection

                    statusRow
                        .padding(.horizontal, Spacing.lg)

                    if let vehicle = assignedVehicle {
                        infoCard(title: "Assigned Vehicle", icon: "car.fill", color: SierraTheme.Colors.sierraBlue) {
                            labeledRow("Name", vehicle.name)
                            labeledRow("Plate", vehicle.licensePlate)
                            labeledRow("Model", vehicle.model)
                            labeledRow("Status", vehicle.status.rawValue)
                        }
                        .padding(.horizontal, Spacing.lg)
                    } else if member.role == .driver {
                        infoCard(title: "Assigned Vehicle", icon: "car.fill", color: SierraTheme.Colors.granite) {
                            Text("No vehicle assigned")
                                .font(SierraFont.bodyText)
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                        }
                        .padding(.horizontal, Spacing.lg)
                    }

                    if let trip = activeTrip {
                        infoCard(title: "Current Trip", icon: "arrow.triangle.swap", color: .green) {
                            labeledRow("Route", "\(trip.origin) \u{2192} \(trip.destination)")
                            labeledRow("Status", trip.status.rawValue)
                            labeledRow("Task ID", trip.taskId)
                        }
                        .padding(.horizontal, Spacing.lg)
                    }

                    infoCard(title: "Contact", icon: "person.crop.circle", color: SierraTheme.Colors.ember) {
                        labeledRow("Email", member.email)
                        if let phone = member.phone { labeledRow("Phone", phone) }
                        if let emergency = member.emergencyContactName {
                            labeledRow("Emergency Contact", emergency)
                        }
                        if let emergencyPhone = member.emergencyContactPhone {
                            labeledRow("Emergency Phone", emergencyPhone)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)

                    if member.isProfileComplete {
                        infoCard(title: "Profile", icon: "doc.text", color: SierraTheme.Colors.alpineMint) {
                            if let dob = member.dateOfBirth { labeledRow("Date of Birth", dob) }
                            if let gender = member.gender { labeledRow("Gender", gender) }
                            if let address = member.address { labeledRow("Address", address) }
                            if let aadhaar = member.aadhaarNumber { labeledRow("Aadhaar", aadhaar) }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }

                    infoCard(title: "Activity", icon: "chart.bar.fill", color: SierraTheme.Colors.warning) {
                        labeledRow("Total Trips", "\(tripCount)")
                        labeledRow("Profile", member.isProfileComplete ? "Complete" : "Incomplete")
                        if let joined = member.joinedDate {
                            labeledRow("Joined", joined.formatted(.dateTime.day().month(.abbreviated).year()))
                        }
                    }
                    .padding(.horizontal, Spacing.lg)

                    Spacer(minLength: 32)
                }
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle(member.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(SierraFont.body(17, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.ember)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            SierraAvatarView(
                initials: member.initials,
                size: 80,
                gradient: member.role == .driver ? SierraAvatarView.driver() : SierraAvatarView.maintenance()
            )
            Text(member.displayName)
                .font(SierraFont.title2)
                .foregroundStyle(SierraTheme.Colors.primaryText)
            Text(member.displayRole)
                .font(SierraFont.subheadline)
                .foregroundStyle(SierraTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Status Row
    // Shows availability as the primary status. Account-level status
    // (active/suspended) is not surfaced here since the list is already
    // filtered to active+approved staff only.

    private var statusRow: some View {
        HStack(spacing: 12) {
            miniStatusCard("Availability", member.availability.rawValue, availabilityColor(member.availability))
            miniStatusCard("Approved", member.isApproved ? "Yes" : "No",
                           member.isApproved ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.danger)
            miniStatusCard("Profile", member.isProfileComplete ? "Complete" : "Incomplete",
                           member.isProfileComplete ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.warning)
        }
    }

    private func miniStatusCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SierraFont.body(13, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(SierraFont.caption2)
                .foregroundStyle(SierraTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Info Card

    private func infoCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(SierraFont.caption1)
                    .foregroundStyle(color)
                Text(title)
                    .font(SierraFont.headline)
                    .foregroundStyle(SierraTheme.Colors.primaryText)
            }
            content()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .sierraShadow(SierraTheme.Shadow.card)
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(SierraFont.caption1)
                .foregroundStyle(SierraTheme.Colors.secondaryText)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(SierraFont.body(14, weight: .medium))
                .foregroundStyle(SierraTheme.Colors.primaryText)
            Spacer()
        }
    }

    // MARK: - Color helpers

    private func availabilityColor(_ a: StaffAvailability) -> Color {
        switch a {
        case .available:   return SierraTheme.Colors.alpineMint
        case .unavailable: return SierraTheme.Colors.danger
        case .busy:        return SierraTheme.Colors.ember
        case .onTrip:      return SierraTheme.Colors.sierraBlue
        case .onTask:      return SierraTheme.Colors.warning
        }
    }
}



#Preview {
    StaffListView()
        .environment(AppDataStore.shared)
}

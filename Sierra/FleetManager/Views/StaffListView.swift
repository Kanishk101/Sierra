import SwiftUI

struct StaffListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedSegment: UserRole = .driver
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedMember: StaffMember?

    private var filteredStaff: [StaffMember] {
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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                    if filteredStaff.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: selectedSegment == .driver ? "person.fill" : "wrench.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.secondary)
                            Text(
                                searchText.isEmpty
                                    ? "No \(selectedSegment == .driver ? "drivers" : "maintenance staff") yet"
                                    : "No results for \"\(searchText)\""
                            )
                            .font(.body)
                            .foregroundStyle(.secondary)
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
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await store.loadAll() }
                    }
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())

                SierraFAB { showAddSheet = true }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
            }
            .navigationTitle("Staff")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
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
        HStack(spacing: 14) {
            // Simple initials circle instead of SierraAvatarView
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

            VStack(alignment: .trailing, spacing: 4) {
                availabilityBadge(member.availability)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    // MARK: - Availability Badge

    private func availabilityBadge(_ availability: StaffAvailability) -> some View {
        let (text, dot, bg, fg): (String, Color, Color, Color) = switch availability {
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
                        .padding(.horizontal, 20)

                    if let vehicle = assignedVehicle {
                        infoCard(title: "Assigned Vehicle", icon: "car.fill", color: .blue) {
                            labeledRow("Name", vehicle.name)
                            labeledRow("Plate", vehicle.licensePlate)
                            labeledRow("Model", vehicle.model)
                            labeledRow("Status", vehicle.status.rawValue)
                        }
                        .padding(.horizontal, 20)
                    } else if member.role == .driver {
                        infoCard(title: "Assigned Vehicle", icon: "car.fill", color: .secondary) {
                            Text("No vehicle assigned")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }

                    if let trip = activeTrip {
                        infoCard(title: "Current Trip", icon: "arrow.triangle.swap", color: .green) {
                            labeledRow("Route", "\(trip.origin) \u{2192} \(trip.destination)")
                            labeledRow("Status", trip.status.rawValue)
                            labeledRow("Task ID", trip.taskId)
                        }
                        .padding(.horizontal, 20)
                    }

                    infoCard(title: "Contact", icon: "person.crop.circle", color: .orange) {
                        labeledRow("Email", member.email)
                        if let phone = member.phone { labeledRow("Phone", phone) }
                        if let emergency = member.emergencyContactName {
                            labeledRow("Emergency Contact", emergency)
                        }
                        if let emergencyPhone = member.emergencyContactPhone {
                            labeledRow("Emergency Phone", emergencyPhone)
                        }
                    }
                    .padding(.horizontal, 20)

                    if member.isProfileComplete {
                        infoCard(title: "Profile", icon: "doc.text", color: .green) {
                            if let dob = member.dateOfBirth { labeledRow("Date of Birth", dob) }
                            if let gender = member.gender { labeledRow("Gender", gender) }
                            if let address = member.address { labeledRow("Address", address) }
                            if let aadhaar = member.aadhaarNumber { labeledRow("Aadhaar", aadhaar) }
                        }
                        .padding(.horizontal, 20)
                    }

                    infoCard(title: "Activity", icon: "chart.bar.fill", color: Color(.systemOrange)) {
                        labeledRow("Total Trips", "\(tripCount)")
                        labeledRow("Profile", member.isProfileComplete ? "Complete" : "Incomplete")
                        if let joined = member.joinedDate {
                            labeledRow("Joined", joined.formatted(.dateTime.day().month(.abbreviated).year()))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(member.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(member.initials)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )
            Text(member.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(member.displayRole)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 12) {
            miniStatusCard("Availability", member.availability.rawValue, availabilityColor(member.availability))
            miniStatusCard("Approved", member.isApproved ? "Yes" : "No",
                           member.isApproved ? .green : .red)
            miniStatusCard("Profile", member.isProfileComplete ? "Complete" : "Incomplete",
                           member.isProfileComplete ? .green : .orange)
        }
    }

    private func miniStatusCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Color helpers

    private func availabilityColor(_ a: StaffAvailability) -> Color {
        switch a {
        case .available:   return .green
        case .unavailable: return .red
        case .busy:        return .orange
        case .onTrip:      return .blue
        case .onTask:      return Color(.systemOrange)
        }
    }
}



#Preview {
    StaffListView()
        .environment(AppDataStore.shared)
}

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
            && $0.status != .pendingApproval
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if member.role != .fleetManager {
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
                if member.status == .suspended {
                    Text("Suspended")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.red, in: Capsule())
                } else {
                    availabilityBadge(member.availability)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(member.status == .suspended ? 0.6 : 1.0)
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

    // MARK: - Suspend / Reactivate

    private func toggleSuspend(_ member: StaffMember, suspend: Bool) async {
        guard member.role != .fleetManager else { return }
        let newStatus: StaffStatus = suspend ? .suspended : .active
        do {
            try await store.setStaffStatus(staffId: member.id, status: newStatus)
        } catch {
            print("[StaffList] toggleSuspend error: \(error)")
        }
    }
}


#Preview {
    StaffListView()
        .environment(AppDataStore.shared)
}

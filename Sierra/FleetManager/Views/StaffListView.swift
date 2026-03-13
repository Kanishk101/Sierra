import SwiftUI

// CHANGES IN THIS FILE (Phase 5):
// - Replaced StaffRole (non-existent enum) with UserRole
// - Replaced StaffMember.samples with @Environment(AppDataStore.self) store.staff
// - Fixed member.name (now optional) to member.displayName
// - Role filter now uses .driver / .maintenancePersonnel
// - Added .task { await store.loadAll() } for data loading
// - Added .refreshable for pull-to-refresh

struct StaffListView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedSegment: UserRole = .driver
    @State private var showAddSheet = false

    private var filteredStaff: [StaffMember] {
        store.staff.filter { $0.role == selectedSegment }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Segmented picker
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
                            Text("No \(selectedSegment == .driver ? "drivers" : "maintenance staff") yet")
                                .font(SierraFont.bodyText)
                                .foregroundStyle(SierraTheme.Colors.secondaryText)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredStaff) { member in
                                staffRow(member)
                                    .listRowInsets(EdgeInsets(top: 6, leading: Spacing.md, bottom: 6, trailing: Spacing.md))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await store.loadAll()
                        }
                    }
                }
                .background(SierraTheme.Colors.appBackground.ignoresSafeArea())

                // FAB
                SierraFAB { showAddSheet = true }
                    .padding(.trailing, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Staff")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.25), value: selectedSegment)
            .sheet(isPresented: $showAddSheet) {
                CreateStaffView()
                    .presentationDetents([.medium, .large])
            }
            .task {
                if store.staff.isEmpty {
                    await store.loadAll()
                }
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

    private func avatarGradient(for member: StaffMember) -> [Color] {
        switch member.role {
        case .driver:               SierraAvatarView.driver()
        case .maintenancePersonnel: SierraAvatarView.maintenance()
        case .fleetManager:         SierraAvatarView.driver() // fallback
        }
    }
}

#Preview {
    StaffListView()
        .environment(AppDataStore.shared)
}

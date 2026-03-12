import SwiftUI

struct StaffListView: View {
    @State private var selectedSegment: StaffRole = .driver
    @State private var staffMembers = StaffMember.samples
    @State private var showAddSheet = false

    private var filteredStaff: [StaffMember] {
        staffMembers.filter { $0.role == selectedSegment }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Segmented picker
                    Picker("Role", selection: $selectedSegment) {
                        Text("Drivers").tag(StaffRole.driver)
                        Text("Maintenance").tag(StaffRole.maintenance)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)

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
                        try? await Task.sleep(for: .milliseconds(800))
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
                Text(member.name)
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
        case .active:          ("Active", SierraTheme.Colors.alpineMint, SierraTheme.Colors.alpineMint.opacity(0.12), SierraTheme.Colors.alpineDark)
        case .pendingApproval: ("Pending", SierraTheme.Colors.warning, SierraTheme.Colors.warning.opacity(0.12), SierraTheme.Colors.warning)
        case .suspended:       ("Suspended", SierraTheme.Colors.danger, SierraTheme.Colors.danger.opacity(0.12), SierraTheme.Colors.danger)
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
        case .driver:      SierraAvatarView.driver()
        case .maintenance: SierraAvatarView.maintenance()
        }
    }
}

#Preview {
    StaffListView()
}

import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    List {
                        ForEach(filteredStaff) { member in
                            staffRow(member)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        // Simulate pull-to-refresh
                        try? await Task.sleep(for: .milliseconds(800))
                    }
                }
                .background(Color(hex: "F2F3F7").ignoresSafeArea())

                // FAB
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(accentOrange, in: Circle())
                        .shadow(color: accentOrange.opacity(0.4), radius: 12, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
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
        HStack(spacing: 14) {
            // Avatar initials
            initialsCircle(member.initials, size: 44, bg: avatarColor(for: member.status))

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(navyDark)
                Text(member.email)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            staffStatusBadge(member.status)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    private func staffStatusBadge(_ status: StaffStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .active:          ("Active", .green)
        case .pendingApproval: ("Pending", .orange)
        case .suspended:       ("Suspended", .red)
        }
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func avatarColor(for status: StaffStatus) -> Color {
        switch status {
        case .active:          return Color(hex: "1B3A6B")
        case .pendingApproval: return .orange
        case .suspended:       return .red.opacity(0.7)
        }
    }

}

#Preview {
    StaffListView()
}

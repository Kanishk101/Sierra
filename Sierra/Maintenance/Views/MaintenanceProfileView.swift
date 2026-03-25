import SwiftUI

// MARK: - MaintenanceProfileView
/// Presented as a modal sheet from the profile avatar button in MaintenanceTabView.

struct MaintenanceProfileView: View {

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var staffer: StaffMember? {
        store.staff.first { $0.id == AuthManager.shared.currentUser?.id }
    }

    private var myTasks: [MaintenanceTask] {
        guard let id = AuthManager.shared.currentUser?.id else { return [] }
        return store.maintenanceTasks.filter { $0.assignedToId == id }
    }

    private var completedCount: Int { myTasks.filter { $0.status == .completed }.count }
    private var activeCount: Int    { myTasks.filter { $0.status == .inProgress }.count }
    private var assignedCount: Int  { myTasks.filter { $0.status == .assigned }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar hero
                        avatarSection

                        // Stats
                        statsGrid
                            .padding(.horizontal, 20)

                        // Sign out
                        signOutButton
                            .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.appOrange)
                }
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appOrange, Color.appDeepOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                    .shadow(color: Color.appOrange.opacity(0.35), radius: 10, x: 0, y: 4)
                Text(initials(for: staffer?.name ?? "MP"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(staffer?.name ?? "Maintenance Personnel")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Text("Maintenance Personnel")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appTextSecondary)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(value: assignedCount, label: "Assigned", color: Color.appOrange)
            statCard(value: activeCount,   label: "In Progress", color: SierraTheme.Colors.alpineMint)
            statCard(value: completedCount, label: "Completed", color: Color.appTextSecondary)
        }
    }

    private func statCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.appCardBg, in: RoundedRectangle(cornerRadius: SierraTheme.Radius.card))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            AuthManager.shared.signOut()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: SierraTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: SierraTheme.Radius.card)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        switch parts.count {
        case 0:  return "?"
        case 1:  return String(parts[0].prefix(2)).uppercased()
        default: return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
    }
}

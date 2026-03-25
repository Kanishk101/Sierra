import SwiftUI

struct MaintenanceTabView: View {

    @Environment(AppDataStore.self) private var store
    @State private var bannerCoordinator = BannerCoordinator()
    @State private var showProfile = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                // MARK: - Repair Tab
                Tab("Repair", systemImage: "wrench.and.screwdriver.fill") {
                    NavigationStack {
                        RepairTaskListView()
                            .navigationTitle("Repair")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    profileAvatarButton
                                }
                                ToolbarItem(placement: .topBarTrailing) {
                                    notificationBell
                                }
                            }
                    }
                }

                // MARK: - Alerts Tab
                Tab("Alerts", systemImage: "bell.fill") {
                    NavigationStack {
                        NotificationCentreView()
                            .navigationTitle("Alerts")
                            .navigationBarTitleDisplayMode(.large)
                    }
                }
                .badge(store.unreadNotificationCount > 0 ? store.unreadNotificationCount : 0)
            }
            .tint(Color.appOrange)

            // MARK: - Banner Overlay
            if let banner = bannerCoordinator.current {
                NotificationBannerView(
                    title: banner.title,
                    message: banner.body,
                    onTap: {
                        bannerCoordinator.dismiss()
                        banner.onTap()
                    },
                    onDismiss: { bannerCoordinator.dismiss() }
                )
            }
        }
        .onChange(of: store.notifications.count) { _, _ in
            if let latest = store.notifications.first, !latest.isRead {
                bannerCoordinator.show(.init(title: latest.title, body: latest.body))
            }
        }
        .sheet(isPresented: $showProfile) {
            MaintenanceProfileView()
                .environment(store)
        }
    }

    // MARK: - Profile Avatar Button

    private var profileAvatarButton: some View {
        Button { showProfile = true } label: {
            Group {
                if let staffer = store.staff.first(where: {
                    $0.id == AuthManager.shared.currentUser?.id
                }) {
                    let initials = initials(for: staffer.name ?? "MP")
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appOrange, Color.appDeepOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        Text(initials)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                } else {
                    Circle()
                        .fill(Color.appOrange.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appOrange)
                        }
                }
            }
        }
    }

    // MARK: - Notification Bell

    private var notificationBell: some View {
        Button { } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.appOrange)
                if store.unreadNotificationCount > 0 {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        switch parts.count {
        case 0:       return "?"
        case 1:       return String(parts[0].prefix(2)).uppercased()
        default:      return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
    }
}

#Preview {
    MaintenanceTabView()
        .environment(AppDataStore.shared)
}

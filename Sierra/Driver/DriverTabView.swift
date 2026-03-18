import SwiftUI
import UIKit

struct DriverTabView: View {

    @Environment(AppDataStore.self) private var store
    @State private var bannerCoordinator = BannerCoordinator()

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    DriverHomeView()
                        .navigationDestination(for: UUID.self) { id in
                            TripDetailDriverView(tripId: id)
                        }
                }
            }
            Tab("Trips", systemImage: "map.fill") {
                NavigationStack {
                    DriverTripsListView()
                }
            }
            Tab("Alerts", systemImage: "bell.fill") {
                NavigationStack {
                    NotificationCentreView()
                }
            }
            .badge(store.unreadNotificationCount)
            Tab("Profile", systemImage: "person.fill") {
                settingsTab()
            }
        }
        .tint(.orange)
        .overlay(alignment: .top) {
            if let banner = bannerCoordinator.current {
                NotificationBannerView(title: banner.title, message: banner.body) {
                    bannerCoordinator.dismiss()
                    banner.onTap()
                }
            }
        }
        .onChange(of: store.notifications.count) { _, _ in
            if let latest = store.notifications.first, !latest.isRead {
                bannerCoordinator.show(.init(title: latest.title, body: latest.body))
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground

        let selectedColor = UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]

        let normalColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func placeholderTab(title: String, icon: String, color: Color) -> some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(color)

                Text(title)
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Coming Soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingsTab() -> some View {
        ZStack {
            LinearGradient(
                colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "person.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))

                Text("Profile")
                    .font(.title2)
                    .foregroundStyle(.white)

                Button {
                    AuthManager.shared.signOut()
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}

#Preview {
    DriverTabView()
        .environment(AppDataStore.shared)
}

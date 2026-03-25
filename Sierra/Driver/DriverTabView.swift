import SwiftUI
import UIKit

enum DriverTab: Hashable {
    case home, trips, alerts
}

struct DriverTabView: View {

    @Environment(AppDataStore.self) private var store
    @State private var bannerCoordinator = BannerCoordinator()
    @State private var selectedTab: DriverTab = .home

    init() { configureTabBarAppearance() }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                NavigationStack {
                    DriverHomeView(tabSelection: $selectedTab)
                        .navigationDestination(for: UUID.self) { id in
                            TripDetailDriverView(tripId: id)
                        }
                }
            }

            Tab("Trips", systemImage: "map.fill", value: .trips) {
                NavigationStack {
                    DriverTripsListView()
                        .navigationDestination(for: UUID.self) { id in
                            TripDetailDriverView(tripId: id)
                        }
                }
            }

            Tab("Alerts", systemImage: "bell.fill", value: .alerts) {
                NavigationStack {
                    DriverAlertsView()
                }
            }
        }
        .tint(.orange)
        .overlay(alignment: .top) {
            if let banner = bannerCoordinator.current {
                NotificationBannerView(
                    title: banner.title,
                    message: banner.body,
                    onTap: {
                        bannerCoordinator.dismiss()
                        banner.onTap()
                    },
                    onDismiss: {
                        bannerCoordinator.dismiss()
                    }
                )
            }
        }
        .onChange(of: store.notifications.count) { _, _ in
            if let latest = store.notifications.first, !latest.isRead {
                // Driver acceptance already shows an in-flow centered success overlay.
                // Suppress duplicate top banners for that same event.
                if latest.type == .tripAccepted { return }
                bannerCoordinator.show(.init(title: latest.title, body: latest.body))
            }
        }
        .task {
            guard let driverId = AuthManager.shared.currentUser?.id else { return }
            await store.refreshDriverData(driverId: driverId)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(store.driverRefreshInterval * 1_000_000_000))
                guard let currentDriverId = AuthManager.shared.currentUser?.id else { continue }
                await store.refreshDriverData(driverId: currentDriverId)
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
}

#Preview {
    DriverTabView()
        .environment(AppDataStore.shared)
}

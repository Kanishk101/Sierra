import SwiftUI
import UIKit

enum DriverTab: Hashable {
    case home, trips, history
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

            Tab("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", value: .history) {
                NavigationStack {
                    DriverTripHistoryView()
                        .navigationDestination(for: UUID.self) { id in
                            TripDetailDriverView(tripId: id)
                        }
                }
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
}

#Preview {
    DriverTabView()
        .environment(AppDataStore.shared)
}

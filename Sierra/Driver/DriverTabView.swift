import SwiftUI
import UIKit

enum DriverTab: Hashable {
    case home, trips, alerts
}

struct DriverTabView: View {

    @Environment(AppDataStore.self) private var store
    @State private var bannerCoordinator = BannerCoordinator()
    @State private var selectedTab: DriverTab = .home
    @State private var homeResetToken = UUID()
    @State private var tripsResetToken = UUID()
    @State private var alertsResetToken = UUID()
    @State private var handledBannerNotificationIds: Set<UUID> = []
    @State private var didPrimeBannerFeed = false

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
                .id(homeResetToken)
            }

            Tab("Trips", systemImage: "map.fill", value: .trips) {
                NavigationStack {
                    DriverTripsListView()
                        .navigationDestination(for: UUID.self) { id in
                            TripDetailDriverView(tripId: id)
                        }
                }
                .id(tripsResetToken)
            }

            Tab("Alerts", systemImage: "bell.fill", value: .alerts) {
                NavigationStack {
                    DriverAlertsView()
                }
                .id(alertsResetToken)
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
        .onAppear {
            if !didPrimeBannerFeed, !store.notifications.isEmpty {
                handledBannerNotificationIds.formUnion(store.notifications.map(\.id))
                didPrimeBannerFeed = true
            }
        }
        .onChange(of: store.notifications) { oldValue, newValue in
            // First hydration pass should not replay historic unread notifications.
            if !didPrimeBannerFeed {
                handledBannerNotificationIds.formUnion(newValue.map(\.id))
                didPrimeBannerFeed = true
                return
            }

            let oldIds = Set(oldValue.map(\.id))
            let incoming = newValue
                .filter { !oldIds.contains($0.id) }
                .sorted { $0.sentAt < $1.sentAt }

            for notification in incoming {
                guard notification.isVisible, !notification.isRead else { continue }
                // Driver acceptance already shows an in-flow centered success overlay.
                if notification.type == .tripAccepted { continue }
                guard handledBannerNotificationIds.insert(notification.id).inserted else { continue }
                bannerCoordinator.show(.init(title: notification.title, body: notification.body))
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            guard oldTab != newTab else { return }
            switch oldTab {
            case .home:
                homeResetToken = UUID()
            case .trips:
                tripsResetToken = UUID()
            case .alerts:
                alertsResetToken = UUID()
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

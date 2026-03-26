import SwiftUI
import UIKit

struct MaintenanceTabView: View {

    @Environment(AppDataStore.self) private var store
    @State private var bannerCoordinator = BannerCoordinator()

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    MaintenanceHomeView()
                }
            }

            Tab("Service", systemImage: "gearshape.2.fill") {
                NavigationStack {
                    ServiceTaskListView()
                }
            }

            Tab("Repair", systemImage: "wrench.and.screwdriver.fill") {
                NavigationStack {
                    RepairTaskListView()
                }
            }

            Tab("Inventory", systemImage: "shippingbox.fill") {
                NavigationStack {
                    InventoryView()
                }
            }

            Tab("Alerts", systemImage: "bell.fill") {
                NavigationStack {
                    DriverAlertsView()
                }
            }
            .badge(store.unreadNotificationCount > 0 ? store.unreadNotificationCount : 0)
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
                    onDismiss: { bannerCoordinator.dismiss() }
                )
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
    MaintenanceTabView()
        .environment(AppDataStore.shared)
}

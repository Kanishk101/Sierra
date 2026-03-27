import SwiftUI
import UIKit

enum MaintenanceTab: Hashable {
    case home, service, repair, inventory, notifications
}

struct MaintenanceTabView: View {

    @Environment(AppDataStore.self) private var store
    @State private var bannerCoordinator = BannerCoordinator()
    @State private var selectedTab: MaintenanceTab = .home
    @State private var homeResetToken = UUID()
    @State private var serviceResetToken = UUID()
    @State private var repairResetToken = UUID()
    @State private var inventoryResetToken = UUID()
    @State private var alertsResetToken = UUID()
    @State private var handledBannerNotificationIds: Set<UUID> = []
    @State private var didPrimeBannerFeed = false

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                NavigationStack {
                    MaintenanceHomeView()
                }
                .id(homeResetToken)
            }

            Tab("Service", systemImage: "gearshape.2.fill", value: .service) {
                NavigationStack {
                    ServiceTaskListView()
                }
                .id(serviceResetToken)
            }

            Tab("Repair", systemImage: "wrench.and.screwdriver.fill", value: .repair) {
                NavigationStack {
                    RepairTaskListView()
                }
                .id(repairResetToken)
            }

            Tab("Inventory", systemImage: "shippingbox.fill", value: .inventory) {
                NavigationStack {
                    InventoryView()
                }
                .id(inventoryResetToken)
            }

            Tab("Notifications", systemImage: "bell.fill", value: .notifications) {
                NavigationStack {
                    DriverAlertsView()
                }
                .id(alertsResetToken)
            }
            .badge(store.unreadNotificationCount > 0 ? store.unreadNotificationCount : 0)
        }
        .tint(SierraTheme.Colors.ember)
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
        .onAppear {
            if !didPrimeBannerFeed, !store.notifications.isEmpty {
                handledBannerNotificationIds.formUnion(store.notifications.map(\.id))
                didPrimeBannerFeed = true
            }
        }
        .onChange(of: store.notifications) { oldValue, newValue in
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
                guard handledBannerNotificationIds.insert(notification.id).inserted else { continue }
                bannerCoordinator.show(.init(title: notification.title, body: notification.body))
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            guard oldTab != newTab else { return }
            switch oldTab {
            case .home:
                homeResetToken = UUID()
            case .service:
                serviceResetToken = UUID()
            case .repair:
                repairResetToken = UUID()
            case .inventory:
                inventoryResetToken = UUID()
            case .notifications:
                alertsResetToken = UUID()
            }
        }
        .task {
            guard let staffId = AuthManager.shared.currentUser?.id else { return }
            await store.loadMaintenanceData(staffId: staffId)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(store.driverRefreshInterval * 1_000_000_000))
                guard let currentStaffId = AuthManager.shared.currentUser?.id else { continue }
                await store.loadMaintenanceData(staffId: currentStaffId)
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground

        let selectedColor = SierraAccessibilityPalette.accentUIColor
        let selectedFont = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: UIFont.systemFont(ofSize: 11, weight: .bold))
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: selectedFont
        ]

        let normalColor = UIColor.secondaryLabel
        let normalFont = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: UIFont.systemFont(ofSize: 11, weight: .medium))
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: normalFont
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    MaintenanceTabView()
        .environment(AppDataStore.shared)
}

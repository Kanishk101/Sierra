import SwiftUI

// MARK: - Main Tab Bar (Native iOS TabView)
struct MainTabBar: View {
    @State private var selectedTab: Tab = .home

    enum Tab: Int, CaseIterable {
        case home, trips, alerts, profile

        var title: String {
            switch self {
            case .home:    return "Home"
            case .trips:   return "Trips"
            case .alerts:  return "Alerts"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .home:    return "house.fill"
            case .trips:   return "map.fill"
            case .alerts:  return "bell.fill"
            case .profile: return "person.fill"
            }
        }
    }

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(onOpenTrips: {
                selectedTab = .trips
            })
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            TripsView()
                .tabItem {
                    Label(Tab.trips.title, systemImage: Tab.trips.icon)
                }
                .tag(Tab.trips)

            AlertsView()
                .tabItem {
                    Label(Tab.alerts.title, systemImage: Tab.alerts.icon)
                }
                .tag(Tab.alerts)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.title, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(.appOrange)
    }

    // MARK: - Native Tab Bar Appearance
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground

        // Selected — orange
        let selectedColor = UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]

        // Normal — gray
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

// MARK: - Placeholder Views (Replace with real screens)
struct AlertsView: View {
    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.appOrange.opacity(0.3))
                Text("Alerts")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }
}

struct ProfileView: View {
    var body: some View {
        ZStack {
            Color.appSurface.ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.appOrange.opacity(0.3))
                Text("Profile")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MainTabBar()
}

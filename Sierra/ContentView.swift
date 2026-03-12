import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = OnboardingService.hasCompletedOnboarding
    private var authManager = AuthManager.shared

    var body: some View {
        let _ = print("🚀 ContentView.body evaluated — isAuthenticated=\(authManager.isAuthenticated)")
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if authManager.isAuthenticated, !authManager.needsReauth {
                #if DEBUG
                let _ = print("🏠 [ContentView] isAuthenticated=true → showing DASHBOARD")
                let _ = print("🏠 [ContentView] This fires BEFORE 2FA if AuthManager sets isAuthenticated early")
                #endif
                // Active session — show destination
                if let user = authManager.currentUser {
                    destinationView(for: authManager.destination(for: user))
                }
            } else {
                #if DEBUG
                let _ = print("🏠 [ContentView] isAuthenticated=false → showing LOGIN")
                #endif
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: authManager.needsReauth)
        .onReceive(
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
        ) { _ in
            hasCompletedOnboarding = OnboardingService.hasCompletedOnboarding
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AuthDestination) -> some View {
        switch destination {
        case .fleetManagerDashboard:  AdminDashboardView()
        case .changePassword:        ForcePasswordChangeView()
        case .driverOnboarding:      DriverProfileSetupView()
        case .maintenanceOnboarding: MaintenanceProfileSetupView()
        case .pendingApproval:       PendingApprovalView()
        case .driverDashboard:       DriverTabView()
        case .maintenanceDashboard:  MaintenanceDashboardView()
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = OnboardingService.hasCompletedOnboarding
    @State private var showBiometricEnrollment = false
    private var authManager = AuthManager.shared

    // Dashboard destinations that should trigger the Face ID enrollment prompt
    private func isDashboard(_ destination: AuthDestination) -> Bool {
        switch destination {
        case .driverDashboard, .maintenanceDashboard, .fleetManagerDashboard: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if authManager.isAuthenticated, !authManager.needsReauth {
                if let user = authManager.currentUser {
                    destinationView(for: authManager.destination(for: user))
                        .sheet(isPresented: $showBiometricEnrollment) {
                            BiometricEnrollmentSheet()
                                .presentationDetents([.medium])
                        }
                }
            } else {
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
        // Trigger enrollment only once per login session, after landing on a real dashboard.
        // Uses onChange so it doesn't re-fire when the sheet itself dismisses.
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth,
               let user = authManager.currentUser,
               isDashboard(authManager.destination(for: user)),
               BiometricEnrollmentSheet.shouldPrompt() {
                // Short delay so the dashboard renders visibly first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showBiometricEnrollment = true
                }
            } else if !isAuth {
                // Reset flag when logged out so it's ready for next login
                showBiometricEnrollment = false
            }
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

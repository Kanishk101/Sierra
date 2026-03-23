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
            } else if authManager.isAuthenticated {
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
        .onReceive(
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
        ) { _ in
            hasCompletedOnboarding = OnboardingService.hasCompletedOnboarding
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth,
               let user = authManager.currentUser,
               isDashboard(authManager.destination(for: user)),
               BiometricEnrollmentSheet.shouldPrompt() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showBiometricEnrollment = true
                }
            } else if !isAuth {
                showBiometricEnrollment = false
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AuthDestination) -> some View {
        switch destination {
        case .fleetManagerDashboard:  AdminDashboardView()
        case .changePassword:         ForcePasswordChangeView()
        case .driverOnboarding:       DriverProfileSetupView()
        case .maintenanceOnboarding:  MaintenanceProfileSetupView()
        case .pendingApproval:        PendingApprovalView()
        case .rejected:               RejectedView()
        case .driverDashboard:        DriverTabView()
        case .maintenanceDashboard:   MaintenanceDashboardView()
        }
    }
}

#Preview {
    ContentView()
}

import Foundation
import SwiftUI

/// Monitors app lifecycle and triggers biometric re-authentication when the app
/// returns from background after the inactivity threshold (60 seconds).
@MainActor @Observable
final class AppLifecycleMonitor {

    static let shared = AppLifecycleMonitor()

    var showBiometricLock: Bool = false

    /// Seconds before requiring biometric on resume.
    private let lockThresholdSeconds: TimeInterval = 60
    private var backgroundedAt: Date?

    private init() {}

    // MARK: - Scene Phase

    func handleScenePhaseChange(to phase: ScenePhase, hasSession: Bool) {
        guard hasSession else { return }

        switch phase {
        case .background:
            backgroundedAt = Date()

        case .active:
            guard AuthManager.shared.isAuthenticated else {
                backgroundedAt = nil
                return
            }
            guard BiometricPreference.isEnabled, BiometricManager.shared.canUseBiometrics() else {
                backgroundedAt = nil
                showBiometricLock = false
                return
            }
            if let bg = backgroundedAt,
               Date().timeIntervalSince(bg) > lockThresholdSeconds {
                showBiometricLock = true
            }
            backgroundedAt = nil

        default:
            break
        }
    }

    // MARK: - Legacy API (backward compat)

    func didEnterBackground() {
        backgroundedAt = Date()
    }

    func didBecomeActive() {
        guard AuthManager.shared.isAuthenticated else { return }
        guard BiometricPreference.isEnabled, BiometricManager.shared.canUseBiometrics() else {
            backgroundedAt = nil
            showBiometricLock = false
            return
        }
        if let bg = backgroundedAt,
           Date().timeIntervalSince(bg) > lockThresholdSeconds {
            showBiometricLock = true
        }
        backgroundedAt = nil
    }

    // MARK: - Actions

    func biometricUnlocked() {
        showBiometricLock = false
        // Also clear needsReauth so ContentView doesn't fall back to LoginView.
        // Both AppLifecycleMonitor (60s threshold) and AuthManager (300s threshold)
        // set their respective flags on foreground. Unlocking the overlay must
        // resolve both, otherwise ContentView's guard (isAuthenticated &&
        // !needsReauth) fails and the user is forced to authenticate a second time.
        AuthManager.shared.reauthCompleted()
    }

    func passwordFallbackUsed() {
        showBiometricLock = false
        // signOut() already sets needsReauth = false and isAuthenticated = false,
        // so ContentView will route to LoginView cleanly.
    }
}

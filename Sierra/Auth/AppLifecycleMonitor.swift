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

    /// Unified handler for scene phase changes.
    func handleScenePhaseChange(to phase: ScenePhase, hasSession: Bool) {
        guard hasSession else { return }

        switch phase {
        case .background:
            backgroundedAt = Date()

        case .active:
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
        if let bg = backgroundedAt,
           Date().timeIntervalSince(bg) > lockThresholdSeconds {
            showBiometricLock = true
        }
        backgroundedAt = nil
    }

    // MARK: - Actions

    func biometricUnlocked() {
        showBiometricLock = false
    }

    func passwordFallbackUsed() {
        showBiometricLock = false
    }
}

import Foundation
import SwiftUI

/// Monitors app lifecycle and triggers biometric re-authentication when the app
/// returns from background after the inactivity threshold (60 seconds).
@Observable
final class AppLifecycleMonitor {

    static let shared = AppLifecycleMonitor()

    var showBiometricLock: Bool = false

    /// Seconds before requiring biometric on resume.
    private let lockThresholdSeconds: TimeInterval = 60
    private var backgroundedAt: Date?

    private init() {}

    // MARK: - Scene Phase Handlers

    func didEnterBackground() {
        backgroundedAt = Date()
    }

    func didBecomeActive() {
        guard AuthManager.shared.isAuthenticated else { return }

        if let bg = backgroundedAt {
            let elapsed = Date().timeIntervalSince(bg)
            if elapsed > lockThresholdSeconds {
                showBiometricLock = true
            }
        }
        backgroundedAt = nil
    }

    func biometricUnlocked() {
        showBiometricLock = false
    }

    func passwordFallbackUsed() {
        showBiometricLock = false
    }
}

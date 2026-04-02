import Foundation
import SwiftUI

/// Monitors app lifecycle and triggers biometric re-authentication when the app
/// returns from background after the inactivity threshold.
@MainActor @Observable
final class AppLifecycleMonitor {

    static let shared = AppLifecycleMonitor()

    var showBiometricLock: Bool = false

    /// Seconds before requiring biometric on resume.
    /// Keep this aligned with AuthManager's auto-lock window to avoid
    /// aggressive prompts for short app switches/screen sleeps.
    private let lockThresholdSeconds: TimeInterval = 300
    private var backgroundedAt: Date?
    private var suppressUntil: Date = .distantPast

    private init() {}

    // MARK: - Scene Phase

    func handleScenePhaseChange(to phase: ScenePhase, hasSession: Bool) {
        guard hasSession else { return }

        switch phase {
        case .background:
            backgroundedAt = Date()
            // Persist latest Supabase session for reliable biometric restore.
            Task { await SupabaseManager.persistCurrentSessionSnapshot() }

        case .active:
            guard AuthManager.shared.isAuthenticated else {
                backgroundedAt = nil
                return
            }
            guard Date() >= suppressUntil else {
                backgroundedAt = nil
                return
            }
            guard !showBiometricLock else { return }
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

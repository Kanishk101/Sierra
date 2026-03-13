//
//  SierraApp.swift
//  Sierra
//
//  Created by kan on 09/03/26.
//

import SwiftUI

@main
struct SierraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private var lifecycle = AppLifecycleMonitor.shared

    init() {
        // Keychain persists across app reinstalls on iOS.
        // On first launch after a fresh install, clear stale Keychain data
        // so Face ID / session tokens from a previous install don't carry over.
        let hasLaunchedKey = "sierra.hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            // Clear all stale Keychain entries
            KeychainService.delete(key: "com.fleetOS.sessionToken")
            KeychainService.delete(key: "com.fleetOS.currentUser")
            KeychainService.delete(key: "com.fleetOS.hashedCredential")
            KeychainService.delete(key: "com.fleetOS.biometricEnabled")
            KeychainService.delete(key: "com.fleetOS.hasPromptedBiometric")
            SecureSessionStore.shared.clearAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
            ContentView()
                .applySierraTheme()

                // Biometric lock overlay — covers all roles
                if lifecycle.showBiometricLock {
                    BiometricLockView()
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .environment(AppDataStore.shared)
            .environment(AuthManager.shared)
            .animation(.easeInOut(duration: 0.25), value: lifecycle.showBiometricLock)
        }
        .onChange(of: scenePhase) { _, newPhase in
            lifecycle.handleScenePhaseChange(
                to: newPhase,
                hasSession: AuthManager.shared.currentUser != nil
            )
            // Also update AuthManager auto-lock timestamps
            switch newPhase {
            case .background:
                AuthManager.shared.appDidEnterBackground()
            case .active:
                AuthManager.shared.appWillEnterForeground()
            default:
                break
            }
        }
    }
}

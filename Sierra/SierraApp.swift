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

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                // Biometric lock overlay — covers all roles
                if lifecycle.showBiometricLock {
                    BiometricLockView()
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .environment(AppDataStore.shared)
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

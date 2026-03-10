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
            .animation(.easeInOut(duration: 0.25), value: lifecycle.showBiometricLock)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lifecycle.didEnterBackground()
                AuthManager.shared.appDidEnterBackground()
            case .active:
                lifecycle.didBecomeActive()
                AuthManager.shared.appWillEnterForeground()
            default:
                break
            }
        }
    }
}

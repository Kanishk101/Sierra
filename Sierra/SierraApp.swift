//
//  SierraApp.swift
//  Sierra
//
//  Created by kan on 09/03/26.
//

import SwiftUI
import UserNotifications

// MARK: - AppDelegate (APNs)
/// Handles APNs device token registration.
/// The token is sent to Supabase `push_tokens` so `send-push-notification`
/// edge function can deliver alerts when the app is backgrounded.

final class SierraAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request push notification permission on first launch.
        // Permission prompt appears after the user logs in (via ContentView),
        // but we register the delegate path here so token delivery works.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Persist locally so we can unregister on sign-out
        UserDefaults.standard.set(token, forKey: "sierra.devicePushToken")
        Task { await PushTokenService.registerToken(token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Non-fatal: in-app notifications still work. APNs fails in Simulator.
        print("[APNs] Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - SierraApp

@main
struct SierraApp: App {
    @UIApplicationDelegateAdaptor(SierraAppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase
    private var lifecycle = AppLifecycleMonitor.shared

    init() {
        // Mapbox SDK v3 reads MBXAccessToken from Info.plist automatically — no code needed.
        // Keychain persists across app reinstalls on iOS.
        // On first launch after a fresh install, clear stale Keychain data
        // so Face ID / session tokens from a previous install don't carry over.
        let hasLaunchedKey = "sierra.hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            // Clear all stale Keychain entries
            KeychainService.delete(key: "com.sierra.sessionToken")
            KeychainService.delete(key: "com.sierra.currentUser")
            KeychainService.delete(key: "com.sierra.hashedCredential")
            KeychainService.delete(key: "com.sierra.biometricEnabled")
            KeychainService.delete(key: "com.sierra.hasPromptedBiometric")
            SecureSessionStore.shared.clearAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
            ContentView()
                .applySierraTheme()

                // Biometric lock overlay - covers all roles
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
                Task { await AppDataStore.shared.checkOverdueMaintenance() }
            default:
                break
            }
        }
    }
}

import SwiftUI
import UserNotifications

// MARK: - AppDelegate
// Handles local notification permission only.
// APNs (remote push) requires a paid Apple Developer Program membership
// and is not used in this build. All notification banners are delivered
// via UNUserNotificationCenter local notifications instead, triggered
// by the Supabase Realtime events that already fire for every role.

final class SierraAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set ourselves as the UNUserNotificationCenter delegate so banners
        // appear even when the app is in the foreground.
        UNUserNotificationCenter.current().delegate = self

        // Request local notification permission (no APNs — no paid account needed).
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error { print("[Notifications] Permission error: \(error.localizedDescription)") }
            #if DEBUG
            print("[Notifications] Permission granted: \(granted)")
            #endif
        }
        return true
    }

    // Show banners even when app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - SierraApp

@main
struct SierraApp: App {
    @UIApplicationDelegateAdaptor(SierraAppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase
    private var lifecycle = AppLifecycleMonitor.shared

    init() {
        // On first launch after a fresh install, clear stale Keychain data
        // so Face ID / session tokens from a previous install don't carry over.
        let hasLaunchedKey = "sierra.hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
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

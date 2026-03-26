import SwiftUI
import UserNotifications

// MARK: - AppDelegate

final class SierraAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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

    // Deep-link tap handling: route to the correct trip/entity when user taps a banner.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let entityId = userInfo["entityId"] as? String {
            NotificationCenter.default.post(
                name: .sierraNotificationTapped,
                object: nil,
                userInfo: ["entityId": entityId]
            )
        }
        completionHandler()
    }
}

// MARK: - SierraApp

@main
struct SierraApp: App {
    @UIApplicationDelegateAdaptor(SierraAppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase
    private var lifecycle = AppLifecycleMonitor.shared
    @State private var foregroundTasks: [Task<Void, Never>] = []

    init() {
        // On first launch after a fresh install, clear stale Keychain data.
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

                if lifecycle.showBiometricLock {
                    BiometricLockView()
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .dismissKeyboardOnTap()
            .environment(AppDataStore.shared)
            .environment(AuthManager.shared)
            .animation(.easeInOut(duration: 0.25), value: lifecycle.showBiometricLock)
        }
        .onChange(of: scenePhase) { _, newPhase in
            lifecycle.handleScenePhaseChange(
                to: newPhase,
                hasSession: AuthManager.shared.isAuthenticated
            )
            switch newPhase {
            case .background:
                foregroundTasks.forEach { $0.cancel() }
                foregroundTasks.removeAll()
                AuthManager.shared.appDidEnterBackground()
            case .active:
                AuthManager.shared.appWillEnterForeground()
                foregroundTasks.forEach { $0.cancel() }
                foregroundTasks.removeAll()
                // Housekeeping on every foreground resume (tracked so we can
                // cancel immediately when app backgrounds, reducing watchdog risk).
                foregroundTasks.append(Task {
                    await AppDataStore.shared.checkOverdueMaintenance()
                })
                foregroundTasks.append(Task {
                    await AppDataStore.shared.checkExpiringDocuments()
                })
                // Deliver any past-due scheduled notifications (1-hr accept /
                // 30-min pre-inspection reminders). Non-fatal if user is not
                // signed in yet — the function returns 401 which is swallowed.
                foregroundTasks.append(Task {
                    await NotificationService.deliverScheduledNotifications()
                })
            default:
                break
            }
        }
    }
}

// MARK: - Notification name for deep-link tap routing
extension Notification.Name {
    static let sierraNotificationTapped = Notification.Name("sierraNotificationTapped")
}

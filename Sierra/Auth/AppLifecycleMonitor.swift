import Foundation
import SwiftUI

/// Monitors app lifecycle and triggers biometric re-authentication when the app
/// returns from background after the inactivity threshold.
@MainActor @Observable
final class AppLifecycleMonitor {

    static let shared = AppLifecycleMonitor()

    var showBiometricLock: Bool = false

    /// Seconds before requiring biometric on resume.

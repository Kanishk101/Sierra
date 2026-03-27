import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AccessibilitySettings {

    static let shared = AccessibilitySettings()

    var isColorBlindModeEnabled: Bool {
        didSet {
            guard oldValue != isColorBlindModeEnabled else { return }
            UserDefaults.standard.set(
                isColorBlindModeEnabled,
                forKey: SierraAccessibilityPalette.colorBlindModeKey
            )
            appearanceVersion &+= 1
        }
    }

    /// Increments whenever appearance preferences change, allowing a safe root refresh.
    private(set) var appearanceVersion: Int = 0

    private init() {
        isColorBlindModeEnabled = UserDefaults.standard.bool(
            forKey: SierraAccessibilityPalette.colorBlindModeKey
        )
    }

    var accentColor: Color { SierraAccessibilityPalette.accent }
}

enum SierraAccessibilityPalette {
    static let colorBlindModeKey = "com.sierra.accessibility.colorBlindModeEnabled"

    static var isColorBlindModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: colorBlindModeKey)
    }

    static var accent: Color {
        isColorBlindModeEnabled
            ? Color(red: 0.00, green: 0.35, blue: 0.78)
            : Color(red: 0.80, green: 0.36, blue: 0.00)
    }

    static var accentLight: Color {
        isColorBlindModeEnabled
            ? Color(red: 0.36, green: 0.60, blue: 0.95)
            : Color(red: 0.96, green: 0.68, blue: 0.20)
    }

    static var accentDark: Color {
        isColorBlindModeEnabled
            ? Color(red: 0.00, green: 0.23, blue: 0.56)
            : Color(red: 0.66, green: 0.28, blue: 0.00)
    }

    static var success: Color {
        isColorBlindModeEnabled
            ? Color(red: 0.00, green: 0.42, blue: 0.50)
            : Color("AlpineMint")
    }

    static var warning: Color {
        isColorBlindModeEnabled
            ? Color(red: 0.90, green: 0.62, blue: 0.00)
            : Color("Warning")
    }

    static var danger: Color {
        isColorBlindModeEnabled
            ? Color(red: 0.80, green: 0.47, blue: 0.65)
            : Color("Danger")
    }

    static var info: Color {
        isColorBlindModeEnabled
            ? Color(red: 0.00, green: 0.35, blue: 0.78)
            : Color("Info")
    }

    static var successUIColor: UIColor { UIColor(success) }
    static var warningUIColor: UIColor { UIColor(warning) }
    static var dangerUIColor: UIColor { UIColor(danger) }
    static var infoUIColor: UIColor { UIColor(info) }

    static var accentUIColor: UIColor {
        UIColor(accent)
    }
}

import SwiftUI

// MARK: - App Color Theme (FMS_SS Design)
extension Color {
    static let appOrange       = Color(red: 0.95, green: 0.55, blue: 0.10)
    static let appAmber        = Color(red: 1.0,  green: 0.75, blue: 0.20)
    static let appDeepOrange   = Color(red: 0.90, green: 0.35, blue: 0.08)
    static let appSurface      = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let appCardBg       = Color.white
    static let appTextPrimary  = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let appTextSecondary = Color(red: 0.45, green: 0.45, blue: 0.48)
    static let appDivider      = Color(red: 0.92, green: 0.92, blue: 0.93)
}

// MARK: - Tab Bar Appearance Helper
enum MaintenanceTheme {
    static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground

        let selectedColor = UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]

        let normalColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

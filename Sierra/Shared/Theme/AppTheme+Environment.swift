import SwiftUI
import UIKit

// MARK: - SierraThemeMode

/// App-wide theme mode preference.
enum SierraThemeMode {
    case light, dark, system
}

// MARK: - Environment Key

private struct SierraThemeKey: EnvironmentKey {
    static let defaultValue: SierraThemeMode = .system
}

extension EnvironmentValues {
    var sierraTheme: SierraThemeMode {
        get { self[SierraThemeKey.self] }
        set { self[SierraThemeKey.self] = newValue }
    }
}

// MARK: - SierraAppThemeModifier

/// Root-level modifier that applies Sierra appearance globally.
/// Call once on the app's root `WindowGroup` content:
///
///     ContentView()
///         .applySierraTheme()
struct SierraAppThemeModifier: ViewModifier {

    init() {
        // Navigation Bar
        let navBg = UIColor(named: "NavBarBg") ?? .systemBackground
        let titleCol = UIColor(named: "PrimaryText") ?? .label

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = navBg
        navAppearance.shadowColor = UIColor.separator
        navAppearance.titleTextAttributes = [
            .foregroundColor: titleCol,
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: titleCol,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        navAppearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]

        let scrollAppearance = navAppearance.copy() as UINavigationBarAppearance
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollAppearance
        UINavigationBar.appearance().tintColor = UIColor.systemOrange

        // Tab Bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .systemBackground
        tabAppearance.shadowColor = UIColor.separator

        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemOrange,
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.titleTextAttributes = selectedAttrs
        itemAppearance.selected.iconColor           = UIColor.systemOrange
        itemAppearance.normal.titleTextAttributes   = normalAttrs
        itemAppearance.normal.iconColor             = UIColor.secondaryLabel

        tabAppearance.stackedLayoutAppearance       = itemAppearance
        tabAppearance.inlineLayoutAppearance        = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance    = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance  = tabAppearance

        // Table / Collection backgrounds
        UITableView.appearance().backgroundColor      = UIColor.systemGroupedBackground
        UICollectionView.appearance().backgroundColor = UIColor.systemGroupedBackground
    }

    func body(content: Content) -> some View {
        content
            .tint(.orange)
            .environment(\.sierraTheme, .system)
    }
}

// MARK: - View Extension

extension View {
    /// Applies the complete Sierra theme globally. Call once at the app root.
    func applySierraTheme() -> some View {
        modifier(SierraAppThemeModifier())
    }
}

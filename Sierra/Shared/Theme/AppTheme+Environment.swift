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
        // ── Navigation Bar ──
        // Use UIColor(named:) for proper dynamic trait resolution
        let navBg = UIColor(named: "NavBarBg") ?? .systemBackground
        let titleCol = UIColor(named: "PrimaryText") ?? .label
        let shadowCol = UIColor(named: "Cloud") ?? .separator

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = navBg
        navAppearance.shadowColor = shadowCol
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

        // Use the SAME opaque appearance for all scroll states — prevents flicker
        let scrollAppearance = navAppearance.copy() as? UINavigationBarAppearance ?? UINavigationBarAppearance()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollAppearance
        UINavigationBar.appearance().tintColor = UIColor(named: "Ember") ?? .tintColor

        // ── Tab Bar ──
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .systemBackground
        tabAppearance.shadowColor = UIColor(SierraTheme.Colors.cloud)

        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(SierraTheme.Colors.ember),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(SierraTheme.Colors.granite),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.titleTextAttributes = selectedAttrs
        itemAppearance.selected.iconColor = UIColor(SierraTheme.Colors.ember)
        itemAppearance.normal.titleTextAttributes = normalAttrs
        itemAppearance.normal.iconColor = UIColor(SierraTheme.Colors.granite)

        tabAppearance.stackedLayoutAppearance = itemAppearance
        tabAppearance.inlineLayoutAppearance = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // ── Table / Collection View backgrounds ──
        UITableView.appearance().backgroundColor = UIColor(SierraTheme.Colors.appBackground)
        UICollectionView.appearance().backgroundColor = UIColor(SierraTheme.Colors.appBackground)
    }

    func body(content: Content) -> some View {
        content
            .tint(SierraTheme.Colors.ember)
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

import SwiftUI
import UIKit

// MARK: - SierraTab

/// Tab definitions for the Fleet Manager tab bar.
enum SierraTab: Int, CaseIterable {
    case dashboard
    case vehicles
    case drivers
    case tasks
    case maintenance

    var title: String {
        switch self {
        case .dashboard:   "Dashboard"
        case .vehicles:    "Vehicles"
        case .drivers:     "Drivers"
        case .tasks:       "Tasks"
        case .maintenance: "Maintenance"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:   "square.grid.2x2"
        case .vehicles:    "truck.box"
        case .drivers:     "person.2"
        case .tasks:       "list.clipboard"
        case .maintenance: "wrench.and.screwdriver"
        }
    }

    var selectedIcon: String {
        switch self {
        case .dashboard:   "square.grid.2x2.fill"
        case .vehicles:    "truck.box.fill"
        case .drivers:     "person.2.fill"
        case .tasks:       "list.clipboard.fill"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - SierraTabViewModifier

/// Applies UITabBarAppearance with Sierra styling:
/// White/card surface background, ember selected tint, granite unselected, cloud top separator.
struct SierraTabViewModifier: ViewModifier {

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        // Top separator
        appearance.shadowColor = UIColor(SierraTheme.Colors.cloud)

        // Selected state
        let selectedFont = UIFontMetrics(forTextStyle: .caption2)
            .scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .bold))
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(SierraTheme.Colors.ember),
            .font: selectedFont
        ]

        // Unselected state
        let normalFont = UIFontMetrics(forTextStyle: .caption2)
            .scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .medium))
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(SierraTheme.Colors.granite),
            .font: normalFont
        ]

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.titleTextAttributes = selectedAttributes
        itemAppearance.selected.iconColor = UIColor(SierraTheme.Colors.ember)
        itemAppearance.normal.titleTextAttributes = normalAttributes
        itemAppearance.normal.iconColor = UIColor(SierraTheme.Colors.granite)

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    func body(content: Content) -> some View {
        content
            .tint(SierraTheme.Colors.ember)
    }
}

// MARK: - View Extension

extension View {
    /// Applies Sierra tab bar styling. Call on the root `TabView`.
    func sierraTabBar() -> some View {
        modifier(SierraTabViewModifier())
    }
}

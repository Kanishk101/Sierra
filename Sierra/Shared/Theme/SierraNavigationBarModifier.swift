import SwiftUI
import UIKit

// MARK: - NavigationBarItem

/// Trailing navigation bar button definition.
struct NavigationBarItem: Identifiable {
    let id = UUID()
    let systemName: String
    let action: () -> Void
    var tint: Color = .white
}

// MARK: - SierraNavigationBarModifier

/// Configures UINavigationBar appearance in the Sierra style:
/// SummitNavy/dark navy background, white title, no separator, minimal back button.
struct SierraNavigationBarModifier: ViewModifier {

    let title: String
    var subtitle: String? = nil
    var showLogo: Bool = false
    var trailingItems: [NavigationBarItem] = []

    init(
        title: String,
        subtitle: String? = nil,
        showLogo: Bool = false,
        trailingItems: [NavigationBarItem] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showLogo = showLogo
        self.trailingItems = trailingItems

        // ── Configure UINavigationBarAppearance ──
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "NavBarBg") ?? .systemBackground
        appearance.shadowColor = UIColor(named: "Cloud") ?? .separator

        let titleColor = UIColor(named: "PrimaryText") ?? .label
        // Title
        appearance.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
        ]

        // Large title
        appearance.largeTitleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        // Back button
        appearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.clear
        ]

        let scrollAppearance = appearance.copy() as? UINavigationBarAppearance ?? UINavigationBarAppearance()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollAppearance
        UINavigationBar.appearance().tintColor = UIColor(named: "Ember") ?? .tintColor
    }

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !trailingItems.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ForEach(trailingItems) { item in
                            Button(action: item.action) {
                                Image(systemName: item.systemName)
                                    .foregroundStyle(item.tint)
                            }
                        }
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies Sierra navigation bar styling.
    func sierraNavigationBar(
        title: String,
        subtitle: String? = nil,
        trailing: [NavigationBarItem] = []
    ) -> some View {
        modifier(SierraNavigationBarModifier(
            title: title,
            subtitle: subtitle,
            trailingItems: trailing
        ))
    }
}

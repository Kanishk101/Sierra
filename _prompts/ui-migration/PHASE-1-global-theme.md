# PHASE 1 — Global Theme Layer & App Entry Point

## Context
You are working on `Kanishk101/Sierra` (`backup-current` branch). This is a SwiftUI iOS fleet management app (iOS 26+, MVVM, Supabase backend). The Supabase backend, all Models, Services, ViewModels, and business logic are **100% correct and must not be touched**.

This phase migrates the global theme layer from custom Sierra design tokens to strictly Apple-native system colors, with `systemOrange` as the single primary brand color.

---

## THE PALETTE — STRICT RULES (apply everywhere, all phases)

| Role | Value | Usage |
|---|---|---|
| Primary/Brand | `.orange` / `Color(.systemOrange)` / `UIColor.systemOrange` | CTAs, active tab, tint, accent icons, links |
| Background | `Color(.systemGroupedBackground)` / `UIColor.systemGroupedBackground` | Screen backgrounds |
| Card/Row surface | `Color(.secondarySystemGroupedBackground)` | Cards, list rows, grouped containers |
| Primary text | `.primary` / `.foregroundStyle(.primary)` | Titles, values |
| Secondary text | `.secondary` / `.foregroundStyle(.secondary)` | Subtitles, captions, placeholders |
| Tertiary text | `.tertiary` / `.foregroundStyle(.tertiary)` | Mono IDs, timestamps |
| Separator | `Color(.separator)` / `UIColor.separator` | Dividers, borders, nav shadow |
| Success | `Color(.systemGreen)` / `.green` | Active/available/completed |
| Warning | `Color(.systemOrange)` / `.orange` | Expiring/pending |
| Danger | `Color(.systemRed)` / `.red` | Expired/cancelled/failed |
| Info | `Color(.systemBlue)` / `.blue` | Scheduled/informational |
| Shadow | `.shadow(color: .black.opacity(0.04), radius: 8, y: 4)` | Standard card shadow |
| Modal shadow | `.shadow(color: .black.opacity(0.08), radius: 8, y: 2)` | Elevated cards |

**Never use**: `SierraTheme.Colors.*` for any color in View files. Keep `SierraTheme.Colors.*` definitions inside `SierraTheme.swift` (they are still referenced by some shared components that haven't been migrated yet), but stop using them in all View layers — use system equivalents instead.

**Never remove**: `SierraTheme.swift`, `SierraFont.swift`, shared theme components like `SierraBadge`, `SierraAvatarView`, `SierraButton`, etc. — these are still used in some places and must remain compilable.

---

## NAVIGATION BAR RULES (apply to ALL screens, all phases)

Every `NavigationStack` screen must use the **iOS native large title that morphs** on scroll:

```swift
// On NavigationStack content:
.navigationTitle("Screen Title")
.toolbarTitleDisplayMode(.inlineLarge)   // morphs large→inline as user scrolls
.toolbarBackground(.hidden, for: .navigationBar)  // transparent until scroll
```

Exceptions — these screens use standard inline (no large title):
- Modal sheets / `.presentationDetents` views
- Auth screens (Login, OTP, Password change) — keep their existing navigation style

The large title morphing is the most important iOS-native visual behaviour. It must be present on every main tab screen: Dashboard, Vehicles, Staff/Drivers, Trips, Driver Home, Maintenance.

---

## FILES TO CHANGE IN THIS PHASE

### 1. `Sierra/Shared/Theme/AppTheme+Environment.swift`

Replace the entire `SierraAppThemeModifier.init()` body with:

```swift
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
```

In `body(content:)`, change:
```swift
// BEFORE
.tint(SierraTheme.Colors.ember)
// AFTER
.tint(.orange)
```

### 2. `Sierra/Shared/Theme/Color+Sierra.swift`

Mark the helper as deprecated:

```swift
import SwiftUI

extension Color {
    /// Deprecated. Use system semantic colors (.primary, .secondary, .orange, .green, .red, .blue, etc.)
    @available(*, deprecated, message: "Use system semantic colors instead of Sierra tokens.")
    static func sierra(_ token: Color) -> Color { token }
}
```

### 3. `Sierra/Shared/Theme/SierraTheme.swift`

No logic changes. Replace all em-dash comment separators (`—`) with hyphens (`-`). Example:
```swift
// BEFORE: /// #0D1F3C — NavigationBar
// AFTER:  /// #0D1F3C - NavigationBar
```

### 4. `Sierra/Shared/Theme/SierraTextStyle.swift`, `SierraFont.swift`, `SierraSpacing.swift`, `SierraPickerRow.swift`, `SierraAlertBanner.swift`, `SierraBadge.swift`, `SierraButton.swift`

Same comment style fix only: em-dash `—` → hyphen `-` in all inline doc comments. No logic changes.

---

## DO NOT TOUCH
- `SierraTheme.swift` color token definitions (the `public static let` values)
- Any file in `Shared/Models/`, `Shared/Services/`, `Auth/Models/`, `Auth/Services/`, `Auth/ViewModels/`, `Driver/ViewModels/`, `FleetManager/ViewModels/`
- `SupabaseManager.swift`, `AppDataStore.swift`, or any networking/persistence code
- `SierraAvatarView.swift`, `SierraBadge.swift`, `SierraCard.swift` — keep compilable as-is

---

## DELIVERABLE
All 7 files above updated and compiling without errors. The app tint is now `.orange`. Tab bar active is `systemOrange`. Tab bar inactive is `secondaryLabel`. Navigation bar shadow uses `UIColor.separator`. Table/collection backgrounds use `systemGroupedBackground`.

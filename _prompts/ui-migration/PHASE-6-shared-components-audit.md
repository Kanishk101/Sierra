# PHASE 6 — Shared Components & Final Consistency Audit

## Context
This is the final phase. It covers:
1. Remaining shared theme component files that need comment-style cleanup
2. The `AdminDashboardView.swift` (the root admin screen that wraps the tab view)
3. The `Onboarding/` module
4. A full cross-app consistency audit

Read Phase 1 for the complete palette. All data/backend untouched.

---

## FILE 1: `AdminDashboardView.swift`

This wraps `FleetManagerTabView` or composes the admin tabs. Apply:
- Any custom nav bar modifications → remove, let `AppTheme+Environment` handle globally
- Any `SierraTheme.Colors.*` → system equivalents
- Remove any debug `print` statements (optional, clean code)

---

## FILES 2-8: Theme Comment Cleanup (em-dash → hyphen only)

These files have **identical logic**, only comment style changed. Do a find-replace of ` — ` → ` - ` in inline doc comments only:

- `Sierra/Shared/Theme/SierraTheme.swift` ✓ (done in Phase 1)
- `Sierra/Shared/Theme/SierraTextStyle.swift`
- `Sierra/Shared/Theme/SierraFont.swift`
- `Sierra/Shared/Theme/SierraSpacing.swift`
- `Sierra/Shared/Theme/SierraPickerRow.swift`
- `Sierra/Shared/Theme/SierraAlertBanner.swift`
- `Sierra/Shared/Theme/SierraBadge.swift`
- `Sierra/Shared/Theme/SierraButton.swift`
- `Sierra/Shared/Theme/VehicleStatus.swift`
- `Sierra/Shared/Theme/DriverStatus.swift`
- `Sierra/Shared/Theme/VehicleCardView.swift`
- `Sierra/Shared/Theme/TripCardView.swift`
- `Sierra/Shared/Theme/StatCardView.swift`
- `Sierra/Shared/Theme/StaffListRowView.swift`
- `Sierra/Shared/Theme/Text+Sierra.swift`

---

## FILE: `SierraApp.swift`

Verify `.applySierraTheme()` is still called at the root. No changes needed unless there are custom color overrides applied here.

---

## ONBOARDING MODULE (`Sierra/Onboarding/`)

Apply the same palette to any onboarding screens:
- Slide backgrounds: `Color(.systemGroupedBackground)` or clean white `Color(.systemBackground)`
- Accent illustrations/icons: `.foregroundStyle(.orange)`
- Continue/Get Started button: `.orange` fill, white text
- Page indicators: `.orange` active dot, `Color(.separator)` inactive
- Skip button: `.foregroundStyle(.secondary)`

---

## FINAL CONSISTENCY AUDIT CHECKLIST

After all phases, do a project-wide search for each of the following and fix any remaining instances:

### Search & Replace:
| Search for | Replace with |
|---|---|
| `SierraTheme.Colors.ember` | `.orange` or `Color(.systemOrange)` |
| `SierraTheme.Colors.appBackground` | `Color(.systemGroupedBackground)` |
| `SierraTheme.Colors.cardSurface` | `Color(.secondarySystemGroupedBackground)` |
| `SierraTheme.Colors.primaryText` | `.primary` |
| `SierraTheme.Colors.secondaryText` | `.secondary` |
| `SierraTheme.Colors.granite` | `.secondary` or `Color(.secondaryLabel)` |
| `SierraTheme.Colors.slate` | `.primary` |
| `SierraTheme.Colors.cloud` | `Color(.separator)` |
| `SierraTheme.Colors.alpineMint` | `.green` or `Color(.systemGreen)` |
| `SierraTheme.Colors.danger` | `.red` or `Color(.systemRed)` |
| `SierraTheme.Colors.warning` | `.orange` or `Color(.systemOrange)` |
| `SierraTheme.Colors.info` | `.blue` or `Color(.systemBlue)` |
| `SierraTheme.Colors.success` | `.green` or `Color(.systemGreen)` |
| `SierraTheme.Colors.sierraBlue` | `.blue` or `Color(.systemBlue)` |
| `SierraTheme.Colors.summitNavy` | `.primary` or `Color(.label)` |
| `SierraTheme.Colors.divider` | `Color(.separator)` |
| `SierraTheme.Colors.navBarBg` | Keep as-is (used by UIKit appearance, not SwiftUI) |
| `SierraFont.body(` | `.font(.system(size:` |
| `SierraFont.headline` | `.font(.headline)` |
| `SierraFont.bodyText` | `.font(.body)` |
| `SierraFont.subheadline` | `.font(.subheadline)` |
| `SierraFont.caption1` | `.font(.caption)` |
| `SierraFont.caption2` | `.font(.caption2)` |
| `SierraFont.title1` | `.font(.title)` |
| `SierraFont.title2` | `.font(.title2)` |
| `SierraFont.largeTitle` | `.font(.largeTitle)` |
| `sierraShadow(SierraTheme.Shadow.card)` | `.shadow(color: .black.opacity(0.04), radius: 8, y: 4)` |
| `sierraShadow(SierraTheme.Shadow.modal)` | `.shadow(color: .black.opacity(0.08), radius: 8, y: 2)` |
| `.navigationBarTitleDisplayMode(.inline)` | `.toolbarTitleDisplayMode(.inlineLarge)` (on main tab screens only) |
| `LinearGradient(colors: [SierraTheme.Colors.summitNavy` | Remove, replace with system bg |

### Exceptions (DO NOT replace these):
- `SierraTheme.Colors.*` inside `SierraTheme.swift` itself (that's the definition file)
- `SierraAvatarView.*` gradient parameters — keep using `SierraAvatarView.driver()` etc.
- `SierraTheme.Colors.navBarBg` in `AppTheme+Environment.swift` — this is UIKit-level
- `SierraTheme.Colors.ember` in `SierraTabBar.swift` if it's in the shared component itself
- Any file in `Shared/Models/`, `Shared/Services/`, ViewModels, Auth services

---

## NAVIGATION BAR AUDIT

Verify **every main NavigationStack screen** (embedded in a tab) has:
```swift
.toolbarTitleDisplayMode(.inlineLarge)    // morphs large → inline on scroll
.toolbarBackground(.hidden, for: .navigationBar)  // transparent bg until scroll
```

Screens that should have this:
- `DashboardHomeView` ✓ (Phase 2)
- `VehicleListView` ✓ (Phase 3)
- `TripsListView` ✓ (Phase 3)
- `StaffListView` / `StaffTabView` ✓ (Phase 3)
- `DriverHomeView` ✓ (Phase 4)
- Maintenance home screen ✓ (Phase 4)
- `AdminProfileView` — depends on presentation; if pushed, use large title

Screens that should NOT use large title (use inline or no title):
- All sheet/modal presentations
- `LoginView`, `TwoFactorView`, `ForcePasswordChangeView`
- Detail views pushed modally (not in tab)

---

## COMPILE CHECK PROCEDURE

After all phases, verify:
1. Build succeeds with zero errors
2. No warnings about deprecated `sierra()` color helper (warnings are OK, errors are not)
3. All `SierraTheme.Colors.*`, `SierraFont.*`, `SierraShadow.*` in the **definition files** still exist and compile (they're still referenced by some shared components)
4. `AppDataStore`, `AuthManager`, all ViewModels — untouched
5. Supabase integration — untouched
6. Run on simulator: tap through all tabs, check no missing colors, no dark backgrounds on light screens, orange is the primary accent throughout

---

## WHAT MUST NEVER BE CHANGED (across all phases)

- `Shared/Models/*.swift` — all data models
- `Shared/Services/*.swift` — Supabase, network services
- `Shared/Services/AppDataStore.swift` — the central data store
- `Auth/AuthManager.swift` backend logic
- `Auth/BiometricManager.swift`
- `Auth/Models/`, `Auth/Services/`, `Auth/ViewModels/`
- `Driver/ViewModels/`, `FleetManager/ViewModels/`
- `supabase/` directory
- `SierraTheme.swift` color token definitions
- `SierraAvatarView.swift`, `SierraBadge.swift`, `SierraCard.swift`, `SierraButton.swift` — keep these compilable as shared components even if some views stop using them

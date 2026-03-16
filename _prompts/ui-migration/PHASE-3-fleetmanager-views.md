# PHASE 3 — Fleet Manager Views Migration

## Context
Files in `Sierra/FleetManager/` and `Sierra/FleetManager/Views/`. Read Phase 1 for the complete palette and navigation bar rules.

All backend logic, ViewModels, and data calls remain **100% unchanged**. Only the visual layer changes.

---

## FILE 1: `FleetManagerTabView.swift`

The tab container placeholder screens. Key changes:

```swift
var body: some View {
    TabView {
        // ... tabs same labels/icons ...
    }
    .tint(SierraTheme.Colors.ember)   // KEEP — this is the tab tint, already orange-equivalent
}
```

Placeholder tabs (Dashboard, Vehicles, Drivers, Reports):
- **Remove** the `LinearGradient(summitNavy → sierraBlue)` background
- **Replace** with `Color(.secondarySystemGroupedBackground).ignoresSafeArea()`
- Icon: remove `.opacity(0.8)`, use `color` at full opacity
- Title text: `.foregroundStyle(SierraTheme.Colors.ember)` → `.foregroundStyle(.orange)`
- "Coming soon" text: `.white.opacity(0.5)` → `.foregroundStyle(.secondary)`
- Dashboard tab icon color argument: `.blue` → `.orange`

Settings tab: keep the `LinearGradient` background — this is the only placeholder that keeps the dark theme (it's the sign-out screen, not a real content tab).

---

## FILE 2: `AdminProfileView.swift`

Apply:
- Background: `Color(.systemGroupedBackground).ignoresSafeArea()`
- Any `SierraTheme.Colors.*` → system equivalents per Phase 1 palette
- Nav title: `.navigationTitle("Profile")` + `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden, for: .navigationBar)`
- All profile info rows: `Color(.secondarySystemGroupedBackground)` rounded containers
- Tappable links/buttons: `.foregroundStyle(.orange)`
- Avatar: keep `SierraAvatarView` if present, OR plain `Circle().fill(Color(.systemGray5))` with initials text

---

## FILE 3: `VehicleListView.swift`

Key changes:
- Screen background: `Color(.systemGroupedBackground).ignoresSafeArea()`
- Navigation: `.navigationTitle("Vehicles")` + `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden, for: .navigationBar)`
- Add button / FAB: `.foregroundStyle(.orange)` or `SierraFAB` (keep if present)
- Search bar: use `.searchable(text:, prompt:)` native modifier
- Vehicle row/card background: `Color(.secondarySystemGroupedBackground)` in `RoundedRectangle(cornerRadius: 16)`
- Row shadow: `.shadow(color: .black.opacity(0.04), radius: 8, y: 4)`
- Vehicle status badges: system colors — `.systemGreen` active, `.systemOrange` maintenance/idle, `.systemRed` out of service
- Remove any `SierraTheme.Colors.*` references
- Vehicle icon: `.foregroundStyle(.secondary)` or `.foregroundStyle(.blue)`
- License plate text: `.font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)`
- Section headers (if any): `.font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)`

---

## FILE 4: `VehicleDetailView.swift`

Key changes:
- Navigation: `.navigationTitle(vehicleName)` + `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden, for: .navigationBar)`
- Background: `Color(.systemGroupedBackground)`
- All info section containers: `Color(.secondarySystemGroupedBackground)` rounded (cornerRadius 16)
- Info rows: `Divider().padding(.leading, 16)` between rows
- Status badge: system colors
- Action buttons (edit, deactivate): primary actions `.orange`, destructive `.red`
- Map view (if present): keep MapKit, just fix surrounding background
- Remove all `SierraTheme.Colors.*`, `SierraFont.*`, `sierraShadow`

---

## FILE 5: `AddVehicleView.swift`

This is a form/sheet. Apply:
- Form background: `Color(.systemGroupedBackground)`
- Section backgrounds: `Color(.secondarySystemGroupedBackground)` or use native `Form` + `Section` which handles this automatically
- Consider replacing custom layout with native `Form { Section { ... } }` if the current implementation uses manual `VStack` — this automatically gives correct iOS grouped appearance
- Text fields: use native `TextField` with `.textFieldStyle(.roundedBorder)` OR keep `SierraTextField` if it compiles
- Primary action button (Save/Add): `.orange` fill
- Cancel button: `.foregroundStyle(.secondary)`
- Navigation: `.navigationTitle("Add Vehicle")` + standard inline (this is a sheet/modal)
- Remove any `SierraTheme.Colors.*`, `SierraFont.*` in this file

---

## FILE 6: `TripsListView.swift`

Key changes:
- Screen background: `Color(.systemGroupedBackground).ignoresSafeArea()`
- Navigation: `.navigationTitle("Trips")` + `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden, for: .navigationBar)`
- Trip rows in a single grouped container `Color(.secondarySystemGroupedBackground)` with `Divider` separators, OR individual cards — whichever matches current structure
- Status badges: `.green`/`.blue`/`.secondary`/`.red` per trip status
- Filter pills (if any): selected = `.orange` fill + `.white` text; unselected = `Color(.secondarySystemGroupedBackground)` + `Color(.separator)` border
- Route text: `.font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)`
- Task ID: `.font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)`
- FAB / add button: `.orange`

---

## FILE 7: `TripDetailView.swift`

Key changes:
- Navigation: large morphing title with trip task ID or "Trip Details"
- Background: `Color(.systemGroupedBackground)`
- Info sections: `Color(.secondarySystemGroupedBackground)` containers with internal `Divider` separators
- Status badge: system status colors
- Driver/vehicle info rows: standard info-row pattern (label left `.secondary`, value right `.primary`)
- Map section: keep MapKit, fix container background
- Action buttons (approve, cancel trip): destructive = `.red`, primary = `.orange`
- Remove all custom Sierra tokens

---

## FILE 8: `CreateTripView.swift`

Same as AddVehicleView pattern:
- Sheet/modal — inline navigation title
- Native `Form` or `Color(.systemGroupedBackground)` + `Color(.secondarySystemGroupedBackground)` sections
- Primary button: `.orange`
- Date/time pickers: native SwiftUI pickers
- Remove Sierra tokens

---

## FILE 9: `PendingApprovalsView.swift`

Key changes:
- Background: `Color(.systemGroupedBackground)`
- Approval cards: `Color(.secondarySystemGroupedBackground)` rounded containers
- Approve button: `.orange` or `.green` depending on context
- Reject button: `.red`
- Navigation: `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden)`

---

## FILE 10: `QuickActionsSheet.swift`

This is a presented sheet:
- Background: `Color(.systemGroupedBackground)` or `.regularMaterial`
- Action buttons: each with system icon + label, tint `.orange`
- Destructive actions: `.red`
- Standard `.presentationDetents([.medium])` if not already set

---

## FILE 11: `AnalyticsDashboardView.swift`

This screen opened as a full sheet:
- Background: `Color(.systemGroupedBackground)`
- Navigation: `.navigationTitle("Analytics")` — standard inline for sheets
- Chart colors: use system `.blue`, `.green`, `.orange`, `.red`, `.purple` — NO custom Sierra color tokens
- Section headers: `.font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)`
- Stat cards: `Color(.secondarySystemGroupedBackground)` background
- All `SierraTheme.Colors.*` → system equivalents
- Remove `SierraFont.*` — use `.system(size:, weight:)` or semantic fonts (`.headline`, `.subheadline`, `.caption`, `.body`)

---

## FILE 12: `StaffListView.swift` — FULL SIMPLIFICATION

This file is heavily simplified in Fleetora (15.5KB → 6.7KB). Rewrite the staff row to use **inline native components** instead of `StaffListRowView` theme component:

```swift
private func staffRow(_ member: StaffMember) -> some View {
    HStack(spacing: 14) {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
            Text(member.initials)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        VStack(alignment: .leading, spacing: 2) {
            Text(member.displayName)
                .font(.headline).foregroundStyle(.primary)
            Text(member.email)
                .font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        staffStatusBadge(member)
    }
    .padding(16)
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
}
```

Status badge — replace `SierraBadge` with inline Text:
```swift
private func staffStatusBadge(_ member: StaffMember) -> some View {
    // pending → "Pending" orange; suspended → "Suspended" red; available → "Available" green; etc.
    let (text, color): (String, Color) = {
        if member.status == .pendingApproval { return ("Pending", Color(.systemOrange)) }
        if member.status == .suspended       { return ("Suspended", Color(.systemRed)) }
        switch member.availability {
        case .onTrip, .onTask: return ("Busy",        Color(.systemRed))
        case .available:       return ("Available",   Color(.systemGreen))
        case .unavailable:     return ("Unavailable", Color(.systemOrange))
        }
    }()
    return Text(text)
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
}
```

Picker segment background: `Color(.systemGroupedBackground)`
List scroll background: `Color(.systemGroupedBackground).ignoresSafeArea()`
Navigation: `.navigationTitle("Staff")` + `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden, for: .navigationBar)`

---

## FILE 13: `StaffTabView.swift`

Navigation:
- `.toolbarTitleDisplayMode(.inlineLarge)` + `.toolbarBackground(.hidden, for: .navigationBar)`
- Add button: `Image(systemName: "plus")` with `.foregroundStyle(.orange)`

Filter chips (Applications tab):
- Selected: `.orange` fill, `.white` text
- Unselected: `Color(.secondarySystemGroupedBackground)` + `Color(.separator)` strokeBorder

Application card:
- Background: `Color(.secondarySystemGroupedBackground)` + `sierraShadow` (keep shadow)
- "Review" label: `.foregroundStyle(.orange)` with `.orange.opacity(0.10)` background capsule

Staff row in `StaffDirectoryView` — keep `SierraAvatarView` + `sierraShadow` (these are explicitly kept in Fleetora)

`StaffProfileSheetView` info block:
- Container background: `Color(.secondarySystemGroupedBackground)` in `RoundedRectangle(cornerRadius: 20)`
- Dividers between rows: `Divider().padding(.leading, 16)`
- Label text: `.body.foregroundStyle(.secondary)` / value text: `.body.weight(.semibold).foregroundStyle(.primary)`

---

## FILE 14: `StaffReviewSheet.swift`

Apply:
- Sheet background: `Color(.systemGroupedBackground)`
- Info sections: `Color(.secondarySystemGroupedBackground)` rounded containers
- Approve button: `.green` fill
- Reject button: `.red`
- All Sierra tokens → system equivalents

---

## FILE 15: `CreateStaffView.swift`

Sheet form:
- `Color(.systemGroupedBackground)` background
- Native form sections or manual `Color(.secondarySystemGroupedBackground)` containers
- Primary action: `.orange`
- Remove Sierra tokens

---

## GLOBAL RULES FOR ALL FILES IN THIS PHASE
1. `SierraTheme.Colors.*` → system color equivalents (see Phase 1 table)
2. `SierraFont.body(x, weight: .y)` → `.font(.system(size: x, weight: .y))`
3. `SierraFont.headline` → `.font(.headline)`
4. `SierraFont.subheadline` → `.font(.subheadline)`
5. `SierraFont.caption1/caption2` → `.font(.caption)` / `.font(.caption2)`
6. `SierraFont.bodyText` → `.font(.body)`
7. `.sierraShadow(SierraTheme.Shadow.card)` → `.shadow(color: .black.opacity(0.04), radius: 8, y: 4)`
8. `.background(SierraTheme.Colors.cardSurface, ...)` → `.background(Color(.secondarySystemGroupedBackground), ...)`
9. `.background(SierraTheme.Colors.appBackground...)` → `.background(Color(.systemGroupedBackground)...)`
10. Keep all `@Environment`, `@State`, `store.*` data calls **exactly as-is**

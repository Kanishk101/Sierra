# Phase 14 — Navigation Fixes + Visual Consistency Across All Pages

## Scope
Fix all navigation/sheet presentations. Standardise colors, typography, and header style
so every page, sheet, and modal looks like it belongs to the same app. Apply Apple HIG
throughout. Remove double segmented filters. Make UI intuitive and purposeful.

---

## Part 1 — Apple HIG Audit and Fixes

### 1A: Remove All Double Segmented Control Patterns

Searching for `Picker` with `.segmented` pickerStyle or `ScrollView(.horizontal)` chip rows
that duplicate a top-level `Picker` or `TabView`. Specific offenders:

**StaffTabView** — currently has a role filter (All / Drivers / Maintenance) as a segmented
control AND a separate section for Fleet Managers. This is acceptable but verify the
`Picker` for role filter is `.segmented` (not a chips row) and is at most ONE filter control.
If there are both a Picker AND filter chips in the same view, remove the chips.

**MaintenanceRequestsView** — has a 3-segment picker (Tasks / Spare Parts / History)
and may have a second status filter inside each tab. If the inner content also has a
segmented or chip-based filter, flatten to a single toolbar Menu with a filter icon.

**AnalyticsDashboardView** — the pill row selector added in Phase 13 replaces segmented;
no duplication.

Rule: **maximum one filter/tab control per screen level**. If a list needs filtering, use
a toolbar `Menu` button (filter icon) with `Picker` or a sheet, not a visible chip row.

### 1B: Sheet and Modal Header Consistency

**Problem**: Some sheets use `.navigationBarTitleDisplayMode(.inline)` with a white
NavigationStack background. Others have large titles. The sheet drag handle area and the
header merge incorrectly when using `.presentationDetents` with default background colors.

**Rule for all modal sheets / presented navigation stacks:**
```swift
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(.visible, for: .navigationBar)
.toolbarColorScheme(.none, for: .navigationBar)  // inherit system color
```

The sheet background and the navigation bar background must be the same semantic color
(`Color(.systemGroupedBackground)` for forms, `Color(.systemBackground)` for content sheets).
Never have a white/bright header floating over a gray body — they must match.

**For every `NavigationStack` inside a `.sheet`:**, add:
```swift
.background(Color(.systemGroupedBackground).ignoresSafeArea())
```
to the root view inside the NavigationStack. This prevents the jarring white nav bar
over gray content flash.

### 1C: Consistent Page Header Appearance

All pages (not sheets) that are inside `AdminDashboardView`'s tabs (Vehicles, Staff, Trips)
should use:
```swift
.navigationTitle("[Title]")
.navigationBarTitleDisplayMode(.large)
.background(Color(.systemGroupedBackground).ignoresSafeArea())
```

All detail views pushed from those lists:
```swift
.navigationBarTitleDisplayMode(.inline)
```

All standalone sheets presented modally:
```swift
.navigationBarTitleDisplayMode(.inline)
// Header title is clear, reads correctly against body background
```

### 1D: Orange Tint Consistency

The app uses `Color(.systemOrange)` / `.orange` as the primary brand color. Every interactive
element should use `.tint(.orange)` at the appropriate scope:
- All `NavigationStack` containers: `.tint(.orange)`
- All `TabView` containers: `.tint(.orange)` (already set in most places)
- All `Button` primary CTAs: orange fill
- All `Toggle`: `.tint(.orange)`
- All `Picker`: `.accentColor(.orange)` or system default (do NOT override to different colors)

Secondary actions (Cancel, Done): system blue or `.secondary` — **not orange**. Currently
many "Cancel" buttons are `.foregroundStyle(.secondary)` which is correct. Do not change these.

### 1E: List Row Consistency

All `List` rows across the app should use consistent density:
- Icon + VStack(title + subtitle) + Spacer + disclosure/action: standard row height
- Status badge: right-aligned `SierraBadge` or capsule pill with correct color
- Swipe actions: only destructive actions in trailing swipe, non-destructive in leading

No list should mix `List` style with manual `VStack` cards inside the same screen —
pick one or the other per screen.

---

## Part 2 — Navigation Stack Fixes

### 2A: VehicleListView Navigation

`VehicleListView` uses NavigationLink but the NavigationStack is declared in the parent tab.
Verify:
```swift
// In AdminDashboardView Tab value 1:
NavigationStack {
    VehicleListView()
        .navigationDestination(for: Vehicle.ID.self) { id in
            VehicleDetailView(vehicleId: id)
        }
}
```
`VehicleListView` must NOT declare its own NavigationStack or .navigationDestination —
only the tab-level one.

### 2B: StaffTabView Navigation

`StaffTabView` contains a `List` of staff and opens `StaffDetailSheet` or `StaffReviewSheet`
as `.sheet` (not push navigation). Verify sheets are presented modally with:
```swift
.sheet(item: $selectedStaff) { member in
    StaffDetailSheet(member: member)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
}
```

### 2C: TripsListView / TripsAndMapContainerView

`TripsAndMapContainerView` uses a `Picker` to switch between Trips list and Live Map.
Verify this is a single `Picker(.segmented)` at the top — if it duplicates filtering
that exists inside `TripsListView`, remove the inner one.

All trip detail navigation should use `NavigationLink(value:)` and `.navigationDestination`
declared ONCE in the NavigationStack wrapping TripsListView.

### 2D: AdminDashboardView QuickActions Fix

When QuickActions sheet is dismissed and then a creation sheet (AddVehicleView, CreateTripView)
is shown via `Task.sleep(300ms)` → `showCreateTrip = true`, there's a brief flash where
both are dismissing/presenting simultaneously. Fix:

The creation sheets are attached to `QuickActionsSheet` itself via `.sheet(isPresented:)`.
After `dismiss()` is called on QuickActionsSheet, the sheet is released and the `@State`
vars that control child sheets in QuickActionsSheet are also released — the sheets
never open. Move creation sheet state to `AdminDashboardView` instead:

```swift
// In AdminDashboardView:
@State private var showCreateTrip    = false
@State private var showAddVehicle    = false
@State private var showCreateStaff   = false
@State private var showCreateMaint   = false

// QuickActionsSheet callback receives an action tag, dismisses, parent handles sheet
.sheet(isPresented: $showQuickActions) {
    QuickActionsSheet { destination in
        // navigation destinations (existing)
        switch destination { ... }
    } onCreation: { tag in
        // creation actions — parent opens the sheet after QuickActions dismisses
        switch tag {
        case "trip":    showCreateTrip  = true
        case "vehicle": showAddVehicle  = true
        case "staff":   showCreateStaff = true
        case "maint":   showCreateMaint = true
        default: break
        }
    }
}
// Attach creation sheets to AdminDashboardView directly:
.sheet(isPresented: $showCreateTrip)    { CreateTripView().presentationDetents([.large]) }
.sheet(isPresented: $showAddVehicle)    { AddVehicleView().presentationDetents([.large]) }
.sheet(isPresented: $showCreateStaff)   { CreateStaffView().presentationDetents([.large]) }
```

In `QuickActionsSheet`, add an `onCreation: (String) -> Void` callback and call it with the
tag instead of showing local sheets. Remove the `showCreateTrip` etc. `@State` vars and local
`.sheet` modifiers from QuickActionsSheet entirely.

---

## Part 3 — Color + Theme Token Audit

### 3A: `SierraTheme.Colors` Usage

The codebase has `SierraTheme.Colors.ember` (orange) and `SierraTheme.Colors.summitNavy`.
All direct `.orange` / `Color.orange` usages should be audited:
- Primary brand actions (CTAs, selected state, active indicators): `SierraTheme.Colors.ember` or `Color(.systemOrange)`
- Map annotation navy background: `SierraTheme.Colors.summitNavy`
- Do NOT use raw `Color.orange` where a semantic token exists

### 3B: Status Color Consistency

Define canonical status colors once and use everywhere:
```swift
extension Color {
    // Vehicle / Trip status
    static let statusActive    = Color.green
    static let statusIdle      = Color.gray
    static let statusScheduled = Color.blue
    static let statusWarning   = Color.orange
    static let statusDanger    = Color.red
    static let statusCompleted = Color.secondary
}
```
Audit `TripDetailView`, `VehicleDetailView`, `StaffDetailSheet`, `MaintenanceDashboardView`
and replace any hardcoded color literals with these semantic colors.

### 3C: Typography Scale

All views must use system font sizes consistently. Do not mix `Font.system(size:)` custom
sizes with `.headline`, `.subheadline` etc. in the same visual hierarchy:
- Screen title (large): `.font(.title2.weight(.bold))`
- Section header: `.font(.headline)`
- Row title: `.font(.subheadline.weight(.medium))`  
- Row subtitle / caption: `.font(.caption)`
- Monospaced IDs: `.font(.system(.caption, design: .monospaced))`

Scan for `font(.system(size: 28))`, `font(.system(size: 34))` etc. and replace with the
semantic equivalents above. Exception: the orange gradient header in `DriverHomeView` is
branded and intentionally large — keep those.

---

## Part 4 — Specific Page Fixes

### 4A: DashboardHomeView — Fleet Management Section

`fleetManagementSection` uses `NavigationLink` to push Maintenance/Reports/Alerts/Geofences.
But `DashboardHomeView` is already inside a NavigationStack (Dashboard tab). Pushing Alerts
and Geofences from here creates a nested navigation path that conflicts with their modal
presentation from QuickActions. Fix:

- Maintenance → NavigationLink push (correct — it's a list of tasks)
- Reports → `.sheet` (not push — it's a paginated analytics sheet)
- Alerts Inbox → `.sheet` (not push — so it matches the QuickActions path)
- Geofences → `.sheet` (not push)

### 4B: DriverProfileSheet — License Expiry

`DriverProfileSheet` shows `profile.licenseExpiry` but this is a `String` (date stored as
string in DriverProfile). Format it with `DateFormatter` before display:
```swift
Text(formatDate(profile.licenseExpiry) ?? profile.licenseExpiry)
```

### 4C: MaintenanceDashboardView — Duplicate NavigationStack

Verify `MaintenanceDashboardView` (which is the root for maintenance role) does not
wrap itself in a NavigationStack AND also get wrapped by a parent NavigationStack. Each
tab in the maintenance app should have its OWN NavigationStack, or the root view should
be a standalone NavigationStack.

---

## Files to Modify

| File | Change |
|---|---|
| All views with double filters | Remove duplicate filter controls |
| All sheet NavigationStacks | Add consistent background + toolbar colors |
| `Sierra/FleetManager/AdminDashboardView.swift` | Move creation sheet state here, add `onCreation` callback support |
| `Sierra/FleetManager/Views/QuickActionsSheet.swift` | Remove local creation sheet state, add `onCreation` callback |
| `Sierra/FleetManager/Views/DashboardHomeView.swift` | Change Reports/Alerts/Geofences from NavigationLink to .sheet |
| `Sierra/Shared/UI/SierraTheme.swift` (or equivalent) | Add semantic Color extensions |
| All views using hardcoded `.orange` | Migrate to `SierraTheme.Colors.ember` or `Color(.systemOrange)` |

---

## Acceptance Criteria

- [ ] No screen has two visible filter controls for the same dimension
- [ ] All sheet headers have matching background to body (no white header over gray body)
- [ ] QuickActions creation sheets open reliably without race condition / flash
- [ ] Dashboard nav links to Reports/Alerts/Geofences use `.sheet` not push navigation
- [ ] Status colors (active=green, idle=gray, scheduled=blue, danger=red) consistent everywhere
- [ ] All list rows follow the same density and information hierarchy

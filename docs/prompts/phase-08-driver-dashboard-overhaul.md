# Phase 08 — Driver Dashboard: Navigation Bug Fix, Profile Consistency, Trip-Scoped Fuel & Maintenance

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Files to modify:** `DriverHomeView.swift`, `DriverTripsListView.swift`, `DriverTripHistoryView.swift`, `TripDetailDriverView.swift`, `FuelLogView.swift`, `FuelLogViewModel.swift`, `DriverMaintenanceRequestView.swift`
- **New file to create:** `Sierra/Driver/Views/DriverTabView.swift` (if not already present or if the current one is wrong)
- **SRS Reference:** §4.2 — Driver features: trip management, fuel logging, vehicle inspection, emergency alerts, route navigation

---

## Bug 1 — Recursive Trip Navigation (CRITICAL)

### Root Cause
The driver's tab structure uses a `NavigationStack` with `.navigationDestination(for: UUID.self)`. This destination is declared in multiple places — in `DriverTripsListView`, in `DriverTripHistoryView`, AND potentially in the parent `DriverTabView`. SwiftUI issues a warning "A navigationDestination for UUID was declared earlier on the stack" and the behaviour is undefined — tapping a trip row can recursively open the same trip or open wrong views.

### Fix: Single Source of Truth for Trip Navigation

The `.navigationDestination(for: UUID.self)` handler must be declared **exactly once** — in the root `NavigationStack` of the driver's trip tab. All child views (`DriverTripsListView`, `DriverTripHistoryView`) must use `NavigationLink(value: trip.id)` without declaring their own `navigationDestination`.

**Architecture:**

```swift
// In DriverTabView.swift (the tab root), the Trips tab should be:
Tab("Trips", systemImage: "map.fill", value: DriverTab.trips) {
    NavigationStack {
        DriverTripsListView()
            .navigationDestination(for: UUID.self) { tripId in
                TripDetailDriverView(tripId: tripId)
            }
    }
}
```

**Remove** `.navigationDestination(for: UUID.self)` from:
- `DriverTripsListView.swift` (the comment says it was already removed — verify this is actually gone)
- `DriverTripHistoryView.swift` (it has one — REMOVE IT)
- Any other driver views that declare it

**Also remove** the recursive `NavigationLink` pattern in `DriverHomeView` — the "View Rides" button in `upcomingRidesCard` uses `NavigationLink { DriverTripsListView() }` which creates a new NavigationStack pushed on top, causing the recursive loop. Replace:

```swift
// OLD (causes recursion):
NavigationLink {
    DriverTripsListView()
} label: { ... }

// NEW (uses programmatic navigation or tab switch):
Button {
    driverTabSelection = .trips  // switch to trips tab
} label: { ... }
```

If `driverTabSelection` binding isn't available in `DriverHomeView`, pass it as a binding from `DriverTabView`.

---

## Fix 2 — Remove Separate Profile Tab; Add Profile Button Consistent with Admin Side

### Current State
The driver dashboard has a separate "Profile" tab in its tab bar. This is inconsistent with the admin side, where profile is accessible via a button/avatar in the dashboard header.

### Required Change in `DriverTabView.swift`
Remove the Profile tab. The driver tab bar should have:
```
[ Home ]  [ Trips ]  [ History ]
```
3 tabs only. (Or Home + Trips if History is merged into Trips with a filter.)

### Add Profile Button in `DriverHomeView.swift`
In the header section of `DriverHomeView`, add a tappable avatar/initials circle in the top-right that opens `DriverProfileSheet` as a modal:

```swift
// In headerSection, HStack at top:
Button {
    showProfile = true
} label: {
    Circle()
        .fill(Color.white.opacity(0.25))
        .frame(width: 38, height: 38)
        .overlay(
            Text(driverMember?.initials ?? "D")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        )
}
.sheet(isPresented: $showProfile) {
    DriverProfileSheet()
        .environment(AppDataStore.shared)
        .presentationDetents([.large])
}
```

`DriverProfileSheet` should show:
- Name, email, phone, availability status
- License info (from `driverProfile(for:)` in AppDataStore)
- Total trips completed, total distance
- Change Password button → `NavigationLink { ChangePasswordView() }`
- Face ID / Touch ID toggle (same pattern as Phase 05 admin profile)
- Sign Out button

---

## Fix 3 — Fuel Log and Report Issue Must Be Trip-Scoped (Not in Main Home Screen)

### Current State
`DriverHomeView` has two quick action buttons: "Log Fuel" and "Report Issue". These are only enabled (`disabled`) when `currentTrip != nil`. However, they are still in the home screen's quick action row, which is conceptually wrong — they should live **inside the active trip's detail view**, not on the home screen.

### Required Change

**Remove** from `DriverHomeView.swift`:
- The `showFuelLog` state and its sheet
- The `showMaintenanceRequest` state and its sheet
- The two quick action buttons (`quickActionsRow`)

**Add** to `TripDetailDriverView.swift` (active trip state):
In the `actionButtons` for `.active` status, after the Navigate button, add two inline action buttons:

```swift
// Fuel Log action (always available during active trip)
actionButton("Log Fuel", icon: "fuelpump.fill", color: .orange) {
    showFuelLog = true
}

// Report Issue (maintenance request)
actionButton("Report Issue", icon: "wrench.and.screwdriver.fill", color: .red.opacity(0.8)) {
    showMaintenanceRequest = true
}
```

Add the sheets to `TripDetailDriverView`:
```swift
.sheet(isPresented: $showFuelLog) {
    if let vehicleId = vehicle?.id, let driverId = user?.id {
        FuelLogView(vehicleId: vehicleId, driverId: driverId, tripId: trip?.id)
    }
}
.sheet(isPresented: $showMaintenanceRequest) {
    if let vehicleId = vehicle?.id, let driverId = user?.id {
        DriverMaintenanceRequestView(
            vehicleId: vehicleId,
            driverId: driverId,
            tripId: trip?.id
        )
    }
}
```

This way, Fuel Log and Report Issue are always available during an **active trip** from within the trip detail — exactly where they contextually belong (SRS §4.2.7, §4.2.6.2).

---

## Fix 4 — `FuelLogViewModel.submit()` Bypasses AppDataStore (see Phase 01 Bug 3)
This is a duplicate of Phase 01 Bug 3. Ensure it is applied.

---

## Fix 5 — "View All Rides" and Trip History Navigation

`DriverTripHistoryView.swift` currently declares its own `.navigationDestination(for: UUID.self)` which conflicts with the parent NavigationStack. Fix:
- Remove the `.navigationDestination` from `DriverTripHistoryView`
- It must be present only once in the root NavigationStack of the Trips tab (as described in Bug 1 fix)

The "View All Rides" button in `DriverHomeView.upcomingRidesCard` should switch to the Trips tab, not push a new NavigationStack. Use a tab selection binding or a Notification for this.

---

## Constraints
- `@Observable` only, no `@Published`
- No new Supabase calls in this phase (all data from AppDataStore)
- `DriverTabView.swift` should use the native `TabView` with `.tabItem` or iOS 18 `Tab` syntax consistently
- The 3-tab structure (Home, Trips, History) or 2-tab (Home, Trips with embedded history) must not be recursively nested
- Fuel log and maintenance request **must** pass `tripId` when opened from trip detail (they already accept it as an optional param)

## Verification Checklist
- [ ] Tapping a trip row opens `TripDetailDriverView` exactly once — no recursion
- [ ] No duplicate `.navigationDestination(for: UUID.self)` declarations
- [ ] No Profile tab in driver tab bar
- [ ] Profile accessible via header button in `DriverHomeView`
- [ ] `DriverProfileSheet` shows all expected fields + Face ID toggle + Change Password + Sign Out
- [ ] "Log Fuel" and "Report Issue" removed from home screen quick actions
- [ ] Both actions available in active trip detail view
- [ ] Fuel log is saved via `AppDataStore.addFuelLog()` (not direct service call)
- [ ] `FuelLogView` pre-fills `tripId` from the current trip
- [ ] "View All Rides" switches to Trips tab (not pushes new stack)
- [ ] Build clean, zero warnings, zero navigation stack warnings in console

# Fix D — DriverTripHistoryView Navigation Wiring 🟡 MEDIUM

**Audit ID:** H-04 (originally "DriverHistoryView dead code")  
**Priority:** Medium — the feature exists but may not be reachable from the UI

---

## The Problem

`Sierra/Driver/Views/DriverTripHistoryView.swift` exists (3.7KB, confirmed in repo). However during audit the navigation path to it from the driver UI was not confirmed. The original audit issue H-04 flagged the old `DriverHistoryView.swift` as dead code — it was renamed and rewritten, but the nav wiring may not have been completed.

---

## Tasks

### Task 1 — Verify current navigation paths

Read these files and check for any reference to `DriverTripHistoryView`:

1. `Sierra/Driver/Views/DriverTripsListView.swift` — is there a NavigationLink or toolbar button?
2. `Sierra/Shared/Theme/SierraTabBar.swift` — does the driver tab bar include a History tab?
3. Any driver root container (search for `DriverTab` enum definition)

Report what you find.

---

### Task 2 — Wire it in (if not already done)

**Option A (preferred if DriverTripsListView is the trips list):**  
Add a "History" segmented control or toolbar button in `DriverTripsListView` that navigates to `DriverTripHistoryView`:

```swift
// In DriverTripsListView toolbar
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
            DriverTripHistoryView()
                .environment(AppDataStore.shared)
        } label: {
            Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
        }
    }
}
```

**Option B (if there's a DriverTab enum):**  
Add `.history` case to the driver tab bar:

```swift
// In the DriverTab enum
case history = "History"

// In SierraTabBar / DriverTabView — add the tab:
TabView(selection: $tabSelection) {
    // ... existing tabs ...
    DriverTripHistoryView()
        .tabItem { Label("History", systemImage: "clock") }
        .tag(DriverTab.history)
}
```

Follow whichever pattern is consistent with how the other driver tabs are structured. Do NOT change the existing tab structure if it breaks anything — a toolbar button in `DriverTripsListView` is the lower-risk option.

---

### Task 3 — Verify `DriverTripHistoryView` compiles cleanly

Read `DriverTripHistoryView.swift` and confirm:
- It `@Environment(AppDataStore.self)` is injected (or passed as a parameter)
- Any filtering it does on trips matches the driver's ID correctly
- It handles the empty state (no completed trips)

Fix any issues found.

---

## Acceptance Criteria

- Driver can navigate to their trip history from somewhere in the app without knowing a hidden gesture or deep link
- `DriverTripHistoryView` shows completed trips for the current driver (filtered by `driverId`)
- Empty state is shown when there are no completed trips
- The navigation path is consistent with the existing driver UI patterns

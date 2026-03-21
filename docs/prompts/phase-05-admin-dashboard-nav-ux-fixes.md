# Phase 05 — Admin Dashboard: Navigation, UX Fixes, Profile Modal, Search Bar Cleanup

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Files to modify:** `AdminDashboardView.swift`, `DashboardHomeView.swift`, `VehicleListView.swift`, `TripsListView.swift`, `StaffTabView.swift`
- **CRITICAL CONSTRAINT:** The `AdminDashboardView` 5-tab structure (Dashboard, Vehicles, Staff, Trips, Search/Add) must stay **exactly as-is**. No new tabs. No removed tabs. Only internal changes.

---

## Fix 1 — Remove the Ellipsis (•••) Button from Dashboard

**File:** `Sierra/FleetManager/Views/DashboardHomeView.swift`

The `DashboardHomeView` has a toolbar item with an ellipsis menu (`Image(systemName: "ellipsis.circle")` or similar). This button doesn't do anything meaningful — it needs to be removed entirely.

Search for `.topBarTrailing` or `ellipsis` in `DashboardHomeView.swift` and remove the `ToolbarItem` that contains it.

**Instead**, the top-right of the Dashboard toolbar should show the **notification bell** (already implemented) and nothing else.

---

## Fix 2 — Profile Modal: Add Face ID Toggle + Proper Wiring

**File:** `Sierra/FleetManager/Views/AdminProfileView.swift`

The profile view that opens when the fleet manager taps their avatar/name in `DashboardHomeView` currently shows basic account info. It needs a **Face ID / Biometrics toggle**.

### Implementation:

```swift
import LocalAuthentication

// State
@State private var isBiometricEnabled: Bool = BiometricAuthManager.isEnabled

// In the profile form:
Section("Security") {
    Toggle(isOn: $isBiometricEnabled) {
        HStack(spacing: 12) {
            Image(systemName: LAContext().biometryType == .faceID ? "faceid" : "touchid")
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(LAContext().biometryType == .faceID ? "Face ID" : "Touch ID")
                    .font(.body)
                Text("Sign in without typing your password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .onChange(of: isBiometricEnabled) { _, enabled in
        if enabled {
            Task { await requestBiometricEnrollment() }
        } else {
            BiometricAuthManager.disable()
        }
    }
}
```

`BiometricAuthManager` — check if it exists in `Sierra/Auth/`. If it exists, use it. If not, create a minimal version:

```swift
// Sierra/Auth/BiometricAuthManager.swift
import LocalAuthentication

enum BiometricAuthManager {
    private static let key = "sierra.biometric.enabled"
    
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }
    
    static func enable() {
        UserDefaults.standard.set(true, forKey: key)
    }
    
    static func disable() {
        UserDefaults.standard.set(false, forKey: key)
        // Optionally invalidate any stored biometric context
    }
    
    /// Returns true if biometric auth succeeds, false if cancelled or unavailable
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) ?? false
    }
}
```

The `AuthManager` should check `BiometricAuthManager.isEnabled` on the sign-in flow (already partially wired via `BiometricEnrollmentSheet`). Verify that `AuthManager.swift` checks this flag and calls `BiometricAuthManager.authenticate()` when the flag is true.

---

## Fix 3 — Remove Redundant Search Bars from Vehicles, Staff, and Trips Tabs

**Context:** `AdminDashboardView` already has a dedicated Search tab (tab index 4) that provides contextual search for whatever tab the user was last on. Having an additional `.searchable` modifier inside each of the content tabs creates redundant search UI and wastes space.

**Files to change:**
- `VehicleListView.swift`: Remove the `.searchable(text: $searchText, ...)` modifier from the `NavigationStack` inside `VehicleListView`. If `VehicleListView` has an internal `@State private var searchText`, remove it too (or keep for Tab 4 compatibility — see below).
- `StaffTabView.swift`: Remove the `.searchable` modifier from `StaffTabView`'s `NavigationStack`. The search in Tab 4 handles this.
- `TripsListView.swift`: Remove the `.searchable` modifier.

**Tab 4 compatibility:** `AdminDashboardView`'s Tab 4 already passes the search text to a clone of the active view via `.searchable(text: $searchText)`. This is the correct approach. The individual views should accept an optional `searchText` binding or just use the environment's search text from Tab 4.

**Important:** `DriverTripsListView.swift` (driver side) keeps its search bar — only the **admin-side** views are affected here.

---

## Fix 4 — Add Plus (+) Create Button to Staff, Vehicles, and Trips Tabs ONLY

Add a `ToolbarItem(placement: .topBarTrailing)` with a `+` button to these **three tabs only**:

### Vehicles Tab (in `VehicleListView.swift`)
```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showAddVehicle = true
    } label: {
        Image(systemName: "plus")
            .fontWeight(.semibold)
    }
}
// Sheet:
.sheet(isPresented: $showAddVehicle) {
    AddVehicleView()
        .presentationDetents([.large])
}
```

### Staff Tab (in `StaffTabView.swift`)
```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showCreateStaff = true
    } label: {
        Image(systemName: "person.badge.plus")
    }
}
// Sheet:
.sheet(isPresented: $showCreateStaff) {
    CreateStaffView()
        .presentationDetents([.large])
}
```
(Only show when `selectedSegment != .applications` — during applications review, the + button is confusing)

### Trips Tab (in `TripsListView.swift`)
```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showCreateTrip = true
    } label: {
        Image(systemName: "plus")
            .fontWeight(.semibold)
    }
}
// Sheet:
.sheet(isPresented: $showCreateTrip) {
    CreateTripView()
        .presentationDetents([.large])
}
```

**DO NOT** add + buttons to: Dashboard tab, any sub-views, or any maintenance/reports views.

---

## Fix 5 — Dashboard Tab: Wire Maintenance, Reports, Geofences, Alerts

Since these features can't be in new tabs, they must be accessible from the Dashboard tab's `DashboardHomeView`. Add navigation rows/cards to `DashboardHomeView` that push to these views:

Add a "Fleet Management" section in `DashboardHomeView` with `NavigationLink` cards for:
- Maintenance Requests → `NavigationLink { MaintenanceRequestsView() } label: { ... }`
- Reports & Analytics → `NavigationLink { ReportsView() } label: { ... }`  
- Geofences → `NavigationLink { GeofenceListView() } label: { ... }`
- Alerts Inbox → `NavigationLink { AlertsInboxView(vm: alertsVM) } label: { ... }`

For `alertsVM`, store it at the `AdminDashboardView` level and pass it in (it's already declared there).

Each card should use a consistent style:
- Icon (tinted `.orange`), title, subtitle (showing count of pending items), chevron
- Background `Color(.secondarySystemGroupedBackground)`, corner radius 16

---

## Constraints
- No new tabs in `AdminDashboardView`
- `@Observable` only
- `LAContext().biometryType` check for Face ID vs Touch ID label
- `BiometricAuthManager` must use `UserDefaults` for persistence (not Keychain — keep it simple)
- Zero new Supabase calls in this phase

## Verification Checklist
- [ ] Ellipsis button removed from Dashboard toolbar
- [ ] Profile modal shows Face ID/Touch ID toggle that persists across app launches
- [ ] Toggling Face ID off disables biometric login on next launch
- [ ] No search bar inside Vehicles, Staff, or Trips tabs (search only in Tab 4)
- [ ] Plus button appears in top-right of Staff, Vehicles, and Trips tabs only
- [ ] Plus buttons open correct creation sheets
- [ ] Maintenance/Reports/Geofences/Alerts reachable from Dashboard tab
- [ ] 5-tab structure unchanged

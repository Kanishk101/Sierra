# Phase 05 — Admin Dashboard: Fold Missing Features In + UX Fixes

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Primary file:** `Sierra/FleetManager/AdminDashboardView.swift`
- **Supporting files:** `DashboardHomeView.swift`, `VehicleListView.swift`, `TripsListView.swift`, `StaffTabView.swift`, `AdminProfileView.swift`
- **SRS Reference:** §4.1 — All fleet manager features accessible from the dashboard

---

## The Situation

`AdminDashboardView` is the correct, final root for the fleet manager. It has exactly 5 tabs:

| Tab | System Image | Content |
|---|---|---|
| 0 | `square.grid.2x2.fill` | `DashboardHomeView()` |
| 1 | `car.fill` | `VehicleListView()` |
| 2 | `person.2.fill` | `StaffTabView()` + pending badge |
| 3 | `arrow.triangle.swap` | `TripsAndMapContainerView(mapViewModel:)` |
| 4 | `magnifyingglass` / `plus` | Contextual search + `QuickActionsSheet` |

**This structure is locked. Do not change it in any way whatsoever.**

Several fleet manager features exist as fully-implemented standalone views but are not reachable from `AdminDashboardView`:
- `MaintenanceRequestsView` — task approval, spare parts, maintenance history
- `ReportsView` — fleet analytics and CSV export
- `GeofenceListView` — geofence management
- `AlertsInboxView` — emergency and system alerts

All of these need to be wired into the existing 5-tab structure. They surface via:
1. **`DashboardHomeView`** — navigation cards/rows that push onto the Dashboard tab's `NavigationStack`
2. **`QuickActionsSheet`** — action tiles that open creation/management flows (Phase 06)

`FleetManagerTabView.swift` (9-tab dead code) was already deleted in Phase 01. If it still exists when you start this phase, delete it now and verify no references remain.

---

## Fix 1 — Remove the Ellipsis (•••) Button from DashboardHomeView

**File:** `Sierra/FleetManager/Views/DashboardHomeView.swift`

Search for any `ToolbarItem` that renders an `ellipsis.circle` or `ellipsis` icon. Remove it entirely. This button has no action wired to it and is confusing noise.

After removal, the Dashboard toolbar should contain only:
- Left/leading: navigation title
- Right/trailing: notification bell button (already implemented — keep it)

---

## Fix 2 — Profile Modal: Face ID Toggle + Full Wiring

**File:** `Sierra/FleetManager/Views/AdminProfileView.swift`

The profile view currently shows basic account info. Add a Face ID / Touch ID toggle that persists across app launches.

### Step 1 — Create `BiometricAuthManager` if it doesn't already exist

Check `Sierra/Auth/` for an existing biometric manager. If absent, create `Sierra/Auth/BiometricAuthManager.swift`:

```swift
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
    }

    /// Performs biometric authentication. Returns true on success.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )) ?? false
    }
}
```

### Step 2 — Add toggle to `AdminProfileView`

```swift
import LocalAuthentication

@State private var isBiometricEnabled: Bool = BiometricAuthManager.isEnabled

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
            Task {
                let ok = await BiometricAuthManager.authenticate(reason: "Enable biometric sign-in for Sierra")
                if ok {
                    BiometricAuthManager.enable()
                } else {
                    // user cancelled or failed — revert the toggle
                    isBiometricEnabled = false
                }
            }
        } else {
            BiometricAuthManager.disable()
        }
    }
}
```

### Step 3 — Wire into `AuthManager.swift`

In `AuthManager.signInWithBiometrics()` (or wherever biometric login is triggered), check `BiometricAuthManager.isEnabled` before attempting. The existing `BiometricEnrollmentSheet` should also call `BiometricAuthManager.enable()` on successful enrolment.

---

## Fix 3 — Remove Redundant Search Bars from Vehicles, Staff, and Trips Tabs

`AdminDashboardView` Tab 4 already provides contextual search for whichever tab the user was last on. Having a `.searchable` modifier inside each of the three content tabs (Vehicles, Staff, Trips) creates duplicate search bars that appear when the user is on those tabs normally — this is wrong.

**Files to change:**

- `VehicleListView.swift`: Remove the `.searchable(text: $searchText, ...)` modifier. The `searchText` state variable can remain (Tab 4 uses it) but the modifier should only be on the Tab 4 clone of the view.
- `StaffTabView.swift`: Remove the `.searchable` modifier from the root `NavigationStack`.
- `TripsListView.swift`: Remove the `.searchable` modifier.

**Important:** Only admin-side views are affected. Driver-side `DriverTripsListView.swift` keeps its search bar.

The correct flow: user is on Vehicles tab → taps the Search tab (Tab 4) → the Tab 4 presents a searchable clone of `VehicleListView`. Search never appears while the user is browsing normally.

---

## Fix 4 — Plus (+) Create Buttons on Staff, Vehicles, and Trips Tabs ONLY

Add a `ToolbarItem(placement: .topBarTrailing)` with a `+` icon to exactly three tabs. Not the Dashboard tab. Not the Search tab. Only these three:

### Vehicles Tab — inside `VehicleListView.swift`

```swift
@State private var showAddVehicle = false

// In toolbar:
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

### Staff Tab — inside `StaffTabView.swift`

```swift
@State private var showCreateStaff = false

// In toolbar (only when not on the Applications segment):
ToolbarItem(placement: .topBarTrailing) {
    if selectedSegment != .applications {
        Button {
            showCreateStaff = true
        } label: {
            Image(systemName: "person.badge.plus")
        }
    }
}

// Sheet:
.sheet(isPresented: $showCreateStaff) {
    CreateStaffView()
        .presentationDetents([.large])
}
```

### Trips Tab — inside `TripsListView.swift`

```swift
@State private var showCreateTrip = false

// In toolbar:
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

---

## Fix 5 — Wire Missing Features into DashboardHomeView

`MaintenanceRequestsView`, `ReportsView`, `GeofenceListView`, and `AlertsInboxView` are fully implemented but unreachable. They must be accessible from the Dashboard tab (Tab 0) via `NavigationLink` cards in `DashboardHomeView`.

`DashboardHomeView` already has a `NavigationStack` wrapping it (Tab 0 in `AdminDashboardView`). That means `NavigationLink` will work correctly here — tapping a card pushes the destination view onto the stack within Tab 0.

Add a **"Fleet Management" section** to `DashboardHomeView`'s `ScrollView`, below the existing stats/priority section:

```swift
// In DashboardHomeView, add this section to the scroll content:

private var fleetManagementSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("FLEET MANAGEMENT")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .kerning(1)
            .padding(.horizontal, 2)

        // Maintenance
        NavigationLink {
            MaintenanceRequestsView()
                .environment(AppDataStore.shared)
        } label: {
            managementCard(
                icon: "wrench.and.screwdriver.fill",
                title: "Maintenance",
                subtitle: "\(store.maintenanceTasks.filter { $0.status == .pending }.count) pending tasks",
                color: .orange
            )
        }

        // Reports
        NavigationLink {
            ReportsView()
                .environment(AppDataStore.shared)
        } label: {
            managementCard(
                icon: "chart.bar.fill",
                title: "Reports & Analytics",
                subtitle: "Fleet performance and exports",
                color: .blue
            )
        }

        // Alerts
        NavigationLink {
            AlertsInboxView(vm: alertsVM)
                .environment(AppDataStore.shared)
        } label: {
            managementCard(
                icon: "bell.badge.fill",
                title: "Alerts Inbox",
                subtitle: "\(store.activeEmergencyAlerts().count) active alerts",
                color: .red
            )
        }

        // Geofences
        NavigationLink {
            GeofenceListView()
                .environment(AppDataStore.shared)
        } label: {
            managementCard(
                icon: "mappin.and.ellipse",
                title: "Geofences",
                subtitle: "\(store.geofences.filter { $0.isActive }.count) active zones",
                color: .teal
            )
        }
    }
}

private func managementCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
    HStack(spacing: 14) {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
}
```

`alertsVM` — `DashboardHomeView` needs a reference to the `AlertsViewModel`. It is already stored at the `AdminDashboardView` level. Pass it in either as an `init` parameter or store a new instance at the `DashboardHomeView` level:
```swift
@State private var alertsVM = AlertsViewModel()
```

Call `fleetManagementSection` inside the existing `ScrollView` `VStack` in `DashboardHomeView`, after the priority alerts section and before the spacer.

---

## Constraints (Absolute)
- `AdminDashboardView` tab count stays at exactly 5. Tab order stays identical. Tab icons/labels unchanged.
- `FleetManagerTabView` must already be deleted (Phase 01). If it isn't, delete it now.
- No "More" tab. No overflow menu. No extra tab bar items. No rerouting.
- `@Observable` only — no `@Published`, no `@StateObject`, no `@ObservedObject`
- All data in `fleetManagementSection` comes from `AppDataStore` in-memory — no new Supabase calls
- `BiometricAuthManager` uses `UserDefaults` only — no Keychain

## Verification Checklist
- [ ] `AdminDashboardView` still has exactly 5 tabs in original order
- [ ] `FleetManagerTabView.swift` does not exist anywhere in the project
- [ ] Ellipsis button is gone from Dashboard toolbar; notification bell remains
- [ ] Profile modal has Face ID / Touch ID toggle that persists after app restart
- [ ] Disabling biometric in profile modal prevents biometric login on next launch
- [ ] No `.searchable` modifier on Vehicles, Staff, or Trips tabs directly
- [ ] `+` button appears top-right in Vehicles, Staff, and Trips tabs only
- [ ] `+` buttons open correct creation sheets
- [ ] MaintenanceRequestsView, ReportsView, AlertsInboxView, GeofenceListView all push correctly from Dashboard tab cards
- [ ] Cards show live counts (pending tasks, active alerts, active zones)
- [ ] Build clean — zero warnings, zero errors, zero console navigation warnings

# Phase 06 — QuickActionsSheet: Complete Rewrite and Proper Wiring

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **File to modify:** `Sierra/FleetManager/Views/QuickActionsSheet.swift`
- **SRS Reference:** §4.1.1–4.1.6 — Administrator creates trips, staff, vehicles, maintenance requests, geofences; views alerts

---

## Current State (What Is Wrong)

`QuickActionsSheet.swift` has 6 action tiles. The issues are:
1. **"View Alerts"** opens `AlertsInboxView` inside a sheet from inside a sheet — double-sheet stacking. This is broken UX. Alerts should navigate, not stack modally.
2. **"Create Maintenance Request"** opens `MaintenanceRequestsView` — the **list** view, not a creation sheet. The correct view is a dedicated maintenance task creation form (not yet fully wired to a creation sheet). The placeholder must be fixed.
3. The sheet **does not dismiss itself** before opening sub-sheets, causing animation jitter on some iOS versions.
4. There is no **"View Reports"** action even though it's a major fleet manager need.
5. There is no **"View Geofences"** action.
6. The sheet grid is fixed at 2 columns with 6 items. Needs to scale cleanly.

---

## Required Changes

### Action Set Redesign

Replace the 6-tile grid with an **8-tile grid** (2×4) covering:

```
[ Create Trip     ] [ Add Vehicle      ]
[ Add Staff       ] [ Maint. Request   ]
[ View Reports    ] [ View Alerts      ]
[ View Geofences  ] [ Notifications    ]
```

### "Create Maintenance Request" — Fix
The correct action is to open `MaintenanceApprovalDetailView` with a NEW task context, or better, a dedicated `CreateMaintenanceTaskSheet` view. For now, open `MaintenanceRequestsView` pushed in a full `NavigationStack` sheet, but navigate directly to a form to create a new task — not just list existing ones.

If `CreateMaintenanceTaskSheet` doesn't exist, create a simple wrapper that shows `MaintenanceRequestsView` in a `.large` detent with a `NavigationStack` and immediately presents a creation affordance.

### "View Alerts" — Fix
Instead of presenting another sheet, store a `@Binding var selectedTab: Int` in the parent `AdminDashboardView` and have the QuickActionsSheet call a closure that switches to the Alerts view:

```swift
// QuickActionsSheet initialiser:
init(onNavigate: @escaping (QuickActionDestination) -> Void)

// In AdminDashboardView:
QuickActionsSheet { destination in
    switch destination {
    case .alerts:   selectedTab = ... // appropriate tab or push NavigationLink
    case .reports:  showReports = true
    case .geofences: showGeofences = true
    default: break
    }
}
```

Alternatively (simpler): The QuickActionsSheet can just set a binding to the destination and let `AdminDashboardView` handle navigation via its own sheet/nav stack. The key point is: **no modal-over-modal** for Alerts, Reports, or Geofences.

### "View Reports" — New Action
```swift
case "reports":
    dismiss()
    // parent navigates to ReportsView
```

### "View Geofences" — New Action
```swift
case "geofences":
    dismiss()
    // parent navigates to GeofenceListView
```

### Dismiss-First Pattern
Before presenting any sheet from within `QuickActionsSheet`, call `dismiss()` first with a short delay:
```swift
dismiss()
Task {
    try? await Task.sleep(for: .milliseconds(300))
    showCreateTrip = true
}
```
This prevents the double-sheet animation issue.

### Sheet for Maintenance Request — Proper Create Flow
`MaintenanceRequestsView` is a list+approval view. When opened from QuickActionsSheet, it should directly present a creation affordance (e.g., a toolbar + button that opens a create task form). Since `MaintenanceApprovalDetailView` is the approval flow, and there is no dedicated `CreateMaintenanceTaskView`, add a minimal inline create task form as a sheet presented from `MaintenanceRequestsView`'s toolbar `+` button. This form should collect: vehicle (picker from `store.vehicles`), title, description, priority, due date, and assigned personnel (picker from `store.staff` filtered to maintenancePersonnel). On submit, call `store.addMaintenanceTask(_:)`. **Do not re-implement this form from scratch** — the existing `MaintenanceApprovalDetailView` may have field patterns to mirror.

---

## Constraints
- `@Observable` only
- No `@Published`
- No modal-over-modal for non-creation actions (Alerts, Reports, Geofences)
- The 8-tile grid must use `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())])`
- Icon, label, and color scheme must follow the existing style from `QuickActionsSheet`
- `dismiss()` must be called before presenting sub-sheets

## Verification Checklist
- [ ] 8 action tiles rendered in 2×4 grid
- [ ] Create Trip → opens `CreateTripView` as a sheet (after dismiss)
- [ ] Add Vehicle → opens `AddVehicleView` as a sheet (after dismiss)
- [ ] Add Staff → opens `CreateStaffView` as a sheet (after dismiss)
- [ ] Maintenance Request → opens `MaintenanceRequestsView` with create affordance
- [ ] View Reports → dismisses QuickActions, navigates to ReportsView
- [ ] View Alerts → dismisses QuickActions, navigates to AlertsInboxView (no double-sheet)
- [ ] View Geofences → dismisses QuickActions, navigates to GeofenceListView
- [ ] Notifications → opens `NotificationCentreView` as a sheet
- [ ] No visual jitter / double-sheet stacking
- [ ] Build clean, zero warnings

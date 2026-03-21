# Phase 02 — Admin Staff Tab: 3-Segment Redesign + Modal Detail Sheets

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Files to modify:** `Sierra/FleetManager/Views/StaffTabView.swift`, `Sierra/FleetManager/Views/StaffListView.swift`
- **Do NOT modify:** `StaffReviewSheet.swift`, `CreateStaffView.swift`, `AppDataStore.swift`
- **SRS Reference:** §4.1.1 — Administrator shall manage staff accounts; view drivers, maintenance personnel, and pending applications

---

## Current State (What Is Wrong)

`StaffTabView.swift` currently has **two nested segmented controls** stacked on top of each other:
1. Outer: "Staff" / "Applications" (StaffMode picker)
2. Inner (inside StaffDirectoryView): "All" / "Drivers" / "Maintenance" (RoleFilter picker)

This is non-standard iOS UX — two segmented controls stacked is confusing and wastes vertical space. Additionally, fleet managers (admins) are shown in the "All" segment, which Kanishk does not want.

`StaffListView.swift` is an older, separate view with its own "Drivers" / "Maintenance" segmented control that is used by a different navigation path but contains the same duplication problem.

---

## Required Changes

### 1. `StaffTabView.swift` — Collapse to a Single 3-Segment Control

Replace the current two-level picker architecture with a **single `Picker` with 3 segments** at the top level:

```
[ Drivers ]  [ Maintenance ]  [ Applications ]
```

**Enum to define:**
```swift
enum StaffSegment: String, CaseIterable {
    case drivers      = "Drivers"
    case maintenance  = "Maintenance"
    case applications = "Applications"
}
```

**Rules:**
- `Drivers` segment: Show `store.staff` filtered to `role == .driver && status == .active && isApproved == true`. Sort by `displayName` ascending.
- `Maintenance` segment: Show `store.staff` filtered to `role == .maintenancePersonnel && status == .active && isApproved == true`. Sort by `displayName` ascending.
- `Applications` segment: Show `store.staffApplications` using the existing `ApplicationsListView` inline component (already implemented inside `StaffTabView.swift`). Show the pending count badge on the segment label if there are pending applications: `Text("Applications (\(pendingCount))")` or use `.badge()` modifier.
- **Fleet managers (role == .fleetManager) are NEVER shown in any segment.** No exceptions.
- Suspended staff: Show them within their respective Drivers/Maintenance segment with a visual "Suspended" indicator (red badge on cell) but only if `isApproved == true`. Pending-approval staff are NOT shown in Drivers or Maintenance — they appear only in Applications.

**Search:** The existing `.searchable` modifier on the `NavigationStack` should filter across the currently active segment. For Drivers and Maintenance, filter by `displayName` and `email`. For Applications, filter by applicant name/email.

**Plus (+) button:** Add a `ToolbarItem(placement: .topBarTrailing)` with a `+` button that opens `CreateStaffView()` as a sheet. This is already covered in Phase 05 but include it here since this phase touches the file.

### 2. Staff Row Cells — Tap Opens Modal Detail Sheet

Currently in `StaffTabView.swift`, the `StaffDirectoryView` section uses a plain `VStack` layout with swipe actions. Tapping a row does nothing (no navigation or sheet). This must be fixed.

**Required behaviour:** Tapping any staff row in Drivers or Maintenance segment opens `StaffDetailSheet` (already implemented in `StaffListView.swift`) as a modal sheet.

Implementation:
```swift
@State private var selectedStaffMember: StaffMember? = nil

// In each row:
.onTapGesture {
    selectedStaffMember = member
}

// On the NavigationStack:
.sheet(item: $selectedStaffMember) { member in
    StaffDetailSheet(member: member)
        .environment(AppDataStore.shared)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
}
```

`StaffDetailSheet` is defined at the bottom of `StaffListView.swift`. Move it to a new file `Sierra/FleetManager/Views/StaffDetailSheet.swift` so both `StaffTabView` and `StaffListView` can import it without duplication. The `StaffDetailSheet` struct should remain public.

### 3. Applications Segment — Tap Opens Review Sheet

In the Applications segment, tapping an application card must open `StaffReviewSheet` (already implemented). The existing `selectedApplication: StaffApplication?` binding pattern already works — preserve it.

### 4. `StaffListView.swift` — Align with New Architecture

`StaffListView` is used in `AdminDashboardView` tab 2 as the Staff tab destination. Since `StaffTabView` now subsumes all its functionality:
- Remove `StaffListView`'s own nested segmented control
- `AdminDashboardView` tab 2 should use `StaffTabView()` directly (it may already do this — verify)
- `StaffListView.swift` can be kept as a lightweight wrapper or deleted if fully redundant — check all references first using `grep -r StaffListView Sierra/`

---

## Constraints
- `@Observable` only. No `@Published`, no `@StateObject`, no `@ObservedObject`.
- Do NOT modify `StaffReviewSheet.swift` — it is already correct.
- Do NOT modify `CreateStaffView.swift`.
- Do NOT modify `AppDataStore.swift` for this phase.
- Swipe actions for Suspend/Reactivate must be preserved as-is from the existing implementation.
- The `filterByStatus`, `filterByRole` logic must remain purely in-memory (no new Supabase calls).
- Zero new `@Published` properties. Zero new `ObservableObject` conformances.

## Verification Checklist
- [ ] Single segmented control at top: Drivers | Maintenance | Applications
- [ ] Fleet managers never appear anywhere
- [ ] Pending-approval staff appear ONLY in Applications, not in Drivers/Maintenance
- [ ] Suspended staff appear in their role segment with visual indicator
- [ ] Tapping a driver/maintenance row opens `StaffDetailSheet` as a modal
- [ ] Tapping an application row opens `StaffReviewSheet`
- [ ] Search bar filters the active segment
- [ ] Swipe to Suspend/Reactivate still works
- [ ] No duplicate `navigationDestination` declarations
- [ ] Build clean, zero warnings

# Phase 03 — Replace All Filter Chips with Native iOS Filter Menus

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Files to modify:** `DriverTripsListView.swift`, `MaintenanceDashboardView.swift`, any other view with horizontal scroll filter chip bars
- **SRS Reference:** §3.3 Usability — The application will have a user-friendly interface that is easy to navigate and understand. Apple HIG specifies that list filters should use the native `.toolbar` filter button pattern on iOS 16+.

---

## Problem

Several views use a horizontal `ScrollView` with custom "chip" buttons for filtering. While visually reasonable, this pattern:
1. Takes up permanent vertical screen real estate even when no filter is active
2. Is inconsistent with Apple HIG's recommended filter approach for list views
3. Conflicts with the search bar placement on some screens
4. Cannot scale when there are many filter dimensions (e.g., status + priority + date range)

The standard iOS pattern is a **filter button in the navigation toolbar** that opens a `Menu` or popover showing all available filters.

---

## Standard Implementation Pattern to Use

For every view that currently has filter chips, replace with this pattern:

```swift
// State
@State private var selectedStatus: TripStatus? = nil
@State private var selectedPriority: TripPriority? = nil

// In toolbar:
ToolbarItem(placement: .topBarTrailing) {
    Menu {
        // Status filter
        Section("Status") {
            Button {
                selectedStatus = nil
            } label: {
                Label("All Statuses", systemImage: selectedStatus == nil ? "checkmark" : "")
            }
            ForEach(TripStatus.allCases, id: \.self) { status in
                Button {
                    selectedStatus = status
                } label: {
                    Label(status.rawValue, systemImage: selectedStatus == status ? "checkmark" : "")
                }
            }
        }
        
        // Priority filter (if applicable)
        Section("Priority") {
            Button { selectedPriority = nil } label: {
                Label("All Priorities", systemImage: selectedPriority == nil ? "checkmark" : "")
            }
            ForEach(TripPriority.allCases, id: \.self) { p in
                Button { selectedPriority = p } label: {
                    Label(p.rawValue, systemImage: selectedPriority == p ? "checkmark" : "")
                }
            }
        }
        
        // Clear all
        if selectedStatus != nil || selectedPriority != nil {
            Divider()
            Button(role: .destructive) {
                selectedStatus = nil
                selectedPriority = nil
            } label: {
                Label("Clear Filters", systemImage: "xmark.circle")
            }
        }
    } label: {
        // Show a filled/highlighted filter icon when any filter is active
        Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isFilterActive ? .orange : .primary)
    }
}

// Computed
private var isFilterActive: Bool {
    selectedStatus != nil || selectedPriority != nil
}
```

---

## Files to Update

### `Sierra/Driver/Views/DriverTripsListView.swift`
- **Remove:** The `filterChips` computed property and its call site
- **Remove:** The horizontal `ScrollView` containing the chip buttons
- **Add:** Toolbar filter Menu with `TripStatus` cases (All, Scheduled, Active, Completed, Cancelled)
- **Keep:** The existing `selectedStatus: TripStatus?` state variable — just change how it's set
- **Note:** The search bar (`.searchable`) must stay — it was already correctly placed

### `Sierra/Maintenance/Views/MaintenanceDashboardView.swift` — Tasks Tab
- **Remove:** The `filterBar` property (the segmented picker at the top of the tasks tab)
- **Remove:** The `vehicleChips` property (horizontal vehicle filter chips)
- **Add:** A single toolbar filter Menu that combines:
  - Task status filter: Pending, Assigned, In Progress, Completed, Cancelled, All
  - Vehicle filter: All Vehicles, then a list of vehicle names from `store.vehicles` filtered to those with tasks assigned to this user
- Keep the task count badge in the toolbar as-is

### `Sierra/Maintenance/Views/MaintenanceDashboardView.swift` — Work Orders Tab  
- The Work Orders tab currently uses `WorkOrderStatus.allCases` section headers — this is acceptable (it's grouping not filtering). No chip bar exists here. No change needed.

### Other Views (Audit First)
Grep for `filterChips`, `chipButton`, `ScrollView(.horizontal` to find any other chip-style filter implementations:
```
Sierra/FleetManager/Views/MaintenanceRequestsView.swift
Sierra/FleetManager/Views/AnalyticsDashboardView.swift  
```
- `MaintenanceRequestsView`: has segmented pickers for task filter and spare parts filter. These are small, clean, and native-feeling (`Picker` with `.segmented` style). Acceptable to keep; do NOT replace these with Menu as they have only 3-4 options and are tightly integrated.
- `AnalyticsDashboardView`: Uses sort buttons for driver table — these are toggle buttons, not filters. Keep as-is.

---

## Constraints
- The filter menu must open a `Menu` (not a sheet) — this matches iOS HIG for list filters
- When a filter is active, the toolbar icon must visually indicate it (filled variant / orange tint)
- All filtering must remain purely in-memory — no new Supabase calls on filter change
- `@Observable` only, no `@Published`
- No new files required — all changes are inline within existing view files
- Preserve all existing animation modifiers (`.animation(.easeInOut, value: selectedStatus)`)

## Verification Checklist
- [ ] No horizontal chip scroll views remain in DriverTripsListView or MaintenanceDashboardView tasks tab
- [ ] Filter icon in toolbar changes appearance (filled/orange) when any filter is active
- [ ] Selecting a filter instantly updates the list
- [ ] "Clear Filters" option appears only when a filter is active
- [ ] Menu closes automatically after selection (standard SwiftUI Menu behaviour)
- [ ] Build clean, zero warnings

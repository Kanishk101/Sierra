# Phase: Maintenance Work Orders Tab

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main

## Problem
In `MaintenanceDashboardView.swift` the Work Orders tab (tab index 1) currently shows
a `comingSoonTab` placeholder. The service layer is complete:
- `WorkOrderService.swift` — full CRUD
- `SparePartsRequestService.swift` — submit / approve / reject / fulfill
- `MaintenanceTaskDetailViewModel.swift` — 6.5KB, includes work order logic
- `SparePartsRequestSheet.swift` — 5.9KB, complete UI
- `AppDataStore.workOrders` — populated via `loadMaintenanceData`
- `AppDataStore.sparePartsRequests` — now populated via `loadMaintenanceData`

## Scope
Replace the Work Orders `comingSoonTab` in `MaintenanceDashboardView.swift` with a real tab
that lists the maintenance personnel's assigned work orders.

### Work Orders List View (inline in the tab, no new file needed)
- Show `store.workOrders` filtered to `assignedToId == currentUserId`.
- Group by status: Open / In Progress / On Hold / Completed / Closed.
- Each row: vehicle name + plate, task title, status badge, due date.
- Tap row navigates to `MaintenanceTaskDetailView(task:)` for the parent task.
- Pull-to-refresh calls `store.loadMaintenanceData(staffId: currentUserId)`.
- Empty state when no work orders assigned.

### Spare Parts
- Inside the work order detail (already in `MaintenanceTaskDetailView`), the existing
  `SparePartsRequestSheet` is already wired. No changes needed there.

## Constraints
- Only modify `MaintenanceDashboardView.swift`.
- Do NOT change any appearance, colour scheme, or font sizes.
- Do NOT add new files — use inline views inside the tab.
- Do NOT touch the Tasks tab or Profile tab.
- The view must compile without using any @Published.

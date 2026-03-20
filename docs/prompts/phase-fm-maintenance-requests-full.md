# Phase: Fleet Manager Maintenance Requests — Full Implementation

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main  |  Jira: FMS1-13, FMS1-16, FMS1-17

## Current State
`MaintenanceRequestsView.swift` (5.2KB) and `MaintenanceApprovalDetailView.swift` (13.3KB)
exist. The approval detail view handles approve/reject of individual tasks.

`MaintenanceApprovalDetailView` is wired to approve/reject `MaintenanceTask` records.
However, the newer `SparePartsRequest` approval workflow is not surfaced to the admin:
- `sparePartsRequests` is now loaded in `loadAll` (pending requests show in AppDataStore).
- `AppDataStore.approveSparePartsRequest` / `rejectSparePartsRequest` are implemented.
- No admin UI exists to see and action pending spare parts requests.

## Scope

### Part 1 — Spare Parts Approval (new section in MaintenanceRequestsView)
Add a "Spare Parts" segment or section to `MaintenanceRequestsView.swift`.
- Show `store.pendingSparePartsRequests()` with: partName, quantity, estimatedCost,
  reason, requested by (staff name), associated task title.
- Swipe actions: Approve (green), Reject (red, with rejection reason input).
- Approved requests update the in-memory array via AppDataStore helpers.

### Part 2 — Maintenance History (FMS1-17)
Add a "History" tab/segment inside `MaintenanceRequestsView` that shows
`store.maintenanceRecords` sorted by serviceDate descending.
- Each row: vehicle name + plate, issue reported, performedBy name, totalCost, serviceDate.
- Tap navigates to a read-only detail showing full repairDetails + parts used.

## Constraints
- Modify `MaintenanceRequestsView.swift`. Create a detail view for maintenance record
  history if needed (`MaintenanceHistoryDetailView.swift`).
- Do NOT modify `MaintenanceApprovalDetailView.swift`.
- @Observable pattern, no @Published.
- No hardcoded data.

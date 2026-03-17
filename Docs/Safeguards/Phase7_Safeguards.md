# Phase 7 Safeguards — Maintenance Workflow
## Attach these instructions at the END of your Phase 7 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — Work order creation must be idempotent (one work order per task)

work_orders has a UNIQUE constraint on maintenance_task_id. If the "Start Work" button is tapped twice (e.g. network lag, double tap), two INSERT calls would fire. The second would fail with a unique constraint violation and crash if not handled.

The "Start Work" button must:
  1. Be disabled immediately on first tap (isStartingWork = true)
  2. Re-enabled only if the call fails
  3. On success: navigate away so the button is no longer visible

Also, before creating a new work order, query: does a work order already exist for this maintenance_task_id? If yes, load that existing work order instead of trying to create a new one.

## SAFEGUARD 2 — Repair image uploads follow the same sequential pattern as inspection photos

Same rule as Phase 4 Safeguard 1. Upload repair images one at a time in a for-loop, not concurrently. Append each URL to the repair_image_urls array as it succeeds. Partial upload is acceptable — never block work order completion because one photo failed.

## SAFEGUARD 3 — Notification sends on task approve/reject must be non-fatal

When the FM approves or rejects a task, the primary operation is updating maintenance_tasks. The notification send to the assigned maintenance person and/or the driver who raised the request is secondary. If the notification insert fails, it must not roll back or fail the approval.

Wrap all NotificationService calls in MaintenanceApprovalDetailView and related ViewModels with non-fatal try/catch (same pattern as Phase 2 Safeguard 6).

## SAFEGUARD 4 — Task status transitions must be validated before the DB call

Prevent illegal status transitions by checking the current status before calling the service:

  func startWork(task: MaintenanceTask) {
    guard task.status == .assigned else {
      errorMessage = "This task cannot be started — it is \(task.status.rawValue)"
      return
    }
    // proceed
  }

Valid transitions:
  - Pending → Assigned (FM approves)
  - Assigned → In Progress (maintenance person starts work)
  - In Progress → Completed (maintenance person marks done)
  - Pending/Assigned/In Progress → Cancelled (FM rejects or cancels)
  - Any other transition: show error, do NOT call the service

## SAFEGUARD 5 — MaintenanceDashboardViewModel.loadTasks must not re-fetch if data is fresh

Add a lastFetchedAt: Date? property. Only re-fetch if lastFetchedAt is nil or more than 60 seconds ago. Pull-to-refresh explicitly clears lastFetchedAt to force a fresh fetch.

This prevents the maintenance dashboard from hammering Supabase with repeated fetches every time the view appears (e.g. returning from MaintenanceTaskDetailView back to the list).

## SAFEGUARD 6 — Parts cost total must be computed from parts rows, not manually entered

When the maintenance person adds parts in the work order form, the parts_cost_total field on the work_order must NOT be a manually editable field in the UI. It must be computed as the sum of all parts_used rows for that work order:

  var computedPartsCost: Double {
    partsUsed.reduce(0) { $0 + ($1.unitCost * Double($1.quantity)) }
  }

Then update work_orders.parts_cost_total with this computed value when the work order is saved. Never let the user type a parts cost total directly — it would diverge from the actual parts used records.

## SAFEGUARD 7 — MaintenanceApprovalDetailView must read FleetManagerTabView's existing navigation model

Read FleetManagerTabView.swift before writing MaintenanceApprovalDetailView and MaintenanceRequestsView. These views must integrate with whatever NavigationStack or navigation model is already in the FM section — do not introduce a new NavigationStack that conflicts with an existing one.

## VERIFICATION CHECKLIST — Before committing

- [ ] "Start Work" button disabled on tap and work order checked for existence before create
- [ ] Repair image uploads sequential in for-loop
- [ ] Notification sends on approve/reject wrapped in non-fatal catch
- [ ] Task status validated before every service call
- [ ] loadTasks has 60-second freshness guard
- [ ] parts_cost_total computed from partsUsed array, not manually entered
- [ ] New views integrated with existing FM NavigationStack, not a new one

# Phase: Fleet Manager System Role Management

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main  |  Jira: FMS1-27

## Problem
FMS1-27 ("As an Admin, I want to manage system roles") is "To Do" and not started.

In Sierra, "role management" means:
1. Viewing which users have which role (fleetManager / driver / maintenancePersonnel).
2. Suspending / reactivating staff accounts (status: active <-> suspended).
3. The fleet manager role itself cannot be changed from the app — it is set at
   account creation via the `create-staff-account` edge function.

`StaffListView.swift` (14.6KB) and `StaffTabView.swift` (12.8KB) already show
staff lists. `StaffReviewSheet.swift` (16.5KB) handles approval.

## Scope
Add a suspend/reactivate action to existing staff management views.

### Change 1 — StaffListView.swift
In the swipe actions or context menu for each active staff row, add:
- "Suspend" (red) — sets staff[idx].status = .suspended, calls
  `StaffMemberService.updateStaffMember` with the updated record.
- For suspended staff rows, show "Reactivate" (green) — sets status = .active.

### Change 2 — Add role filter to StaffTabView
The segmented picker currently shows "Drivers" / "Maintenance".
Add an "All" segment so the admin can see fleet managers too (read-only — no
suspend action for fleetManager role).

## Constraints
- Modify `StaffListView.swift` and `StaffTabView.swift` only.
- Do NOT modify `StaffReviewSheet.swift`.
- Do NOT allow suspending a fleetManager — gate the action with
  `guard staff.role != .fleetManager else { return }`.
- @Observable pattern, no @Published.
- No new files required.

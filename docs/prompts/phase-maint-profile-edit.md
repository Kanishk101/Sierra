# Phase: Maintenance Staff Profile Edit

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main  |  Jira: FMS1-69

## Problem
The maintenance dashboard Profile tab is read-only. Maintenance staff cannot update
their phone number, address, or emergency contact after onboarding.

`MaintenanceProfileViewModel.swift` (11KB) already exists and has the full editing
logic including `updateProfile()` that calls both `StaffMemberService.updateStaffMember`
and `MaintenanceProfileService.updateMaintenanceProfile`.

## Scope
Add an Edit Profile sheet to the Profile tab in `MaintenanceDashboardView.swift`.

### Change
1. Add `@State private var showEditProfile = false` to the view.
2. Add a toolbar button in the Profile tab NavigationStack:
   ```swift
   .toolbar {
       ToolbarItem(placement: .topBarTrailing) {
           Button("Edit") { showEditProfile = true }
       }
   }
   ```
3. Present a sheet:
   ```swift
   .sheet(isPresented: $showEditProfile) {
       NavigationStack {
           MaintenanceProfileEditView()
       }
   }
   ```
4. Create `MaintenanceProfileEditView.swift` in `Sierra/Maintenance/Views/`.
   It should allow editing: phone, address, emergencyContactName, emergencyContactPhone.
   On Save call `MaintenanceProfileViewModel.updateProfile()` then dismiss.
   Use the existing `MaintenanceProfileViewModel` — do not duplicate logic.

## Constraints
- Only modify `MaintenanceDashboardView.swift` and create `MaintenanceProfileEditView.swift`.
- Do NOT modify `MaintenanceProfileViewModel.swift`.
- Do NOT change appearance, colour scheme, fonts.
- The edit form fields must match what is stored in `staff_members`
  (phone, address, emergency_contact_name, emergency_contact_phone).
- `@Observable` pattern throughout, no @Published.

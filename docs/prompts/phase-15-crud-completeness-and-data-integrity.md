# Phase 15 — CRUD Completeness and Full Data Integrity Audit

## Scope
Verify and fix every CRUD operation across all modules: Staff, Vehicles, Trips, Maintenance,
Fuel Logs, Inspections, Proof of Delivery, Emergency Alerts, Geofences, Notifications.
Ensure Forgot Password / 2FA flows work end-to-end. Fix any remaining data wiring bugs.

---

## Part 1 — Forgot Password Flow Audit

### Current Flow
```
LoginView → ForgotPasswordView → EnterEmail → OTP → NewPassword → Done
```

### Audit Checklist

**ForgotPasswordView.swift + ForgotPasswordViewModel.swift:**

1. `requestPasswordReset(email:)` in AuthManager:
   - Checks if email exists in `staff_members` → if not found, returns `false`
   - Generates OTP, calls `EmailService.sendResetOTP(to:otp:)` (fire-and-forget)
   - Inserts row into `password_reset_tokens` with `used: false`
   - **Verify**: The `prt_insert_anon` RLS policy requires the email to exist in
     `staff_members`. The `send-email` function is `verify_jwt: false`. The reset flow
     calls `supabase.functions.invoke("send-email")` without an auth header — verify
     the `send-email` function's CORS and auth setup allows unauthenticated calls.

2. `resetPassword(code:newPassword:)` in AuthManager:
   - Verifies OTP matches and hasn't expired
   - Calls `reset-password` edge function with email + token + new_password
   - **Verify**: `reset-password` edge function must use `supabase.auth.admin.updateUserById()`
     with service role key to change the password. Fetch its `index.ts` and confirm.
   - After success, clears `pendingResetToken`, `resetOTP`, `pendingOTPEmail`

3. **Bug**: After a successful password reset, the user needs to log in fresh. But
   `ForgotPasswordViewModel.step` may be left in `.success` state when ForgotPasswordView
   dismisses, and the LoginView needs to be clean. Verify `ForgotPasswordView.onDismiss`
   or the success callback resets state properly.

### Fix if needed:
- Confirm `reset-password/index.ts` uses `adminClient.auth.admin.updateUserById(userId, { password: newPassword })`
- If it doesn't, update the function to use admin API
- Add `.interactiveDismissDisabled(false)` only on the OTP entry step (not the email step)

---

## Part 2 — 2FA Flow Audit

### Current Flow
```
signIn() → generateOTP() → EmailService.sendLoginOTP() → TwoFactorView → verifyOTP() → completeAuthentication()
```

### Audit Checklist

1. `generateOTP()` fires `EmailService.sendLoginOTP()` which is fire-and-forget. If the
   email function fails (rate limited, SMTP misconfigured), the user sees the OTP input
   but never receives the code. `TwoFactorView` should show: "Code sent to [masked email].
   Didn't receive it? [Resend]". The "Resend" button should call `generateOTP()` again
   only if the cooldown (`otpCooldownSeconds = 30`) has passed.

2. `TwoFactorViewModel` has a resend mechanism. Verify `TwoFactorView` surfaces a
   "Resend Code" button that is visible after 30s and disabled during cooldown.

3. `verifyOTP()` returns `Bool`. If the OTP has expired (> 10 minutes), it clears the
   OTP and returns false. The UI should distinguish between "wrong code" and "expired code"
   with different error messages.

4. The `onVerified` callback in TwoFactorView/VM calls:
   ```swift
   AuthManager.shared.completeAuthentication()
   resolvedDestination = ctx.authDestination
   showDestination = true
   ```
   Verify `showDestination = true` is always reached and `resolvedDestination` is non-nil.

---

## Part 3 — Vehicle CRUD

### AddVehicleView.swift

Verify:
- All required fields are validated before submit (name, manufacturer, model, year, VIN, license plate, fuel type)
- Duplicate VIN / license plate shows a user-friendly error (not a raw Supabase 409 error)
- `store.addVehicle(_:)` appends to `store.vehicles` array immediately (optimistic) ✓ (already in AppDataStore)
- After add, `store.vehicles` Realtime subscription should receive the new vehicle via INSERT event

**VehicleDetailView.swift** — Edit flow:
- Tapping edit should open an edit sheet, not an inline form
- Edit sheet should use the same form as AddVehicleView but pre-filled
- Submit calls `store.updateVehicle(_:)` which calls `VehicleService.updateVehicle`
- On success, the `vehicles` array is updated in-place via the Realtime UPDATE subscription

### VehicleDocuments
- `VehicleDetailView` should list `store.vehicleDocuments(forVehicle: vehicle.id)`
- Add document button opens an `AddVehicleDocumentSheet` with fields: type, number, issued date, expiry date, authority, note
- Submit calls `store.addVehicleDocument(_:)` ✓
- Swipe-to-delete calls `store.deleteVehicleDocument(id:)` ✓

---

## Part 4 — Staff CRUD

### StaffReviewSheet (Approve/Reject)

`StaffReviewSheet` calls either `store.approveStaffApplication(id:reviewedBy:)` or
`store.rejectStaffApplication(id:reason:reviewedBy:)`. These in turn call
`StaffMemberService.setApprovalStatus(staffId:approved:rejectionReason:)` which updates
`is_approved`, `status`, and `rejection_reason` in `staff_members`.

Verify after approval:
- `staffApplications[idx].status = .approved` in store ✓
- `staff[si].isApproved = true; staff[si].status = .active` in store ✓
- The approved staff member needs to receive a push notification about approval
- Add to `approveStaffApplication()`:
  ```swift
  try? await NotificationService.insertNotification(
      recipientId: app.staffMemberId,
      type: .general,
      title: "Application Approved",
      body: "Your Sierra FMS application has been approved. Complete your profile to get started.",
      entityType: "staff_application",
      entityId: id
  )
  ```

### Staff Suspend / Reactivate

`StaffListView` has swipe actions for Suspend and Reactivate. These call
`store.updateStaffMember(driver)` after mutating `driver.status`. Verify:
- `StaffMemberUpdatePayload` includes `status` field — currently it does NOT include `status`
  (intentionally excluded to prevent self-promotion). But admin suspend/reactivate NEEDS to
  change status. Fix: add a dedicated `setStatusPayload` separate from profile update:
  ```swift
  static func setStatus(staffId: UUID, status: StaffStatus) async throws {
      struct P: Encodable { let status: String }
      try await supabase.from("staff_members")
          .update(P(status: status.rawValue))
          .eq("id", value: staffId.uuidString.lowercased())
          .execute()
  }
  ```
  Call this from `StaffListView` swipe actions instead of `updateStaffMember`.

---

## Part 5 — Trip CRUD (beyond Phase 12 compile fix)

### Trip Edit

`TripDetailView` (admin view) should have an Edit button (only if trip.status == .scheduled).
Editing a scheduled trip should allow changing: priority, notes, scheduled date/time.
Driver and vehicle should NOT be changeable after creation (to avoid resource conflicts).

### Trip Cancel

The cancel action in `TripDetailView` calls `store.deleteTrip(id:)` — this is WRONG.
Cancelling should call `store.updateTripStatus(id:status:.cancelled)` which triggers
the `trg_trip_cancelled` DB trigger that frees driver and vehicle automatically.

Search for `store.deleteTrip` calls in UI code and replace with `updateTripStatus(.cancelled)`
except for actual admin hard-delete (which should be rare and require a confirmation dialog).

---

## Part 6 — Maintenance CRUD

### CreateMaintenanceTaskView

Verify `store.addMaintenanceTask(_:)` correctly:
1. Calls `MaintenanceTaskService.addMaintenanceTask(_:)` ✓
2. Sets vehicle status to `.inMaintenance` ✓
3. If `task.assignedToId` is non-nil, `WorkOrderService.addWorkOrder(_:)` should be called
   automatically to create the corresponding work order — verify this happens in
   `MaintenanceTaskService` or in the calling site

### Work Order Status Transitions

In `MaintenanceDashboardView`, work order status updates (Open → In Progress → Completed)
must call `store.updateWorkOrder(_:)`. Verify these calls pass the full updated WorkOrder
struct, not just a status string.

When a WorkOrder is closed (`store.closeWorkOrder(id:)`):
1. `work_orders.status = "Closed"` ✓
2. The parent `MaintenanceTask.status` should also update to `.completed`
3. Add to `closeWorkOrder()` in AppDataStore:
   ```swift
   if let taskIdx = maintenanceTasks.firstIndex(where: { $0.id == order.maintenanceTaskId }) {
       maintenanceTasks[taskIdx].status = .completed
       maintenanceTasks[taskIdx].completedAt = Date()
   }
   ```

---

## Part 7 — Notifications

### Mark as Read

`NotificationService` needs a `markAsRead(id:)` method:
```swift
static func markAsRead(id: UUID) async throws {
    struct P: Encodable { let is_read: Bool; let read_at: String }
    try await supabase.from("notifications")
        .update(P(is_read: true, read_at: iso.string(from: Date())))
        .eq("id", value: id.uuidString)
        .execute()
}
```
In AppDataStore, add:
```swift
func markNotificationRead(id: UUID) async throws {
    try await NotificationService.markAsRead(id: id)
    if let idx = notifications.firstIndex(where: { $0.id == id }) {
        notifications[idx].isRead = true
    }
}
```

### Clear All Notifications

Add `DELETE` call to clear all:
```swift
func clearAllNotifications(userId: UUID) async throws {
    try await supabase.from("notifications")
        .delete()
        .eq("recipient_id", value: userId.uuidString)
        .execute()
    notifications = []
}
```

---

## Part 8 — Driver-Side Inspections + POD

### PreTripInspectionView

After submitting, calls `store.addVehicleInspection(_:)` which:
1. Inserts to `vehicle_inspections` ✓
2. Updates `trips[idx].preInspectionId` ✓
3. If result is `.failed`: sets vehicle to `.inMaintenance` ✓

Verify the submit button is only enabled when ALL items in the checklist have been
marked (passed/failed/notChecked). Do not allow submitting with default empty items.

### ProofOfDeliveryView

POD submission calls `store.addProofOfDelivery(_:)` which:
1. Inserts to `proof_of_deliveries` ✓
2. Updates `trips[idx].proofOfDeliveryId` ✓
3. Should then automatically call `store.updateTripStatus(id:status:.completed)` — verify this
   happens either in the view or in `AppDataStore.addProofOfDelivery`

---

## Acceptance Criteria

- [ ] Forgot Password → OTP → New Password works end-to-end (verify reset-password fn uses admin API)
- [ ] 2FA OTP "Resend" button visible after 30s, shows correct error for expired vs wrong code
- [ ] Create Vehicle with duplicate VIN → friendly error (not raw Supabase error)
- [ ] Edit Vehicle (scheduled status only) → updates correctly
- [ ] Approve Staff → staff receives in-app notification
- [ ] Suspend Staff → uses dedicated setStatus(), not StaffMemberUpdatePayload
- [ ] Cancel Trip → calls updateTripStatus(.cancelled), NOT deleteTrip
- [ ] Work Order close → parent MaintenanceTask also updates to .completed
- [ ] Notifications: markAsRead and clearAll work
- [ ] POD submission → trip automatically moves to .completed status

# Fix 2 — PendingApprovalView: Poll `refreshCurrentUser()` So Approval Unblocks

## Files
- `Sierra/Auth/PendingApprovalView.swift` (or wherever `PendingApprovalView` is defined)
- `Sierra/FleetManager/ViewModels/StaffApprovalViewModel.swift`

---

## Problem A — Driver stuck on pending forever

When the admin approves a staff application, `staff_members.is_approved` is updated
in the DB. But the driver's `AuthManager.currentUser` is a stale Keychain snapshot.
`ContentView` re-renders based on `destination(for: currentUser)` — but
`currentUser.isApproved` is still `false`. The driver sees `PendingApprovalView`
indefinitely until they kill the app and log back in.

There is no polling, no realtime subscription, no `refreshCurrentUser()` call anywhere
on the pending approval screen.

### Fix — Add polling to `PendingApprovalView`

Add a timer on `onAppear` that calls `AuthManager.shared.refreshCurrentUser()` every
10 seconds. When `isApproved` becomes `true`, `ContentView` automatically re-routes
to the correct dashboard because `destination(for:)` is recomputed reactively.

```swift
// Inside PendingApprovalView body or .onAppear modifier:

.onAppear {
    startPolling()
}
.onDisappear {
    stopPolling()
}
```

Add these to the view:

```swift
@State private var pollingTask: Task<Void, Never>?

private func startPolling() {
    pollingTask = Task {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            try? await AuthManager.shared.refreshCurrentUser()
        }
    }
}

private func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
}
```

No additional navigation logic needed — `ContentView` observes `authManager.currentUser`
and re-evaluates `destination(for:)` automatically when `isApproved` changes.

---

## Problem B — `StaffApprovalViewModel.approve(staffId:)` naming ambiguity

Current code:
```swift
func approve(staffId: UUID) async {
    try await store.approveStaffApplication(id: staffId, reviewedBy: adminId)
}
```

`AppDataStore.approveStaffApplication(id:reviewedBy:)` expects the **application UUID**
(`staff_applications.id`), not the staff member UUID. If the calling view passes
`application.id` it works. If it passes `application.staffMemberId` it silently does
nothing (the `guard let idx` fails and returns).

### Fix — Rename parameter and verify call site

```swift
// StaffApprovalViewModel.swift

@MainActor
func approve(applicationId: UUID) async {
    let adminId  = AuthManager.shared.currentUser?.id ?? UUID()
    isProcessing = true
    errorMessage = nil
    do {
        try await store.approveStaffApplication(id: applicationId, reviewedBy: adminId)
    } catch {
        errorMessage = error.localizedDescription
    }
    isProcessing = false
}

@MainActor
func reject(applicationId: UUID, reason: String) async {
    let adminId  = AuthManager.shared.currentUser?.id ?? UUID()
    isProcessing = true
    errorMessage = nil
    do {
        try await store.rejectStaffApplication(id: applicationId, reason: reason, reviewedBy: adminId)
    } catch {
        errorMessage = error.localizedDescription
    }
    isProcessing = false
    resetRejectState()
}
```

Verify the calling view (wherever `StaffApprovalView` or `StaffListView` calls approve/reject)
passes `application.id` — the UUID from `staff_applications.id` — not `application.staffMemberId`.

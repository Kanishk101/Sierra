# Fix 3 — Remove `notify-fleet-manager` Edge Function Calls

## Files
- `Sierra/Driver/ViewModels/DriverProfileViewModel.swift`
- `Sierra/Maintenance/ViewModels/MaintenanceProfileViewModel.swift`

## Problem

Both profile view models fire:
```swift
_ = try? await supabase.functions.invoke(
    "notify-fleet-manager",
    options: FunctionInvokeOptions(body: bodyData)
)
```

This Edge Function does not exist in Sierra-FMS-v2. It returns 404 on every submission.
Because it's wrapped in `try?` it's silent, but it's a pointless network round-trip
on every onboarding submission.

## Fix

Remove the entire `Task { ... }` block that calls `notify-fleet-manager` from both
view models. The `staff_applications` insert into Supabase is the notification mechanism —
the fleet manager sees the pending count badge update on next `loadAll()` which already
happens on dashboard open.

### In `DriverProfileViewModel.submitProfile()`

Remove this entire block:
```swift
// DELETE THIS ENTIRE TASK BLOCK:
Task {
    let payload: [String: String] = [ ... ]
    guard let bodyData = try? JSONEncoder().encode(payload) else { return }
    _ = try? await supabase.functions.invoke(
        "notify-fleet-manager",
        options: FunctionInvokeOptions(body: bodyData)
    )
}
```

Also remove the `let supabase = SupabaseManager.shared.client` line above it since it's
only used for that call.

### In `MaintenanceProfileViewModel.submitProfile()`

Same — remove the identical `Task { ... }` block and the `let supabase = ...` line.

## After removal

The submit flow becomes:
1. `AppDataStore.shared.addStaffApplication(application)` — inserts into DB ✅
2. `AppDataStore.shared.updateStaffMember(member)` — patches personal details ✅
3. `AuthManager.shared.markProfileComplete()` — sets `is_profile_complete = true` ✅
4. `AuthManager.shared.saveSessionToken()` — saves session ✅
5. `profileSubmitted = true` — triggers navigation ✅

Clean. No dead network calls.

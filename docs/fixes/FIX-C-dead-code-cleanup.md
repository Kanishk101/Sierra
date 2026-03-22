# Fix C — Dead Code Cleanup + Double Edge Function Call 🟡 MEDIUM

**Audit IDs:** Redundancy issues found during Phases 4 + 7 verification  
**Priority:** Medium — no runtime bugs, but creates maintenance confusion and one latent double-invocation risk

---

## The Three Problems

### Problem 1: Double edge-function invocation in `AppDataStore.deleteStaffMember`

`AppDataStore.deleteStaffMember` calls `supabase.functions.invoke("delete-staff-member")` directly. But `StaffMemberService.deleteStaffMember` also calls that same edge function. Any future code that calls `StaffMemberService.deleteStaffMember` directly would invoke the function twice — the DB row would get a second (harmless but wasteful) delete attempt on the already-gone row, and the auth user would get a double-delete attempt that logs a warning.

**Current code in `AppDataStore.swift`:**
```swift
func deleteStaffMember(id: UUID) async throws {
    struct Payload: Encodable { let staffMemberId: String }
    try await supabase.functions.invoke(
        "delete-staff-member",
        options: FunctionInvokeOptions(body: Payload(staffMemberId: id.uuidString))
    )
    staff.removeAll               { $0.id == id }
    // ...
}
```

**Fix:** Route through `StaffMemberService` as the single call point:
```swift
func deleteStaffMember(id: UUID) async throws {
    // StaffMemberService.deleteStaffMember calls the delete-staff-member edge function
    // internally, which handles auth user deletion atomically.
    try await StaffMemberService.deleteStaffMember(id: id)
    staff.removeAll               { $0.id == id }
    driverProfiles.removeAll      { $0.staffMemberId == id }
    maintenanceProfiles.removeAll { $0.staffMemberId == id }
    staffApplications.removeAll   { $0.staffMemberId == id }
}
```

---

### Problem 2: `TripAcceptanceService.swift` is dead code

`Sierra/Shared/Services/TripAcceptanceService.swift` implements `acceptTrip` and `rejectTrip` with direct Supabase DB calls.

However, `AppDataStore+TripAcceptance.swift` calls `TripService.acceptTrip(tripId:driverId:)` and `TripService.rejectTrip(tripId:driverId:reason:)` — which were added in Phase 2. `TripAcceptanceService` is never called anywhere.

Having two implementations of the same operation with the same DB semantics is a maintenance trap — if the trip acceptance logic changes, someone might update one and miss the other.

**Fix:** Delete `Sierra/Shared/Services/TripAcceptanceService.swift`. Verify there are zero references to `TripAcceptanceService` or `TripAcceptanceError` anywhere in the codebase before deleting. If `TripAcceptanceError.driverMismatch` is referenced, move that error case into `TripServiceError` in `TripService.swift`.

---

### Problem 3: `.DS_Store` committed to the repo

`Sierra/.DS_Store` is tracked in git (SHA `cec71497`). This is macOS metadata noise that should never be in a repo.

**Fix:**
1. Add `.DS_Store` and `**/.DS_Store` to `.gitignore` at the repo root
2. Remove `Sierra/.DS_Store` from git tracking (the file can stay on disk, just not in the repo)

---

## Implementation Steps

### Step 1 — Fix `AppDataStore.deleteStaffMember`

In `Sierra/Shared/Services/AppDataStore.swift`, find the `deleteStaffMember` method and replace the direct `supabase.functions.invoke` call with `StaffMemberService.deleteStaffMember(id: id)` as shown above.

### Step 2 — Delete `TripAcceptanceService.swift`

First confirm zero call sites:
```bash
grep -r "TripAcceptanceService" Sierra/
grep -r "TripAcceptanceError" Sierra/
```

If zero results: delete the file.

If `TripAcceptanceError` is referenced: add the `driverMismatch` and `reasonRequired` cases to `TripServiceError` in `TripService.swift`, then update the reference, then delete `TripAcceptanceService.swift`.

### Step 3 — Fix `.gitignore`

Create or update `.gitignore` at the repo root to include:
```
# macOS
.DS_Store
**/.DS_Store
.AppleDouble
.LSOverride

# Xcode
build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
!default.pbxuser
!default.mode1v3
!default.mode2v3
!default.mode3v3
!default.perspectivev3
xcuserdata/
*.xccheckout
*.moved-to-trash/
*.xcuserstate
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/

# Environment / secrets
Secrets.xcconfig
.env
*.p8
```

Then remove the tracked `.DS_Store`:
```bash
git rm --cached Sierra/.DS_Store
git commit -m "chore: remove tracked .DS_Store"
```

---

## Acceptance Criteria

- `AppDataStore.deleteStaffMember` → `StaffMemberService.deleteStaffMember` → edge function (one call only)
- `TripAcceptanceService.swift` does not exist in the repo
- `git ls-files | grep DS_Store` returns nothing
- `.gitignore` includes `.DS_Store` and `**/.DS_Store`

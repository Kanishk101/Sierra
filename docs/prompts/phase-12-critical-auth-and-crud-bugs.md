# Phase 12 — Critical Auth Bugs + CRUD Compile Errors

## Scope
Fix all blocking bugs that prevent the app from functioning: Face ID login loop, Trip create
compile error, Staff create email separation. No UI restyling in this phase.

---

## Bug 1 — Face ID Loops Back to Login Screen

### Root Cause Analysis

There are **three compounding problems** in the biometric wiring:

**Problem A: Two disconnected biometric preference systems**
- `BiometricAuthManager.swift` stores the enabled flag in **UserDefaults** under key `"sierra.biometric.enabled"`
- `BiometricEnrollmentSheet.swift` stores it in **Keychain** under key `"com.fleetOS.biometricEnabled"`
- `LoginViewModel.showBiometricButton` reads `BiometricEnrollmentSheet.isBiometricEnabled()` (Keychain)
- `DriverProfileSheet` toggles `BiometricAuthManager.isEnabled` (UserDefaults)
- **These are completely disconnected.** Toggling Face ID in the profile sheet has zero effect on
  whether the login button appears. Users enable it in profile, but the login screen still shows no button.

**Problem B: `signOut()` wipes biometric Keychain keys every logout**
In `AuthManager.signOut()`:
```swift
KeychainService.delete(key: Keys.biometricOn)       // "com.fleetOS.biometricEnabled"
KeychainService.delete(key: Keys.biometricPrompted)  // "com.fleetOS.hasPromptedBiometric"
```
Every signout destroys the enrollment. Next login: `BiometricEnrollmentSheet.isBiometricEnabled()` returns
false → button hidden. User enrolled, signed out, re-opens app, no biometric button. They sign in with
password, complete 2FA, get the enrollment prompt again (because `hasPrompted` was also wiped). This is
a terrible UX loop even before the navigation bug.

**Problem C: Biometric success in `LoginViewModel.biometricSignIn()` does not navigate**
After `BiometricManager.shared.authenticate()` succeeds:
```swift
AuthManager.shared.completeAuthentication()  // sets isAuthenticated = true
AuthManager.shared.reauthCompleted()          // sets needsReauth = false
authState = .idle                              // PROBLEM: no navigation triggered
```
ContentView's `Group` condition is:
```swift
} else if authManager.isAuthenticated, !authManager.needsReauth {
    destinationView(for: ...)
```
If `isAuthenticated` was **already true** from `restoreSessionSilently()`, changing `needsReauth` from
true → false SHOULD re-render ContentView. But `@Observable` only re-renders if an observed property
actually changes. Since `isAuthenticated` did not change (it was already true), and `needsReauth` DID
change, ContentView should re-render. However, ContentView is still displaying `LoginView()` and
LoginView has `authState = .idle` — the `onChange(of: viewModel.authState)` fires but the `.idle`
case does nothing (`default: break`). The fullScreenCover `showDestination` is never set to `true`.

The fix: biometric login must explicitly set `resolvedDestination` and `showDestination = true`, OR
the architecture should be simplified so ContentView alone controls navigation (no competing fullScreenCover).

**Correct Architecture:**
The simplest, most correct fix:
1. Remove biometric login from `LoginViewModel` entirely
2. `BiometricLockView` is the ONLY biometric auth surface
3. When app launches with a valid session (restoreSession returns a user), immediately show BiometricLockView if `BiometricEnrollmentSheet.isBiometricEnabled()` is true
4. ContentView becomes the sole navigator — no fullScreenCovers in LoginView competing with it
5. LoginView only handles email+password+2FA for brand new sessions

### Fix Instructions

**Step 1: Consolidate biometric preference into a single source of truth**

Create `Sierra/Auth/BiometricPreference.swift` as a replacement for both `BiometricAuthManager.swift`
and the inline Keychain usage in `BiometricEnrollmentSheet.swift`. Use a single Keychain key.

```swift
// Sierra/Auth/BiometricPreference.swift
import Foundation

enum BiometricPreference {
    private static let enabledKey  = "com.sierra.biometricEnabled"   // ONE canonical key
    private static let promptedKey = "com.sierra.biometricPrompted"

    static var isEnabled: Bool {
        get {
            guard let data = KeychainService.load(key: enabledKey),
                  let str  = String(data: data, encoding: .utf8) else { return false }
            return str == "true"
        }
        set {
            let str = newValue ? "true" : "false"
            if let data = str.data(using: .utf8) { _ = KeychainService.save(data, forKey: enabledKey) }
        }
    }

    static var hasBeenPrompted: Bool {
        KeychainService.load(key: promptedKey) != nil
    }

    static func markPrompted() {
        if let data = "true".data(using: .utf8) { _ = KeychainService.save(data, forKey: promptedKey) }
    }

    // Called on signOut — does NOT wipe enabled/prompted flags.
    // The user's preference persists across sessions deliberately.
    // (contrast: old code wiped these on every signout causing the loop)
    static func clearSessionData() {
        // Nothing to clear — preference is permanent until user disables it
    }
}
```

**Step 2: Remove biometric keys from `AuthManager.signOut()`**

In `Sierra/Auth/AuthManager.swift`, remove these two lines from `signOut()`:
```swift
// REMOVE:
KeychainService.delete(key: Keys.biometricOn)
KeychainService.delete(key: Keys.biometricPrompted)
```
Also remove these from `private enum Keys`:
```swift
// REMOVE:
static let biometricOn       = "com.fleetOS.biometricEnabled"
static let biometricPrompted = "com.fleetOS.hasPromptedBiometric"
```

**Step 3: Update `BiometricEnrollmentSheet.swift`**

Replace all KeychainService calls with `BiometricPreference`:
```swift
// Replace:
static func shouldPrompt() -> Bool {
    !BiometricPreference.hasBeenPrompted
}
static func isBiometricEnabled() -> Bool {
    BiometricPreference.isEnabled
}
private static func setBiometricEnabled(_ enabled: Bool) {
    BiometricPreference.isEnabled = enabled
}
private static func markAsPrompted() {
    BiometricPreference.markPrompted()
}
```

**Step 4: Update `BiometricAuthManager.swift`**

Delegate to `BiometricPreference`:
```swift
enum BiometricAuthManager {
    static var isEnabled: Bool {
        get { BiometricPreference.isEnabled }
        set { BiometricPreference.isEnabled = newValue }
    }
    static func enable()  { BiometricPreference.isEnabled = true }
    static func disable() { BiometricPreference.isEnabled = false }
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, localizedReason: reason
        )) ?? false
    }
}
```

**Step 5: Fix `LoginViewModel.showBiometricButton` and `biometricSignIn()`**

In `LoginViewModel.swift`:

```swift
// showBiometricButton — both systems now read the same key
var showBiometricButton: Bool {
    BiometricManager.shared.canUseBiometrics()
        && AuthManager.shared.hasSessionToken()
        && BiometricPreference.isEnabled
}
```

For `biometricSignIn()`, after success set `resolvedDestination` and `showDestination` explicitly:
```swift
@MainActor
func biometricSignIn() async {
    authState = .loading
    do {
        try await BiometricManager.shared.authenticate(
            reason: "Sign in to Sierra"
        )
        guard AuthManager.shared.hasSessionToken(),
              let user = AuthManager.shared.currentUser else {
            authState = .error("Session expired. Please sign in with your password.")
            AuthManager.shared.signOut()
            return
        }
        // Prefetch AFTER successful auth, not before
        Task.detached {
            switch user.role {
            case .fleetManager:         await AppDataStore.shared.loadAll()
            case .driver:               await AppDataStore.shared.loadDriverData(driverId: user.id)
            case .maintenancePersonnel: await AppDataStore.shared.loadMaintenanceData(staffId: user.id)
            }
        }
        AuthManager.shared.completeAuthentication()
        AuthManager.shared.reauthCompleted()
        // CRITICAL FIX: set the destination explicitly so LoginView navigates
        let dest = AuthManager.shared.destination(for: user)
        authState = .authenticated(destination: dest)
    } catch {
        if let bioError = error as? BiometricError {
            authState = bioError == .userCancelled ? .idle
                : .error(bioError.errorDescription ?? "Biometric authentication failed.")
        } else {
            authState = .error("Biometric authentication failed.")
        }
    }
}
```

**Step 6: Update `DriverProfileSheet.swift` Face ID toggle**

The `onChange(of: isBiometricEnabled)` in `DriverProfileSheet` calls `BiometricAuthManager.enable()/disable()`.
Since `BiometricAuthManager` now delegates to `BiometricPreference`, this is automatically correct.
Initialise the `@State` with the unified source:
```swift
@State private var isBiometricEnabled = BiometricPreference.isEnabled
```

---

## Bug 2 — Trip Creation Compile Error (Missing `routeStops` Parameter)

### Root Cause

In `Sierra/FleetManager/Views/CreateTripView.swift`, the `createTrip()` method constructs a `Trip`
using the memberwise initializer. After Phase 11, `Trip` gained a new non-optional-with-default field:
```swift
var routeStops: [RouteStop]?  // added in Phase 11 commit
```
The memberwise init in `createTrip()` is missing this parameter, causing a **compile error that
prevents ALL trip creation**. Additionally, the `stops: [GeocodedAddress]` array that the UI collects
is never converted to `[RouteStop]` and written to the trip.

Also: `routeFieldValidationError(for:)` rejects any input containing digits, which means real
addresses ("12 MG Road", "Plot 5, Sector 17") cannot be entered. Numbers are valid in addresses.

### Fix Instructions

**In `CreateTripView.createTrip()`, add `routeStops` and fix the validation:**

```swift
// 1. Fix routeFieldValidationError — remove the number rejection
private func routeFieldValidationError(for value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "This field is required." }
    if trimmed.count < 3 { return "Address is too short." }
    return nil  // Numbers are valid in addresses — remove the regex check
}

// 2. In createTrip(), convert stops to RouteStop and pass to Trip init
let routeStops: [RouteStop] = stops.enumerated().map { index, addr in
    RouteStop(
        name: addr.shortName,
        latitude: addr.latitude,
        longitude: addr.longitude,
        order: index + 1
    )
}

// 3. Add routeStops to Trip initializer call
let trip = Trip(
    id: UUID(),
    taskId: TripService.newTaskId(),
    driverId: driverId.uuidString,
    vehicleId: vehicleId.uuidString,
    createdByAdminId: adminId.uuidString,
    origin: origin.trimmingCharacters(in: .whitespaces),
    destination: destination.trimmingCharacters(in: .whitespaces),
    originLatitude: originCoords?.0,
    originLongitude: originCoords?.1,
    destinationLatitude: destCoords?.0,
    destinationLongitude: destCoords?.1,
    routePolyline: nil,
    routeStops: routeStops.isEmpty ? nil : routeStops,  // ADD THIS
    deliveryInstructions: notes,
    scheduledDate: scheduledDate,
    scheduledEndDate: scheduledEndDate,
    actualStartDate: nil,
    actualEndDate: nil,
    startMileage: nil,
    endMileage: nil,
    notes: notes,
    status: .scheduled,
    priority: priority,
    proofOfDeliveryId: nil,
    preInspectionId: nil,
    postInspectionId: nil,
    driverRating: nil,
    driverRatingNote: nil,
    ratedById: nil,
    ratedAt: nil,
    createdAt: now,
    updatedAt: now
)
```

**Also fix `TripService.addTrip()` to include `route_stops` in the Supabase insert payload:**

In `Sierra/Shared/Services/TripService.swift`, find the INSERT payload struct and add:
```swift
let route_stops: String  // JSON-encoded [RouteStop]
// In the initializer: encode routeStops as JSON string for the JSONB column
let stopsJSON = (try? String(data: JSONEncoder().encode(trip.routeStops ?? []), encoding: .utf8)) ?? "[]"
```

---

## Bug 3 — Staff Creation: Email Failure Kills Entire Operation

### Root Cause

In `CreateStaffViewModel.createStaff()`:
```swift
// Step 1: create-staff-account edge fn (creates auth user + staff_members row) — SUCCEEDS
let created: CreateStaffAccountResponse = try await supabase.functions.invoke(...)

// Step 2: sendCredentials — if GMAIL secrets not configured OR email bounces, THROWS
try await EmailService.sendCredentials(to: trimmedEmail, name: ..., ...)

// If Step 2 throws, catch block sets:
errorMessage = "Failed to create staff account."  // WRONG: account WAS created
```

The user (auth + DB row) was created successfully. But if email fails, the admin sees
"Failed to create staff account" and has no idea the user exists. The new staff member
has an account with no way to log in.

### Fix Instructions

**In `CreateStaffViewModel.createStaff()`**, decouple account creation from email delivery:

```swift
@MainActor
func createStaff() async {
    guard canSubmit, let role = selectedRole else { return }
    guard role == .driver || role == .maintenancePersonnel else {
        errorMessage = "Only Driver or Maintenance accounts can be created here."
        return
    }

    isLoading = true
    errorMessage = nil

    let tempPassword = generateTemporaryPassword()
    let trimmedName  = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

    // Phase 1: Create account (atomic — auth user + staff_members row)
    let accountCreated: Bool
    do {
        let payload = CreateStaffAccountPayload(
            email: trimmedEmail, password: tempPassword,
            name: trimmedName, role: role.rawValue
        )
        let created: CreateStaffAccountResponse = try await supabase.functions.invoke(
            "create-staff-account",
            options: FunctionInvokeOptions(body: payload)
        )
        guard UUID(uuidString: created.id) != nil else {
            throw URLError(.badServerResponse)
        }
        accountCreated = true
    } catch {
        isLoading = false
        errorMessage = error.localizedDescription.contains("already registered")
            ? "An account with this email already exists."
            : "Failed to create account: \(error.localizedDescription)"
        return
    }

    // Phase 2: Send credentials (non-fatal — account is already created)
    var emailSent = false
    if accountCreated {
        do {
            try await EmailService.sendCredentials(
                to: trimmedEmail, name: trimmedName,
                password: tempPassword, role: role
            )
            emailSent = true
        } catch {
            // Log but don't fail — admin can share credentials manually
            print("[CreateStaff] Email delivery failed (non-fatal): \(error)")
        }
    }

    isLoading = false
    createdStaffName = trimmedName
    createdStaffEmail = trimmedEmail          // new property to store email for display
    createdTempPassword = emailSent ? nil : tempPassword  // show password if email failed
    emailDelivered = emailSent
    showSuccess = true

    NotificationCenter.default.post(
        name: .staffCreated,
        object: nil,
        userInfo: ["name": trimmedName, "email": trimmedEmail, "role": role.rawValue]
    )
}
```

**Add new properties to `CreateStaffViewModel`:**
```swift
var createdStaffEmail: String   = ""
var createdTempPassword: String? = nil  // non-nil only if email failed
var emailDelivered: Bool         = true
```

**Update `CreateStaffView.successView`** to show the temporary password if email failed:
```swift
// In successView, below the role badge:
if !viewModel.emailDelivered {
    VStack(spacing: 8) {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Email delivery failed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
        }
        Text("Share these credentials manually:")
            .font(.caption).foregroundStyle(.secondary)
        if let pwd = viewModel.createdTempPassword {
            VStack(spacing: 4) {
                Text(viewModel.createdStaffEmail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(pwd)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(.orange)
            }
            .padding(12)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    .padding(.horizontal, 24)
} else {
    Text("Credentials emailed to \(viewModel.createdStaffEmail)")
        .font(.caption).foregroundStyle(.secondary)
}
```

---

## Files to Modify

| File | Change |
|---|---|
| `Sierra/Auth/BiometricPreference.swift` | NEW — single source of truth for biometric preference |
| `Sierra/Auth/AuthManager.swift` | Remove biometric keys from signOut() and Keys enum |
| `Sierra/Auth/BiometricEnrollmentSheet.swift` | Use BiometricPreference instead of inline Keychain |
| `Sierra/Auth/BiometricAuthManager.swift` | Delegate to BiometricPreference |
| `Sierra/Auth/ViewModels/LoginViewModel.swift` | Fix biometricSignIn() to set authState = .authenticated |
| `Sierra/Driver/Views/DriverProfileSheet.swift` | Use BiometricPreference.isEnabled for @State init |
| `Sierra/FleetManager/Views/CreateTripView.swift` | Add routeStops, fix routeFieldValidationError |
| `Sierra/Shared/Services/TripService.swift` | Add route_stops to INSERT payload |
| `Sierra/FleetManager/ViewModels/CreateStaffViewModel.swift` | Decouple account from email, add email/pwd properties |

---

## Acceptance Criteria

- [ ] Enable Face ID in DriverProfileSheet → biometric button appears on next login screen
- [ ] Sign out and sign back in → biometric button STILL appears (preference persists)
- [ ] Tap Face ID on login → scan succeeds → immediately navigates to dashboard (no loop)
- [ ] Create Trip with an address containing numbers ("12 MG Road") → step 1 valid
- [ ] Create Trip completes without compile error
- [ ] Stops added in CreateTripView are persisted to trips.route_stops
- [ ] Add Staff when email fails → admin sees success with fallback credentials shown
- [ ] Add Staff when email succeeds → admin sees success with confirmation email was sent

# Phase 6 — ForcePasswordChangeViewModel.swift (Vinayak Pattern)

## File
`Sierra/Auth/ViewModels/ForcePasswordChangeViewModel.swift`

## What to implement

Adapt to vinayak pattern:
- `verifyCurrentPassword()`: call `AuthManager.shared.signIn()` which now queries
  `staff_members` by email + password comparison (no Supabase Auth SDK)
- After successful password change: call `AuthManager.shared.generateOTP()`
  then set `awaitingOTP = true` to trigger the 2FA view
- Remove `readyToNavigate` / `completed` state vars (use `awaitingOTP` instead)

---

## State vars

```swift
var currentPassword: String = ""
var newPassword: String = ""
var confirmPassword: String = ""

var isCurrentPasswordVisible: Bool = false
var isNewPasswordVisible: Bool = false
var isConfirmPasswordVisible: Bool = false

var isLoading: Bool = false
var errorMessage: String?
var currentPasswordError: String?
var nextDestination: AuthDestination?
var awaitingOTP: Bool = false     // triggers TwoFactorView fullScreenCover
```

---

## `setNewPassword()` — vinayak implementation

```swift
@MainActor
func setNewPassword() async {
    guard canSubmit else { return }
    currentPasswordError = nil
    errorMessage = nil
    isLoading = true

    // 1. Verify current password — re-queries staff_members by email + password
    let isValidCurrent = await verifyCurrentPassword()
    guard isValidCurrent else {
        isLoading = false
        currentPasswordError = "Current password is incorrect"
        return
    }

    // 2. New password must differ from current
    guard newPassword != currentPassword else {
        isLoading = false
        errorMessage = "New password must be different from your current password"
        return
    }

    do {
        // 3. Update staff_members.password + is_first_login (Phase 2)
        try await AuthManager.shared.updatePasswordAndFirstLogin(newPassword: newPassword)

        // 4. Determine next destination
        if let user = AuthManager.shared.currentUser {
            switch user.role {
            case .driver:               nextDestination = .driverOnboarding
            case .maintenancePersonnel: nextDestination = .maintenanceOnboarding
            case .fleetManager:         nextDestination = .fleetManagerDashboard
            }
        }

        // 5. Generate OTP + send via SwiftSMTP — triggers TwoFactorView
        AuthManager.shared.generateOTP()
        isLoading = false
        awaitingOTP = true

    } catch {
        isLoading = false
        errorMessage = "Failed to update password. Please try again."
    }
}
```

---

## `verifyCurrentPassword()` — vinayak implementation

```swift
private func verifyCurrentPassword() async -> Bool {
    guard let email = AuthManager.shared.currentUser?.email else { return false }
    do {
        _ = try await AuthManager.shared.signIn(email: email, password: currentPassword)
        return true
    } catch {
        return false
    }
}
```

`AuthManager.signIn()` now queries `staff_members` directly (Phase 2),
so this works without any Supabase Auth session.

---

## Validation computed vars — keep as-is
- `strength`, `hasMinLength`, `hasUppercase`, `hasNumber`, `hasSpecialChar`
- `passwordsMatch`, `allRequirementsMet`, `canSubmit`, `confirmPasswordError`
- `PasswordStrength` enum (keep in this file, same as vinayak)

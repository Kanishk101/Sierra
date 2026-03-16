# Phase 3 — ForcePasswordChangeView: Post-OTP Auth Logic Fix

---

## Context

You are working on the **Sierra Fleet Management System** iOS app (SwiftUI, MVVM, iOS 26+).  
This is a targeted logic fix to `Sierra/Auth/ForcePasswordChangeView.swift`.

Do not change any UI layout, gradients, colors, fonts, or card styles in this view.

### What is being fixed

After a first-login user successfully changes their password, a 2FA OTP screen appears.  
When that OTP is verified, the `onVerified` closure runs — but the action taken after  
verification is incorrect.

**Current (your) code:**
```swift
onVerified: {
    viewModel.awaitingOTP = false
    // Do NOT call completeAuthentication() here.
    // completeAuthentication() was already called by LoginViewModel.signIn()
    // for first-login users, so isAuthenticated is already true.
    // updatePasswordAndFirstLogin() already set currentUser.isFirstLogin = false.
    // ContentView observes currentUser changes and automatically re-routes
    // to .driverOnboarding or .maintenanceOnboarding without any extra push.
    AuthManager.shared.saveSessionToken()
},
```

**The problem:** `saveSessionToken()` is the wrong call here. By this point in the flow,  
the session token was already persisted during the initial `signIn()`. What needs to happen  
after OTP verification in the first-login password change flow is:
- Signal that the mandatory first-login process is fully complete
- Allow `AuthManager` to transition the user out of the `forcePasswordChange` gate
- This is done via `AuthManager.shared.confirmFirstLoginComplete()`

This was identified by comparing with the Fleetora sibling repo which corrected this call.

---

## File — `Sierra/Auth/ForcePasswordChangeView.swift`

### Required Change — `onVerified` closure inside the `.fullScreenCover` modifier

Locate the `.fullScreenCover(isPresented: $viewModel.awaitingOTP)` block. Inside  
`TwoFactorViewModel`'s `onVerified` closure, make this single-line change:

**Remove:**
```swift
AuthManager.shared.saveSessionToken()
```

**Replace with:**
```swift
AuthManager.shared.confirmFirstLoginComplete()
```

**Also remove** the surrounding multi-line comment block that explained why NOT to call  
`completeAuthentication()` — this comment was documenting the workaround that is now  
being replaced with the correct call. Clean comments are preferred.

### Before (current state of the fullScreenCover block)

```swift
.fullScreenCover(isPresented: $viewModel.awaitingOTP) {
    TwoFactorView(
        viewModel: TwoFactorViewModel(
            subtitle: "Verify your identity",
            maskedEmail: AuthManager.shared.maskedEmail,
            onVerified: {
                viewModel.awaitingOTP = false
                // Do NOT call completeAuthentication() here.
                // completeAuthentication() was already called by LoginViewModel.signIn()
                // for first-login users, so isAuthenticated is already true.
                // updatePasswordAndFirstLogin() already set currentUser.isFirstLogin = false.
                // ContentView observes currentUser changes and automatically re-routes
                // to .driverOnboarding or .maintenanceOnboarding without any extra push.
                AuthManager.shared.saveSessionToken()
            },
            onCancelled: {
                viewModel.awaitingOTP = false
            }
        )
    )
}
```

### After (target state)

```swift
.fullScreenCover(isPresented: $viewModel.awaitingOTP) {
    TwoFactorView(
        viewModel: TwoFactorViewModel(
            subtitle: "Verify your identity",
            maskedEmail: AuthManager.shared.maskedEmail,
            onVerified: {
                viewModel.awaitingOTP = false
                AuthManager.shared.confirmFirstLoginComplete()
            },
            onCancelled: {
                viewModel.awaitingOTP = false
            }
        )
    )
}
```

---

## Prerequisite — Verify `confirmFirstLoginComplete()` exists

Before making this change, verify that `AuthManager.swift` has a method named  
`confirmFirstLoginComplete()`. Search for it:

```
Sierra/Auth/AuthManager.swift
```

**If it exists:** proceed with the change above.

**If it does NOT exist:** you need to add it. Based on the auth flow, this method should:
1. Set the current user's `isFirstLogin` flag to `false` in the local model and Supabase
2. Call `saveSessionToken()` to persist the updated session
3. Publish a change on `currentUser` so `ContentView` re-evaluates routing

Here is the implementation to add to `AuthManager` if missing:

```swift
/// Called after a first-login user completes mandatory password change + OTP verification.
/// Clears the firstLogin gate and persists the session.
func confirmFirstLoginComplete() {
    guard var user = currentUser else { return }
    user.isFirstLogin = false
    currentUser = user
    saveSessionToken()
}
```

Place it in the `// MARK: - Session Management` section of `AuthManager.swift`.

---

## Do NOT Change

- Any visual element in `ForcePasswordChangeView` (gradient, card, fields, buttons)
- `ForcePasswordChangeViewModel.swift`
- Any other `AuthManager` method
- The `onCancelled` closure
- The `PasswordStrengthView` component

---

## Success Criteria

- [ ] `onVerified` in `ForcePasswordChangeView` calls `confirmFirstLoginComplete()` not `saveSessionToken()`
- [ ] `AuthManager.confirmFirstLoginComplete()` exists and is correctly implemented
- [ ] The verbose comment block explaining the old workaround is removed
- [ ] App compiles with zero errors
- [ ] First-login password change flow routes correctly after OTP verification

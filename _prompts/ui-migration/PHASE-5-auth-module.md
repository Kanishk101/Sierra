# PHASE 5 — Auth Module Migration

## Context
Files in `Sierra/Auth/`. These are the login, OTP, password, and biometric screens. Read Phase 1 for the palette.

Auth screens are special: some are **full-screen presented views** (no tab bar), some are sheets. They have their own unique UI patterns. The migration goal is native system colors while keeping the Sierra security/auth logic 100% intact.

**ViewModels, AuthManager, BiometricManager, all auth services** — DO NOT TOUCH.

---

## NAVIGATION RULES FOR AUTH SCREENS

Auth screens do NOT use large morphing titles. They use:
- Full-screen presentations: no `NavigationStack` wrapper, OR `NavigationStack` with `.navigationBarHidden(true)` / minimal toolbar
- Sheet presentations: standard `.navigationTitle` + `.navigationBarTitleDisplayMode(.inline)`
- Exception: `ForcePasswordChangeView`, `ChangePasswordView`, `ForgotPasswordView` — these flow screens can use `.inline` title

---

## FILE 1: `LoginView.swift` (11898 bytes in Fleetora vs 15075 in Sierra)

The Fleetora version is significantly smaller, meaning the dark gradient hero and heavy custom styling was simplified. Apply:

**Background**: Replace any `LinearGradient(summitNavy → sierraBlue)` full-screen background with `Color(.systemBackground)` or if keeping a header accent, use a small orange accent area at the top only.

**Logo/App name area**:
- App icon or logo: keep as-is
- App name text: `.font(.largeTitle.weight(.bold)).foregroundStyle(.primary)`
- Subtitle: `.font(.subheadline).foregroundStyle(.secondary)`

**Email field**: Native `TextField` with `.textFieldStyle(.roundedBorder)` OR `SierraTextField` if it compiles — keep whichever compiles

**Password field**: Native `SecureField` with `.textFieldStyle(.roundedBorder)`

**Sign In button**: 
```swift
Button(action: signIn) {
    if isLoading {
        ProgressView().tint(.white)
    } else {
        Text("Sign In").font(.headline).foregroundStyle(.white)
    }
}
.frame(maxWidth: .infinity).frame(height: 50)
.background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
.disabled(isLoading)
```

**Forgot password link**: `.foregroundStyle(.orange)`

**Error messages**: `.foregroundStyle(.red)` text, or a capsule/banner with `Color(.systemRed).opacity(0.1)` background

**Biometric button** (Face ID/Touch ID):
```swift
Button(action: authenticateWithBiometrics) {
    Image(systemName: biometricIcon)
        .font(.system(size: 28)).foregroundStyle(.orange)
}
```

**Overall screen background**: `Color(.systemGroupedBackground).ignoresSafeArea()` — or if keeping a two-panel look, use `Color(.systemBackground)` for the form card on `Color(.systemGroupedBackground)`

**Form card** (if using card layout):
```swift
.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
.shadow(color: .black.opacity(0.04), radius: 8, y: 4)
```

**Remove**: All `SierraTheme.Colors.*`, `SierraFont.*`, `LinearGradient` with navy/blue, custom shadow modifiers

---

## FILE 2: `TwoFactorView.swift` (OTP Screen)

```swift
// Background
Color(.systemGroupedBackground).ignoresSafeArea()

// Instruction text
Text("Enter the 6-digit code")
    .font(.title2.weight(.bold)).foregroundStyle(.primary)
Text("sent to your email")
    .font(.subheadline).foregroundStyle(.secondary)

// OTP digit boxes — each box:
RoundedRectangle(cornerRadius: 12, style: .continuous)
    .strokeBorder(isFocused ? Color.orange : Color(.separator), lineWidth: isFocused ? 2 : 1)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

// OTP digit text
.font(.system(size: 28, weight: .bold, design: .monospaced)).foregroundStyle(.primary)

// Verify button: orange fill same as login
// Resend code: .foregroundStyle(.orange) link style
// Error: .foregroundStyle(.red)
// Timer countdown: .foregroundStyle(.secondary)
```

Keep all OTP logic, timers, and verification flow unchanged.

---

## FILE 3: `ForcePasswordChangeView.swift`

This appears after admin-reset passwords:
- Background: `Color(.systemGroupedBackground)`
- Form: `Color(.secondarySystemGroupedBackground)` section container
- Password fields: native `SecureField`
- Requirements list (if any): green checkmark for met, secondary for unmet
- Submit button: `.orange` fill
- Navigation: `.navigationTitle("Change Password")` + `.inline`

---

## FILE 4: `ForgotPasswordView.swift`

- Background: `Color(.systemGroupedBackground)`
- Email input: native `TextField`
- Send button: `.orange` fill
- Success state: green icon + `.foregroundStyle(.green)` text
- Navigation: `.navigationTitle("Forgot Password")` + `.inline`
- Back/cancel: `.foregroundStyle(.orange)` or system back button

---

## FILE 5: `ChangePasswordView.swift`

Same pattern as ForcePasswordChangeView. Orange primary button, native form fields, system background.

---

## FILE 6: `BiometricLockView.swift`

This is the app lock screen shown over the app when biometric auth is required:
- Background: `Color(.systemBackground)` or `.ultraThinMaterial` over blur
- App icon or lock icon: centered, large
- Biometric prompt button:
  ```swift
  Button(action: authenticate) {
      VStack(spacing: 8) {
          Image(systemName: biometricSystemImage)  // faceid or touchid
              .font(.system(size: 52)).foregroundStyle(.orange)
          Text("Tap to unlock")
              .font(.subheadline).foregroundStyle(.secondary)
      }
  }
  ```
- Error text: `.foregroundStyle(.red)`
- Fallback button ("Use Password"): `.foregroundStyle(.orange)`

---

## FILE 7: `BiometricEnrollmentSheet.swift`

Sheet for enrolling Face ID/Touch ID:
- Background: `Color(.systemGroupedBackground)`
- Feature description rows: `Color(.secondarySystemGroupedBackground)` container with icon + text
- Enable button: `.orange` fill
- Skip: `.foregroundStyle(.secondary)`
- Icons: `.foregroundStyle(.orange)`

---

## FILE 8: `PendingApprovalView.swift`

Shown to drivers waiting for admin approval:
- Background: `Color(.systemGroupedBackground).ignoresSafeArea()`
- Status illustration/icon: `.foregroundStyle(.orange)` (pending) 
- Title: `.font(.title2.weight(.bold)).foregroundStyle(.primary)`
- Description: `.font(.body).foregroundStyle(.secondary)`
- Status indicator: orange waiting spinner or icon
- Sign out button: `.foregroundStyle(.red)` in a contained style

---

## FILE 9: `DriverOnboardingView.swift`

Post-signup flow for new drivers:
- Background: `Color(.systemGroupedBackground)`
- Step indicators: `.orange` for active, `.secondary` for inactive
- Continue button: `.orange` fill
- Info fields: native fields
- Remove Sierra tokens

---

## AUTH MODULE — GLOBAL RULES
1. ALL `SierraTheme.Colors.*` → system colors
2. ALL `SierraFont.*` → system fonts (`.headline`, `.body`, `.subheadline`, `.caption`, `.system(size:weight:)`)
3. Dark gradient backgrounds → `Color(.systemGroupedBackground)` or `Color(.systemBackground)`
4. Primary accent everywhere: `.orange` / `Color(.systemOrange)`
5. Auth **business logic** (Supabase calls, session management, biometric auth, OTP) — completely unchanged
6. `AuthManager`, `BiometricManager`, all ViewModels — completely unchanged

# Fix 4 — Eliminate 2FA Screen Lag (Generate OTP Before Screen Appears)

## Files
- `Sierra/Auth/ViewModels/LoginViewModel.swift`
- `Sierra/Auth/ViewModels/TwoFactorViewModel.swift`
- `Sierra/Auth/Services/AuthManagerOTPVerificationService.swift`

## Problem

Current flow:
1. `LoginViewModel.signIn()` validates credentials → sets `authState = .requiresTwoFactor`
2. `TwoFactorViewModel.onAppear()` fires → calls `service.sendOTP()` → calls `generateOTP()`
   → calls `sendEmail()` via SwiftSMTP (live TCP connection)
3. Screen shows in `.sending` state — frozen, no digit inputs — until SwiftSMTP completes
4. SwiftSMTP connects, authenticates, sends → `state = .awaitingEntry` → inputs unlock

This SMTP round-trip (3–4 seconds) happens **after** the screen appears, causing the lag.

## Fix — Pre-generate OTP in `LoginViewModel.signIn()` before navigating

### Step 1 — `LoginViewModel.signIn()`: Generate OTP before transition

Generate the OTP immediately after credentials are validated, **before** setting
`authState = .requiresTwoFactor`. SwiftSMTP fires in the background via
`Task.detached` (which `generateOTP()` already uses internally). The screen
transition happens instantly, the email arrives seconds later.

```swift
// In LoginViewModel.signIn(), after getting `role` and building `destination`:

// Generate OTP now — fires SwiftSMTP in background immediately.
// TwoFactorViewModel must NOT call sendOTP() again on appear.
AuthManager.shared.generateOTP()

let context = TwoFactorContext(
    userID: user?.id.uuidString ?? UUID().uuidString,
    role: role,
    method: .email,
    maskedDestination: AuthManager.shared.maskedEmail,
    sessionToken: "",
    authDestination: destination
)

authState = .requiresTwoFactor(context: context)  // screen appears immediately
```

### Step 2 — `AuthManagerOTPVerificationService.sendOTP()`: Return instantly, don't re-generate

When `TwoFactorViewModel.onAppear()` calls `service.sendOTP()`, the OTP has already
been generated and the email is already sending. The service just needs to return
a result immediately without re-generating.

```swift
final class AuthManagerOTPVerificationService: OTPVerificationServiceProtocol {

    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        // OTP was pre-generated in LoginViewModel.signIn() before screen appeared.
        // Do NOT call generateOTP() again here — it would overwrite the sent OTP.
        // Just return the result immediately so TwoFactorViewModel enters awaitingEntry.
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(600),
            cooldownUntil: Date().addingTimeInterval(30)
        )
    }

    func verifyOTP(code: String, context: TwoFactorContext) async throws -> OTPVerifyResult {
        let correct = AuthManager.shared.verifyOTP(code)
        return OTPVerifyResult(
            success: correct,
            attemptsRemaining: correct ? nil : 2,
            isLocked: false,
            lockUntil: nil,
            fullSessionToken: correct ? "sierra_session_\(UUID().uuidString)" : nil
        )
    }

    func resendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        // Resend: generate a new OTP and send fresh email
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        _ = AuthManager.shared.generateOTP()
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt: Date().addingTimeInterval(600),
            cooldownUntil: Date().addingTimeInterval(30)
        )
    }
}
```

### Step 3 — `TwoFactorViewModel.sendOTP()`: No change needed

The existing `onAppear` → `sendOTP()` → `service.sendOTP()` chain is unchanged.
Because `service.sendOTP()` now returns instantly (no SMTP call), `state` transitions
from `.sending` to `.awaitingEntry` in microseconds. The screen appears fully
interactive with zero delay.

`resendCode()` still works correctly — it calls `service.resendOTP()` which does
generate a new OTP and send a fresh email.

## Result

| Before | After |
|---|---|
| Screen appears → `.sending` state → 3–4s SMTP lag → inputs unlock | Credentials validated → OTP email fires in background → screen appears instantly in `.awaitingEntry` |

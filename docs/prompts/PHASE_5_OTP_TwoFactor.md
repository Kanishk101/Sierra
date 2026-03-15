# Phase 5 — OTP / TwoFactor (AuthManager-Based SwiftSMTP OTP)

## Files
- `Sierra/Auth/Services/OTPVerificationService.swift`
- `Sierra/Auth/Services/AuthManagerOTPVerificationService.swift`
- `Sierra/Auth/ViewModels/TwoFactorViewModel.swift`

## What to implement

Switch the entire 2FA OTP flow to use `AuthManagerOTPVerificationService`
as the default conformance — exactly the vinayak pattern.

In vinayak:
- `sendOTP()` calls `AuthManager.shared.generateOTP()` which calls `sendEmail()` via SwiftSMTP
- `verifyOTP()` calls `AuthManager.shared.verifyOTP(code)` — simple in-memory string compare
- No Supabase Auth OTP, no cooldown limits, no 60-second lockouts

---

## `OTPVerificationService.swift` — keep protocol + update mock

Keep the `OTPVerificationServiceProtocol`, `OTPSendResult`, `OTPVerifyResult` types unchanged.

Update `MockOTPVerificationService.verifyOTP()` to call `AuthManager.shared.verifyOTP(code)`
(not the hardcoded `"123456"` string):

```swift
func verifyOTP(code: String, context: TwoFactorContext) async throws -> OTPVerifyResult {
    try await Task.sleep(nanoseconds: 800_000_000)
    let correct = AuthManager.shared.verifyOTP(code)
    if correct {
        attemptsUsed = 0
        return OTPVerifyResult(
            success: true,
            attemptsRemaining: nil,
            isLocked: false,
            lockUntil: nil,
            fullSessionToken: "sierra_session_\(UUID().uuidString)"
        )
    } else {
        attemptsUsed += 1
        let remaining = max(0, 3 - attemptsUsed)
        let locked    = remaining == 0
        return OTPVerifyResult(
            success: false,
            attemptsRemaining: remaining,
            isLocked: locked,
            lockUntil: locked ? Date().addingTimeInterval(900) : nil,
            fullSessionToken: nil
        )
    }
}
```

---

## `AuthManagerOTPVerificationService.swift` — the real implementation

This file already exists. Verify it matches this exactly:

```swift
final class AuthManagerOTPVerificationService: OTPVerificationServiceProtocol {

    func sendOTP(context: TwoFactorContext) async throws -> OTPSendResult {
        guard AuthManager.shared.currentUser != nil else { throw AuthError.userNotFound }
        // generateOTP() now calls sendEmail() internally (Phase 2)
        _ = AuthManager.shared.generateOTP()
        return OTPSendResult(
            success: true,
            maskedDestination: context.maskedDestination,
            expiresAt:      Date().addingTimeInterval(600),
            cooldownUntil:  Date().addingTimeInterval(30)
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
        try await sendOTP(context: context)
    }
}
```

---

## `TwoFactorViewModel.swift` — change default service

In `TwoFactorViewModel.init(context:service:onVerified:onCancelled:)`:

```swift
// BEFORE:
self.service = service ?? SupabaseOTPVerificationService()

// AFTER:
self.service = service ?? AuthManagerOTPVerificationService()
```

Also in the convenience `init(subtitle:maskedEmail:onVerified:onCancelled:)`:

```swift
// BEFORE:
self.init(context: ctx, service: SupabaseOTPVerificationService(), ...)

// AFTER:
self.init(context: ctx, service: AuthManagerOTPVerificationService(), ...)
```

---

## Files to delete (or empty-stub)
- `Sierra/Auth/Services/SupabaseOTPVerificationService.swift` — delete
- `Sierra/Auth/Services/SupabaseAuthService.swift` — delete

These reference `supabase.auth.signInWithOTP()` and `supabase.auth.verifyOTP()`
which are no longer used in this architecture.

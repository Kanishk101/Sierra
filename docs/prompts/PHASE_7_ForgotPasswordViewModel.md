# Phase 7 — ForgotPasswordViewModel.swift (Vinayak Pattern)

## File
`Sierra/Auth/ViewModels/ForgotPasswordViewModel.swift`

## What to implement

This file already largely matches vinayak. Verify and correct the three methods
that call into `AuthManager`:

---

## `sendResetCode()` — verify it calls `requestPasswordReset`

```swift
func sendResetCode() async {
    emailError = nil
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else { emailError = "Email is required"; return }
    guard trimmed.contains("@") && trimmed.contains(".") else {
        emailError = "Enter a valid email address"
        return
    }

    isLoading = true
    let found = await AuthManager.shared.requestPasswordReset(email: trimmed)
    isLoading = false

    if found {
        withAnimation(.easeInOut(duration: 0.3)) { step = .enterCode }
    } else {
        emailError = "No account found with this email"
    }
}
```

`AuthManager.requestPasswordReset()` (Phase 2) now:
1. Queries `staff_members` for email existence
2. Generates OTP in-memory
3. Calls `sendEmail()` via SwiftSMTP
4. Returns `true` if found, `false` if not

---

## `verifyResetCode()` — verify it calls `verifyResetOTP`

```swift
func verifyResetCode() {
    let code = digits.joined()
    guard code.count == 6 else { codeError = "Enter all 6 digits"; return }

    if AuthManager.shared.verifyResetOTP(code) {
        codeError = nil
        withAnimation(.easeInOut(duration: 0.3)) { step = .newPassword }
    } else {
        codeError = "Incorrect code. Please try again."
        withAnimation(.default) { shakeCount += 1 }
    }
}
```

`AuthManager.verifyResetOTP()` is an in-memory string compare against `resetOTP`.
No async, no throws.

---

## `resetPassword()` — verify it calls `AuthManager.resetPassword`

```swift
func resetPassword() async {
    guard canSubmitNewPassword else { return }
    isLoading = true
    errorMessage = nil

    do {
        try await AuthManager.shared.resetPassword(
            code: digits.joined(),
            newPassword: newPassword
        )
        isLoading = false
        withAnimation(.easeInOut(duration: 0.3)) { step = .success }
    } catch {
        isLoading = false
        errorMessage = "Failed to reset password. Please try again."
    }
}
```

`AuthManager.resetPassword()` (Phase 2) now:
1. Verifies OTP in-memory
2. Updates `staff_members.password` directly via `.from("staff_members").update()`
3. Clears `resetOTP` and `pendingOTPEmail`

---

## State and steps — keep as vinayak

```swift
enum ForgotPasswordStep { case enterEmail, enterCode, newPassword, success }

var step: ForgotPasswordStep = .enterEmail
var email: String = ""
var emailError: String?
var digits: [String] = Array(repeating: "", count: 6)
var focusedIndex: Int? = 0
var codeError: String?
var shakeCount: Int = 0
var newPassword: String = ""
var confirmPassword: String = ""
var isLoading: Bool = false
var errorMessage: String?
```

## Computed vars — keep as vinayak
- `maskedEmail`: `AuthManager.shared.maskedEmail`
- `strength`, `hasMinLength`, `hasUppercase`, `hasNumber`, `hasSpecialChar`
- `allRequirementsMet`, `passwordsMatch`, `canSubmitNewPassword`, `confirmPasswordError`
- `goBack()` navigation helper

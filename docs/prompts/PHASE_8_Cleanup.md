# Phase 8 — Cleanup

## What to delete or stub out

These files are no longer needed after Phases 2-7 are complete.

---

### Delete completely

**`Sierra/Auth/Services/SupabaseOTPVerificationService.swift`**
Was the production OTP service using `supabase.auth.signInWithOTP()`.
Replaced by `AuthManagerOTPVerificationService` (SwiftSMTP).

**`Sierra/Auth/Services/SupabaseAuthService.swift`**
Thin wrapper around Supabase Auth SDK (`signIn`, `signOut`, `sendOTP`, `verifyOTP`,
`updatePassword`, `resetPasswordForEmail`). None of these calls are used anymore.

---

### Replace with empty stub or delete

**`Sierra/Shared/Services/AuthUserService.swift`**
Was retargeted to `staff_members` but is now fully superseded by:
- `StaffMemberService` (for all staff CRUD)
- `AuthManager` (for all auth operations)
Mark the file with a deprecation comment or delete it entirely.
If any call site still references it, update that call site to use
the appropriate replacement before deleting.

---

### Keep but verify

**`Sierra/Auth/Services/AuthManagerOTPVerificationService.swift`**
Keep. This is now the production OTP service.

**`Sierra/Auth/Services/OTPVerificationService.swift`**
Keep protocol + `MockOTPVerificationService`. Delete `SupabaseOTPVerificationService`
from this file if it was defined here rather than in a separate file.

**`Sierra/Shared/Services/StaffApplicationStore.swift`**
Already a deprecation stub. Leave as-is.

---

## After cleanup — verify these compile with zero errors

1. `AuthManager.swift` — no `import Supabase` Auth SDK calls remaining
2. `CreateStaffViewModel.swift` — no reference to `AuthManager.createStaffAccount()`
3. `TwoFactorViewModel.swift` — uses `AuthManagerOTPVerificationService` as default
4. `ForcePasswordChangeViewModel.swift` — `awaitingOTP` drives navigation, not `readyToNavigate`
5. `ForgotPasswordViewModel.swift` — all three steps call into `AuthManager` correctly
6. `StaffMemberService.swift` — `addStaffMember(_:password:)` includes password param

---

## Summary of architecture after all 8 phases

| Concern | Implementation |
|---|---|
| Staff creation | UUID client-side → `StaffMemberService.addStaffMember(staff, password:)` → `EmailService.sendCredentials()` |
| Login | `staff_members` query by email + plaintext password compare |
| 2FA OTP send | `AuthManager.generateOTP()` → `sendEmail()` SwiftSMTP |
| 2FA OTP verify | `AuthManager.verifyOTP()` in-memory string compare |
| Password reset | `staff_members` email check → OTP SwiftSMTP → `staff_members.password` update |
| First login change | `staff_members.password` + `is_first_login` update directly |
| Supabase Auth SDK | Used ONLY for the fleet manager's initial account (existing `auth.users` row) |
| RPC | Not used anywhere |
| Edge Functions | Not used anywhere |

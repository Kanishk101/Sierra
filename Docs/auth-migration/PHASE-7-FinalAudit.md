# Phase 7 — Final Audit & Cleanup

> **Depends on:** Phases 1–6 all complete and building.

---

## Purpose

A complete sweep of every Swift file and every edge function to confirm
zero stale references to the old plain-text password system survive.
This is the gate before shipping.

---

## Exact prompt — paste into Cursor

```
Perform a full codebase audit of the Sierra Xcode project to confirm the
Supabase Auth migration is complete. Check every .swift file and every
TypeScript edge function file in supabase/functions/.

────────────────────────────────────────────────
SEARCH 1 — staff_members password column references
────────────────────────────────────────────────

Search all .swift files for the literal string "password".

For each match, classify it as one of these ALLOWED uses:
  A) supabase.auth.signInWithPassword(        ← Auth SDK, allowed
  B) supabase.auth.update(user: UserAttributes(password:  ← Auth SDK, allowed
  C) CryptoService.hash(password:             ← biometric cache, allowed
  D) KeychainService.save(hashed, forKey:     ← keychain, allowed
  E) UserAttributes(password:                 ← Auth SDK, allowed
  F) FunctionInvokeOptions(body: ResetPayload(... new_password: ← edge fn, allowed
  G) A comment explaining the migration       ← allowed
  H) AuthError enum cases                     ← allowed
  I) Function parameter names (newPassword:, password:) ← allowed in function sigs

Flag as FORBIDDEN (must be removed):
  X) Any Encodable struct field `let password: String` used for staff_members
  Y) .update(["password": ...]) or .update(SomeStruct(password:...)) against staff_members
  Z) .select("..., password, ...") against staff_members
  W) .eq("password", ...) against staff_members

For each FORBIDDEN match: show the file + line, explain what it is,
and apply the fix (remove it or refactor to use AuthManager).

────────────────────────────────────────────────
SEARCH 2 — dropped column references
────────────────────────────────────────────────

Search all .swift files for:
  failed_login_attempts
  account_locked_until

These columns no longer exist. Any occurrence must be removed.

────────────────────────────────────────────────
SEARCH 3 — deleted structs
────────────────────────────────────────────────

Search all .swift files for:
  StaffLoginRow
  SignInPayload

Both were deleted in Phase 1. If found anywhere, remove them.

────────────────────────────────────────────────
SEARCH 4 — edge function audit
────────────────────────────────────────────────

Check supabase/functions/create-staff-account/index.ts:
  - The staff_members insert must have NO `password` key.
  - auth.admin.createUser({ email, password, email_confirm: true }) is CORRECT — keep it.

Check supabase/functions/sign-in/index.ts:
  - Must have NO .eq("password", ...) call.
  - Must have NO .select("..., password, ...") call.
  - Must call anonClient.auth.getUser() to get auth.uid() from the JWT.
  - Must fetch staff profile by user ID, not by email+password.

Check supabase/functions/reset-password/index.ts (if exists):
  - Must call admin.auth.admin.updateUserById(userId, { password: new_password }).
  - Must NOT call supabase.from("staff_members").update({password: ...}).
  - Must validate the token from password_reset_tokens before updating.

────────────────────────────────────────────────
SEARCH 5 — hardcoded credential strings
────────────────────────────────────────────────

Search all .swift files for these literal strings:
  "Sierra@123"
  "Admin@123"
  "Driver@123"
  "Driver@1234"
  "Main@123"
  "DRP#H4Yfnxwe"

If found in preview providers or test helpers, wrap in:
  #if DEBUG
  // Preview/test credential — never ship to production
  #endif

If found outside DEBUG guards in production code paths, remove entirely.

────────────────────────────────────────────────
FINAL BUILD + SMOKE TEST
────────────────────────────────────────────────

After all fixes:

1. Build the project — zero errors, zero new warnings.

2. Run on simulator and test all three roles:
   a) Fleet Manager:
      - Login → Fleet Manager dashboard loads
      - Create a new driver account → no 400 error
      - Logout → back to Login
   b) Driver (existing, is_first_login: false):
      - Login → Driver dashboard loads
      - Change password (Settings) → re-login with new password works
   c) Driver (is_first_login: true):
      - Login → ForcePasswordChangeView appears
      - Change password → routed to onboarding or dashboard correctly
   d) Forgot Password flow:
      - Enter email → OTP arrives in email
      - Enter OTP → enter new password → success
      - Login with new password → works
      - Attempt to reuse same OTP → rejected

3. Confirm in Supabase dashboard (Sierra-FMS-v2 project):
   - Table Editor → staff_members:
     NO columns named password, failed_login_attempts, account_locked_until
   - Authentication → Users:
     All 13 users present, all have a non-empty email
   - Edge Functions:
     sign-in → Active, verify_jwt: true
     reset-password → Active, verify_jwt: false
     create-staff-account → Active, verify_jwt: true
     check-resource-overlap → Active, verify_jwt: true
```

---

## Final migration checklist

- [ ] Phase 1: `AuthManager.swift` rewritten — `StaffLoginRow`, `SignInPayload` gone
- [ ] Phase 2: `create-staff-account` insert has no password field; `StaffMemberService` cleaned
- [ ] Phase 3: `resetPassword()` calls edge fn; `requestPasswordReset()` inserts token; `ForgotPasswordView` clean
- [ ] Phase 4: `password_reset_tokens` table created; `reset-password` edge fn deployed
- [ ] Phase 5: `ChangePasswordView` + `ForcePasswordChangeView` delegate to `AuthManager` only
- [ ] Phase 6: `restoreSession()`, `restoreSessionSilently()`, `reauthCompleted()` prime SDK session
- [ ] Phase 7: Full audit passed — zero forbidden password references anywhere
- [ ] Build: zero errors, zero new warnings
- [ ] Smoke test: all 3 roles login, password change, forgot password all work
- [ ] Supabase dashboard: staff_members has no password column
- [ ] Supabase dashboard: all 13 auth.users present with encrypted_password set

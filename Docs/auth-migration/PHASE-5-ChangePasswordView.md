# Phase 5 — Fix `ChangePasswordView.swift` + `ForcePasswordChangeView.swift`

> **Depends on:** Phase 1 complete and building.

---

## Context

These two views handle password changes:
- `ForcePasswordChangeView` — shown on first login (`is_first_login: true`)
- `ChangePasswordView` — accessible from Settings for any user

After Phase 1, `AuthManager.updatePasswordAndFirstLogin()` and
`AuthManager.updatePassword()` are both correct — they update only
`is_first_login` in staff_members and call `supabase.auth.update()` for
the Supabase Auth password.

The risk is either view directly constructing a Supabase update payload
that includes a `password` field for staff_members, which would now cause
a 400 from PostgREST.

---

## Exact prompt — paste into Cursor

```
Audit and fix Sierra/Auth/ChangePasswordView.swift and
Sierra/Auth/ForcePasswordChangeView.swift.

Context:
  - staff_members.password has been DROPPED from the database.
  - Sending `password` in any PostgREST call against staff_members causes a 400.
  - AuthManager.updatePasswordAndFirstLogin(newPassword:) is the correct way
    to change a password. After Phase 1 it:
      a) Updates staff_members.is_first_login = false (no password field)
      b) Calls supabase.auth.update(user: UserAttributes(password: newPassword))
  - AuthManager.updatePassword(_:) delegates to updatePasswordAndFirstLogin.
    Both are correct and should be the only password-change paths.

For EACH of the two view files, do the following:

────────────────────────────────────────────────
SEARCH & REMOVE
────────────────────────────────────────────────

1. Find any call to supabase.from("staff_members").update(...) that
   includes a `password` field or key. REMOVE the entire call if password
   is the only field being updated. If other fields are being updated in
   the same call, remove only the password key-value from the payload.

2. Find any locally-defined Encodable struct (e.g. PasswordPayload,
   UpdatePayload, etc.) that contains `let password: String` and is used
   for a staff_members DB write. REMOVE such structs entirely.

3. Find any supabase.from("staff_members").update(["password": newPassword])
   dictionary-style calls. REMOVE entirely.

────────────────────────────────────────────────
ENSURE CORRECT DELEGATION
────────────────────────────────────────────────

4. The "Change Password" / "Save" button action in each view must call
   one of these and nothing else for the password update:

     try await authManager.updatePasswordAndFirstLogin(newPassword: newPassword)
   or
     try await authManager.updatePassword(newPassword)

   If the view was calling both a direct DB update AND authManager, remove
   the direct DB call and keep only the authManager call.

5. Error handling: wrap the authManager call in do/catch. On catch, show
   an error alert with a user-friendly message. Do not swallow errors silently.

────────────────────────────────────────────────
DO NOT CHANGE
────────────────────────────────────────────────

- Any UI layout, styling, colors, or fonts
- Password validation logic (minimum length, confirmation match check)
- Navigation / routing after successful password change
- The `authManager.markPasswordChanged()` call if present
- Any calls to `authManager.markProfileComplete()` if present
```

---

## Build verification

- [ ] `ChangePasswordView.swift` has no `supabase.from("staff_members")` password write
- [ ] `ForcePasswordChangeView.swift` has no `supabase.from("staff_members")` password write
- [ ] Both views delegate to `authManager.updatePasswordAndFirstLogin()` or `authManager.updatePassword()`
- [ ] Build succeeds — zero errors
- [ ] Smoke test: log in as driver with `is_first_login: true` → forced change → redirected correctly → re-login with new password works

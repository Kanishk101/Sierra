# Phase 1 — Rewrite `AuthManager.swift`

> **Supabase pre-conditions (already done — do not redo):**
> - All 13 `auth.users` bcrypt-synced ✅
> - `staff_members.password`, `failed_login_attempts`, `account_locked_until` dropped ✅
> - `sign-in` edge function v2 live (`verify_jwt: true`, profile-fetch only) ✅
>
> **Start here when opening Cursor.**

---

## What changed on the backend

| Before | After |
|---|---|
| `signIn()` called `sign-in` edge fn v1 (credential check + sync) | `sign-in` edge fn v2 just fetches the profile row using the live JWT |
| `sign-in` edge fn queried `staff_members.password` | `staff_members.password` column **does not exist** |
| Credentials in two places (staff_members + auth.users) | Credentials **only** in `auth.users` (bcrypt) |
| `Payload` struct had `password: String` for DB updates | **No** password in any staff_members update |

---

```
Rewrite Sierra/Auth/AuthManager.swift for full Supabase Auth.
The Supabase backend has been migrated:
  - staff_members.password is DROPPED.
  - staff_members.failed_login_attempts is DROPPED.
  - staff_members.account_locked_until is DROPPED.
  - sign-in edge function is now v2 (verify_jwt: true). It takes NO body,
    reads auth.uid() from the JWT, and returns the staff profile row:
    { id, email, name, role, is_first_login, is_profile_complete,
      is_approved, rejection_reason, phone, created_at }
    It does NOT accept credentials — it is a profile-fetch only.

Apply ALL of the following changes. Do not change anything not listed.

────────────────────────────────────────────────
1. DELETE these private structs — no longer needed:
   - StaffLoginRow
   - SignInPayload
────────────────────────────────────────────────

────────────────────────────────────────────────
2. REWRITE func signIn(email: String, password: String) async throws -> UserRole
────────────────────────────────────────────────

New implementation (replace the entire function body):

  func signIn(email: String, password: String) async throws -> UserRole {
      otpLastSentAt = nil

      // Step 1 — Authenticate with Supabase Auth (bcrypt, server-side)
      do {
          try await supabase.auth.signInWithPassword(
              email: email,
              password: password
          )
      } catch {
          throw AuthError.invalidCredentials
      }

      // Step 2 — Fetch staff profile via edge function (JWT now live)
      struct StaffProfile: Decodable {
          let id: String
          let email: String
          let name: String?
          let role: String
          let is_first_login: Bool?
          let is_profile_complete: Bool?
          let is_approved: Bool?
          let rejection_reason: String?
          let phone: String?
          let created_at: String?
      }

      let profile: StaffProfile
      do {
          profile = try await supabase.functions.invoke(
              "sign-in",
              options: FunctionInvokeOptions()
          )
      } catch {
          // Auth succeeded but profile fetch failed — roll back
          try? await supabase.auth.signOut()
          throw AuthError.invalidCredentials
      }

      guard let userId = UUID(uuidString: profile.id) else {
          try? await supabase.auth.signOut()
          throw AuthError.invalidCredentials
      }

      let user = AuthUser(
          id: userId,
          email: profile.email,
          role: UserRole(rawValue: profile.role) ?? .driver,
          isFirstLogin: profile.is_first_login ?? true,
          isProfileComplete: profile.is_profile_complete ?? false,
          isApproved: profile.is_approved ?? false,
          name: profile.name,
          rejectionReason: profile.rejection_reason,
          phone: profile.phone,
          createdAt: ISO8601DateFormatter().date(from: profile.created_at ?? "") ?? Date()
      )

      // Hash is kept for biometric reauth caching only — NOT used for Supabase Auth
      let hashed = CryptoService.hash(password: password)
      _ = KeychainService.save(hashed, forKey: Keys.hashedCred)
      _ = KeychainService.save(user, forKey: Keys.currentUser)

      currentUser = user
      pendingOTPEmail = user.email
      // Do NOT set isAuthenticated here — 2FA must complete first
      return user.role
  }

────────────────────────────────────────────────
3. UPDATE func updatePasswordAndFirstLogin(newPassword: String) async throws
────────────────────────────────────────────────

Change the Payload struct to:
  struct Payload: Encodable { let is_first_login: Bool }

Change the update call to:
  try await supabase
      .from("staff_members")
      .update(Payload(is_first_login: false))
      .eq("id", value: user.id.uuidString)
      .execute()

KEEP the Supabase Auth sync line exactly as-is:
  try await supabase.auth.update(user: UserAttributes(password: newPassword))

KEEP all Keychain saves. KEEP user.isFirstLogin = false mutation.
Do NOT change anything else in this function.

────────────────────────────────────────────────
4. UPDATE func resetPassword(code: String, newPassword: String) async throws
────────────────────────────────────────────────

REMOVE the entire staff_members update block:
  try await supabase.from("staff_members").update(["password": newPassword])...

KEEP the rest of the function body exactly:
  try await Task.sleep(for: .milliseconds(600))
  guard code == resetOTP else { throw AuthError.invalidCredentials }
  guard let email = pendingOTPEmail else { throw AuthError.invalidCredentials }
  let hashed = CryptoService.hash(password: newPassword)
  _ = KeychainService.save(hashed, forKey: Keys.hashedCred)
  resetOTP = ""
  pendingOTPEmail = nil

ADD a comment above the function:
  // NOTE: Supabase Auth password is updated by the reset-password edge
  // function (Phase 3). The next signIn() call will authenticate with
  // the new password via supabase.auth.signInWithPassword().

────────────────────────────────────────────────
5. UPDATE the comment block before updatePasswordAndFirstLogin
────────────────────────────────────────────────

Replace any existing IMPORTANT comment about "two password sources" with:
  // Passwords are managed exclusively by Supabase Auth (bcrypt).
  // CryptoService.hash is used only for local biometric reauth caching.
  // staff_members has no password column.

────────────────────────────────────────────────
6. signOut() — already correct. Confirm it has:
   Task { try? await supabase.auth.signOut() }
   If missing, add it.
────────────────────────────────────────────────

Do NOT change: AuthError, AuthDestination, completeAuthentication,
restoreSession, restoreSessionSilently, hasSessionToken, destination,
maskedEmail, generateOTP, verifyOTP, verifyResetOTP, markProfileComplete,
markPasswordChanged, refreshCurrentUser, requestPasswordReset,
emailExists, appDidEnterBackground, appWillEnterForeground, reauthCompleted.
```

---

## Build verification

After Applying the changes, confirm:

- [ ] Build succeeds — zero errors
- [ ] `StaffLoginRow` struct is gone
- [ ] `SignInPayload` struct is gone
- [ ] `signIn()` calls `supabase.auth.signInWithPassword()` before the edge function
- [ ] `updatePasswordAndFirstLogin` Payload struct has only `is_first_login: Bool`
- [ ] No `.update(["password":` against staff_members anywhere
- [ ] No `.eq("password",` against staff_members anywhere
- [ ] `resetPassword` has no `supabase.from("staff_members").update` call

# Phase 6 — Session Restore, Biometric Reauth & Auto-Lock

> **Depends on:** Phase 1 complete and building.

---

## Context

After Phase 1, `signIn()` calls `supabase.auth.signInWithPassword()` which
causes the Supabase Swift SDK to persist the JWT session (access token +
refresh token) in its own internal storage automatically.

The problem: `AuthManager.restoreSession()` only restores the `AuthUser`
from our own Keychain but does **not** interact with the Supabase SDK session.
On cold launch, `auth.uid()` may be null until the SDK's internal session
is verified — meaning the first RLS query after a cold launch can fail.

The SDK refreshes tokens automatically when they are close to expiry, but
only if its internal session is primed. This phase adds that priming.

---

## Exact prompt — paste into Cursor

```
Fix session restore in Sierra/Auth/AuthManager.swift so the Supabase
SDK JWT session is always valid after a cold launch, foreground restore,
or biometric reauth.

Context:
  - supabase.auth.signInWithPassword() is called on every explicit login.
    The Supabase Swift SDK persists the session (access + refresh tokens)
    automatically in its own internal storage (separate from our Keychain).
  - AuthManager.restoreSession() restores AuthUser from our Keychain but
    does not touch the SDK session — so auth.uid() may be null on cold launch
    until the SDK verifies its stored tokens.
  - supabase.auth.session is an async property that returns the current
    valid session (refreshing if needed) or throws if no session exists.

Apply these targeted changes to AuthManager.swift only:

────────────────────────────────────────────────
1. In func restoreSession() -> UserRole?
────────────────────────────────────────────────

After the existing block that sets currentUser and isAuthenticated = true,
add a background Task to verify the SDK session:

  Task {
    do {
      // Prime the SDK session so auth.uid() is populated for RLS.
      // This also triggers a token refresh if the access token is close
      // to expiry. If the session is fully expired/gone, force re-login.
      _ = try await supabase.auth.session
    } catch {
      // SDK has no valid session (e.g. token revoked, app reinstalled).
      // Wipe our cached state and send the user back to Login.
      await MainActor.run { self.signOut() }
    }
  }

Place this Task immediately after the line `isAuthenticated = true`,
before the existing Task that calls AppDataStore.

────────────────────────────────────────────────
2. In func restoreSessionSilently() (called from init)
────────────────────────────────────────────────

After the existing `if let user = ...` block, add:

  // Pre-prime the SDK session in the background so auth.uid() is set
  // before the first DB query (which may happen before restoreSession is called).
  Task { _ = try? await supabase.auth.session }

────────────────────────────────────────────────
3. In func reauthCompleted()
────────────────────────────────────────────────

After `needsReauth = false`, add:

  // Re-prime SDK session after biometric unlock to ensure auth.uid() is set.
  Task { _ = try? await supabase.auth.session }

────────────────────────────────────────────────
DO NOT CHANGE
────────────────────────────────────────────────

- BiometricManager.swift
- BiometricLockView.swift
- BiometricEnrollmentSheet.swift
- AppLifecycleMonitor.swift
- The Keychain logic or CryptoService
- The AppDataStore loading Tasks already in restoreSession()
- Any other function not listed above
```

---

## Build verification

- [ ] Build succeeds — zero errors, zero new warnings
- [ ] Kill app → relaunch → user lands on dashboard (not Login) if within JWT lifetime
- [ ] Kill app → relaunch after token expiry → user redirected to Login (signOut() called)
- [ ] After biometric unlock → first DB query succeeds (dashboard data loads)
- [ ] `restoreSessionSilently()` has the background Task for SDK pre-priming
- [ ] `reauthCompleted()` has the re-prime Task

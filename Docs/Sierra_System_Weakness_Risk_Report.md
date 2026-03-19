# Sierra System Weakness & Risk Report

Repository audited: `https://github.com/Kanishk101/Sierra`  
Branch audited: `main`  
Pinned commit: `671a3338424298568971a8b1bb45e7edf6a92804`  
Backend audited: `Sierra-FMS-v2` (`https://ldqcdngdlbbiojlnbnjg.supabase.co`) via provided anon key (read-only probing)

Live probe highlights (read-only):
- REST table probes for critical tables returned HTTP `200` with empty arrays.
- RPC `check_resource_overlap` returned HTTP `401` (`permission denied for function check_resource_overlap`).
- Edge function probes:
  - `sign-in` -> `401 Unauthorized`
  - `create-staff-account` -> `401 Invalid caller session`
  - `reset-password` -> `400 Missing fields` (publicly callable endpoint)
  - `send-email` -> `400 Missing required fields` (publicly callable endpoint)
  - `check-resource-overlap` -> `400 Missing required fields` (publicly callable endpoint)
  - `notify-fleet-manager` -> `404 Requested function was not found`

## Evidence Baseline & Trace Matrix

Core subsystem entrypoints inspected:
- Auth/session: `AuthManager`, `LoginViewModel`, `TwoFactorViewModel`, `AuthManagerOTPVerificationService`
- Realtime/state: `AppDataStore`, `RealtimeSubscriptionManager`, `NotificationService`
- Navigation/location: `TripNavigationCoordinator`, `TripNavigationView`, `VehicleLocationService`
- Maintenance execution: `MaintenanceTaskDetailView` (no dedicated detail ViewModel present)
- Backend adapters: service layer files using `.from(...)`, edge functions, migrations

Trace matrix (selected high-risk paths):
- `LoginViewModel -> AuthManager.signIn -> functions/sign-in -> staff_members`
- `LoginViewModel/TwoFactorViewModel -> AuthManagerOTPVerificationService -> AuthManager.verifyOTP` (client-local)
- `TripService.checkOverlap -> functions/check-resource-overlap -> rpc(check_resource_overlap)`
- `TripNavigationCoordinator.startLocationPublishing -> VehicleLocationService.publishLocation -> vehicle_location_history + vehicles`
- `AppDataStore` channels: `emergency_alerts`, `staff_members`, `vehicles`, `trips`
- `RealtimeSubscriptionManager` channels: `vehicle_location_history`, `route_deviation_events`, `geofence_events`, `vehicles`, `maintenance_tasks`, `notifications`
- `NotificationService.subscribeToNotifications -> notifications`

---

## Critical Issues (Must Fix Immediately)

1. Client-side OTP verification is trusted for login 2FA.
2. Public password-reset/email edge endpoints are callable without JWT and have no visible server-side abuse controls in repo.
3. Overlap-check protection path is currently broken (`check_resource_overlap` denied), allowing scheduling logic degradation/fallback risk.
4. Session restore/auth gating uses local random token state independent of Supabase session validity windows.
5. Realtime architecture is split across two managers, creating duplicate/lost/stale update risk during real usage.

## High Risk Issues

1. Sensitive auth workflow integrity is partially implemented but not wired to DB-backed `two_factor_sessions`.
2. Temporary staff passwords are emailed in plaintext.
3. Password-reset token creation swallows DB failures and can produce inconsistent reset UX/state.
4. AppDataStore subscribes channels at singleton init (before explicit authenticated lifecycle binding).
5. Navigation route build is one-shot and can fail permanently for a session after transient API/network issues.

## Medium Risk Issues

1. Vehicle location throttling is global per app instance, not keyed by vehicle/trip/driver.
2. Maintenance task completion/start logic lives in a SwiftUI View instead of a ViewModel/service orchestration layer.
3. Missing Supabase metadata/config and migration coverage in repo creates schema-policy drift risk.
4. Notification subscription state uses one boolean gate and can leak stale state across user-role/session transitions.
5. Realtime event handlers perform refetch-per-event patterns that may not scale under high update rates.

## Low Risk Issues

1. Hardcoded anon key in source increases operational/key-rotation friction.
2. `notify-fleet-manager` deployment mismatch (`404`) indicates environment drift and broken alerting path.

---

## Detailed Findings

### Issue 1 — Client-Side 2FA Trust Boundary Collapse
**Description**  
Login OTP verification succeeds based on client-held OTP state and local comparison instead of server-validated session state.

**Root Cause**  
OTP generation/verification is maintained in app memory (`currentOTP`) and verified in client code.

**Where it exists (file/service/table)**  
- `Sierra/Auth/AuthManager.swift` (`generateOTP`, `verifyOTP`)  
- `Sierra/Auth/Services/AuthManagerOTPVerificationService.swift` (`verifyOTP`)  
- `Sierra/Auth/ViewModels/TwoFactorViewModel.swift` (accepts service success, stores session token locally)

**Why it is dangerous**  
An attacker with app instrumentation/runtime tampering can bypass OTP checks and force authenticated state transitions without server challenge validation.

**Exact fix (code-level or DB-level)**  
- Make `two_factor_sessions` authoritative:
  - Create server session row with hashed OTP + expiry + attempts.
  - Verify OTP via secured RPC/edge function only.
  - Return signed ephemeral proof bound to user/session.
- Remove client-side truth source (`currentOTP`) for auth decisions.

---

### Issue 2 — Publicly Callable Reset/Email Endpoints Without Evidence of Abuse Controls
**Description**  
`reset-password` and `send-email` functions are reachable without JWT (observed via live probe returning field-validation errors, not auth rejection).

**Root Cause**  
Functions are intentionally configured with `verify_jwt: false` and code shows no rate-limit/CAPTCHA/IP throttle/anti-automation controls.

**Where it exists (file/service/table)**  
- `supabase/functions/reset-password/index.ts`  
- `supabase/functions/send-email/index.ts`  
- `Sierra/Shared/Services/EmailService.swift` invokes `send-email`

**Why it is dangerous**  
Enables abuse channels (email spam, reset brute force pressure, denial-by-traffic) even when reset tokens are validly enforced.

**Exact fix (code-level or DB-level)**  
- Add mandatory abuse protections in edge functions:
  - IP+email rate limiting (Redis/upstash or DB-backed throttle table).
  - CAPTCHA or signed nonce for public calls.
  - Cooldown windows + lockout responses with no account enumeration leakage.
- Consider `verify_jwt: true` for non-public email workflows.

---

### Issue 3 — Overlap Guard Path Broken in Production Behavior
**Description**  
Live RPC test on `check_resource_overlap` returns permission denied, while app scheduling flow depends on this check.

**Root Cause**  
Runtime privilege/execute grants or function ownership/search path posture do not match app assumptions.

**Where it exists (file/service/table)**  
- `Sierra/Shared/Services/TripService.swift` (`checkOverlap`)  
- `supabase/migrations/20260315000002_add_overlap_check_fn.sql` (function + grants)  
- Live backend RPC response: `401 permission denied for function check_resource_overlap`

**Why it is dangerous**  
Resource conflict prevention can silently fail, increasing double-booking race risk for driver/vehicle assignment.

**Exact fix (code-level or DB-level)**  
- Reconcile function ownership/grants on live DB:
  - Verify `GRANT EXECUTE` for actual role path used by edge/app.
  - Explicitly set secure `search_path` in SECURITY DEFINER function.
- In app, hard-fail scheduling on overlap-check errors (no permissive fallback).

---

### Issue 4 — Session Gating Uses Local Random Token, Not Supabase Session Authority
**Description**  
Authentication restore decisions rely on locally generated keychain token (`UUID`) as primary gate.

**Root Cause**  
`saveSessionToken()` writes random token unrelated to Supabase refresh/access token lifecycle.

**Where it exists (file/service/table)**  
- `Sierra/Auth/AuthManager.swift` (`saveSessionToken`, `hasSessionToken`, `restoreSession`)
- `Sierra/Auth/ViewModels/LoginViewModel.swift` biometric path checks `hasSessionToken()`

**Why it is dangerous**  
Can produce stale or inconsistent auth state under session expiry/revocation/multi-device changes.

**Exact fix (code-level or DB-level)**  
- Remove custom random session token as auth authority.
- Gate exclusively on Supabase session + refresh validity (`auth.session`, refresh outcome).
- Persist only minimal local lock state separate from auth truth.

---

### Issue 5 — Realtime Lifecycle Fragmentation and Duplicate Streams
**Description**  
Both `AppDataStore` and `RealtimeSubscriptionManager` manage realtime channels over overlapping domains (`vehicles`, `notifications`, etc.).

**Root Cause**  
No single owner/lifecycle for channels; mixed startup points and mixed unsubscribe semantics.

**Where it exists (file/service/table)**  
- `Sierra/Shared/Services/AppDataStore.swift` (channels in singleton init + notification subscription gate)
- `Sierra/Shared/Services/RealtimeSubscriptionManager.swift` (separate start/stop system)
- `Sierra/Auth/AuthManager.swift` currently does not orchestrate `RealtimeSubscriptionManager.startAll/stopAll`

**Why it is dangerous**  
Risk of duplicate event processing, stale state after user switches, missed updates, and memory/channel leaks.

**Exact fix (code-level or DB-level)**  
- Choose one realtime owner (recommended: `RealtimeSubscriptionManager`).
- Start/stop strictly on auth lifecycle hooks.
- Remove overlapping channel logic from `AppDataStore` or convert to passive state sink only.

---

### Issue 6 — DB-backed 2FA Service Exists but Is Not Actually Wired
**Description**  
`TwoFactorSessionService` exists but active 2FA path uses client OTP service instead.

**Root Cause**  
Dependency injection defaults to `AuthManagerOTPVerificationService`; no production path to DB session verification.

**Where it exists (file/service/table)**  
- `Sierra/Shared/Services/TwoFactorSessionService.swift`
- `Sierra/Auth/ViewModels/LoginViewModel.swift`
- `Sierra/Auth/ViewModels/TwoFactorViewModel.swift`

**Why it is dangerous**  
Creates false confidence: secure model exists in codebase but is bypassed in runtime behavior.

**Exact fix (code-level or DB-level)**  
- Replace default OTP service with server-backed verifier.
- Add integration tests asserting `two_factor_sessions` rows are created, incremented, locked, and verified.

---

### Issue 7 — Temporary Passwords Sent in Plaintext Email
**Description**  
Staff onboarding emails include generated plaintext password.

**Root Cause**  
Credential bootstrap design sends password value in email body.

**Where it exists (file/service/table)**  
- `Sierra/FleetManager/ViewModels/CreateStaffViewModel.swift`
- `Sierra/Shared/Services/EmailService.swift` (`sendCredentials`)

**Why it is dangerous**  
Email channel compromise or mailbox compromise leaks account credentials.

**Exact fix (code-level or DB-level)**  
- Replace plaintext password email with one-time activation link/reset flow.
- Force password set through signed token + short expiry.

---

### Issue 8 — Password Reset Token Insert Failure Is Silently Ignored
**Description**  
Reset flow may report success while token persistence failed.

**Root Cause**  
`try?` on token insert discards DB error.

**Where it exists (file/service/table)**  
- `Sierra/Auth/AuthManager.swift` (`requestPasswordReset`, token insert block)
- `public.password_reset_tokens`

**Why it is dangerous**  
Creates inconsistent UX and support burden; also obscures monitoring for reset failures.

**Exact fix (code-level or DB-level)**  
- Remove `try?`; enforce explicit error handling and user-visible failure.
- Add structured telemetry on reset token write outcomes.

---

### Issue 9 — AppDataStore Subscribes Realtime Before Auth-Bound Context
**Description**  
Store singleton subscribes in `init`, independent of authenticated user lifecycle.

**Root Cause**  
Constructor side effects create channels immediately.

**Where it exists (file/service/table)**  
- `Sierra/Shared/Services/AppDataStore.swift` (`private init()`)

**Why it is dangerous**  
Background unauthorized churn, channel duplication on auth transitions, and wrong-user state contamination.

**Exact fix (code-level or DB-level)**  
- Remove subscription side effects from initializer.
- Bind all subscribe/unsubscribe operations to authenticated user identity transitions.

---

### Issue 10 — Route Build Is One-Shot, No Retry After Transient Failure
**Description**  
`hasBuiltRoutes` flips before successful route acquisition; failed call can permanently block rebuild in that session unless manually reset via add-stop path.

**Root Cause**  
Guard flag set too early and not reverted on failure.

**Where it exists (file/service/table)**  
- `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift` (`buildRoutes`)

**Why it is dangerous**  
Navigation can remain unavailable after transient network/API errors.

**Exact fix (code-level or DB-level)**  
- Set `hasBuiltRoutes = true` only after successful route assignment.
- Add bounded retry/backoff and explicit user-triggered retry action.

---

### Issue 11 — Vehicle Location Throttle Is Global and Not Context-Keyed
**Description**  
Single `lastPublishTime` controls all publish events regardless of vehicle/trip/driver context.

**Root Cause**  
Throttle state is instance-global, not scoped.

**Where it exists (file/service/table)**  
- `Sierra/Shared/Services/VehicleLocationService.swift`

**Why it is dangerous**  
Concurrent trips (or rapid context switch) can suppress legitimate location updates or cause cross-context timing interference.

**Exact fix (code-level or DB-level)**  
- Key throttle by `(driverId, tripId, vehicleId)`.
- Add server-side dedupe constraints/index strategy for high-frequency writes.

---

### Issue 12 — Maintenance Task Detail Performs Business/Data Ops in View Layer
**Description**  
View directly orchestrates work-order creation, status transitions, storage uploads, and notifications.

**Root Cause**  
Missing dedicated `MaintenanceTaskDetailViewModel`.

**Where it exists (file/service/table)**  
- `Sierra/Maintenance/Views/MaintenanceTaskDetailView.swift`
- Absence in `Sierra/Maintenance/ViewModels/` (no `MaintenanceTaskDetailViewModel.swift`)

**Why it is dangerous**  
Harder to test, easier to regress, and greater chance of inconsistent transactional behavior.

**Exact fix (code-level or DB-level)**  
- Introduce `MaintenanceTaskDetailViewModel` to own async orchestration/state transitions.
- Keep View purely declarative UI.

---

### Issue 13 — Migration/Policy Source of Truth Is Incomplete in Repo
**Description**  
Repo has only four migration SQL files while app references many critical tables/functions/channels; no local policy snapshot/config is tracked.

**Root Cause**  
Schema/policy history not fully exported/versioned in repository.

**Where it exists (file/service/table)**  
- `supabase/migrations/*.sql` (4 files only)
- No tracked supabase config/policy export file in repo

**Why it is dangerous**  
Environment drift and unknown RLS/function posture in production; harder incident recovery/audit.

**Exact fix (code-level or DB-level)**  
- Export and commit full migration chain and policy/function definitions.
- Add CI drift check against live schema hash.

---

### Issue 14 — Notification Subscription State Is Sticky Across Session Changes
**Description**  
`isSubscribedToNotifications` gate can block proper re-subscription after role/user transitions.

**Root Cause**  
Single boolean flag without strong identity binding.

**Where it exists (file/service/table)**  
- `Sierra/Shared/Services/AppDataStore.swift` (`isSubscribedToNotifications`, `loadAndSubscribeNotifications`)

**Why it is dangerous**  
Missed notifications or cross-user stale data in long-lived app sessions.

**Exact fix (code-level or DB-level)**  
- Track current subscribed user ID and force unsubscribe/resubscribe on identity change.
- Reset notification state on sign-out and session restore transitions.

---

### Issue 15 — `notify-fleet-manager` Function Drift (Not Deployed)
**Description**  
Live endpoint returns `404` for `notify-fleet-manager`.

**Root Cause**  
Deployment/state drift between repo and live project.

**Where it exists (file/service/table)**  
- `supabase/functions/notify-fleet-manager/index.ts`
- Live probe: `/functions/v1/notify-fleet-manager` -> `404 NOT_FOUND`

**Why it is dangerous**  
Operational alerting pathway for application workflows may silently fail.

**Exact fix (code-level or DB-level)**  
- Deploy function and add post-deploy endpoint health checks in CI/CD.
- Add fallback in app/backend if function missing.

---

### Issue 16 — Hardcoded Project Anon Key in Source
**Description**  
Anon key is embedded directly in source.

**Root Cause**  
Static initialization of global Supabase client with in-repo key literal.

**Where it exists (file/service/table)**  
- `Sierra/Shared/Services/SupabaseManager.swift`

**Why it is dangerous**  
Operational risk: key rotation friction, accidental exposure in forks/logs/tests.

**Exact fix (code-level or DB-level)**  
- Move key/url into environment-based configuration per build flavor.
- Add secret scanning gate in CI.

---

## Hidden / Non-Obvious Risks

1. **Security feature mirage**: `TwoFactorSessionService` suggests robust server-backed 2FA but runtime path does not use it.
2. **Dual realtime managers**: both exist and can each appear “correct” in isolation while causing production drift/duplication together.
3. **Session token semantics mismatch**: local random token can mask Supabase session revocation/expiry edge cases.
4. **Function-permission drift**: migration grants for overlap check exist in repo, but live RPC denies execution.
5. **Reset flow partial success**: OTP email can be sent while token insert silently fails, producing hard-to-debug user failures.

---

## Production Failure Scenarios

### Scenario A — Unauthorized Dashboard Access via Client-Side OTP Tampering
1. Attacker obtains valid username/password for a staff account.
2. Intercepts app runtime and forces `verifyOTP` success path.
3. App marks auth flow as verified and stores session artifacts.
4. Dashboard access granted without server-side OTP verification.

**Blast radius**: Account takeover for any credentialed user where OTP is expected to protect login.
**First breakpoint**: Client OTP validation boundary.

### Scenario B — Double Booking During Trip Creation
1. Fleet manager attempts to create trip assignment.
2. `TripService.checkOverlap` relies on edge function/RPC.
3. Backend permission mismatch returns failure.
4. If caller flow does not hard-stop, conflicting trip can be persisted.

**Blast radius**: Operational conflict, dispatch failures, SLA breach.
**First breakpoint**: Overlap-check call contract reliability.

### Scenario C — Realtime Drift and Notification Staleness
1. User logs in/out or switches role in same app lifetime.
2. One realtime system remains active while another re-subscribes.
3. Duplicate or stale events update local state inconsistently.
4. UI badges/map states diverge from backend truth.

**Blast radius**: Wrong operational decisions from stale fleet data.
**First breakpoint**: Realtime ownership and lifecycle coupling.

### Scenario D — Password Reset Flow Appears Successful but Fails at Final Step
1. User requests reset; OTP email is sent.
2. Token insert silently fails (`try?`) due DB policy/connectivity issue.
3. User enters OTP/new password.
4. Reset function rejects token; user gets credential reset failure.

**Blast radius**: Support load, user lockout frustration, trust erosion.
**First breakpoint**: token persistence error handling.

### Scenario E — Navigation Fails After Transient Routing Error
1. Driver starts navigation; first route fetch fails transiently.
2. `hasBuiltRoutes` remains true.
3. Subsequent attempts do not rebuild route in-session.
4. Driver runs without guided navigation.

**Blast radius**: route adherence issues, delay, safety/compliance impact.
**First breakpoint**: route build retry logic.

---

## Security Exploits (If Any)

### Exploit 1 — 2FA Client Bypass
- **Method**: Hook/patch app runtime to force success path in OTP verification service.
- **Impact**: bypass second factor, full account session.
- **Preconditions**: valid first-factor credential + local app tampering capability.

### Exploit 2 — Public Endpoint Abuse (Email/Reset Surface)
- **Method**: script high-volume calls to publicly callable edge endpoints (`send-email`, `reset-password`) with synthetic payloads.
- **Impact**: service abuse, spam pressure, operational degradation.
- **Preconditions**: network access to functions endpoint; no anti-automation control.

### Exploit 3 — Session State Confusion
- **Method**: exploit mismatch between local random session token and backend auth state, especially across expiration/revocation windows.
- **Impact**: inconsistent auth gating and potential unintended access persistence.
- **Preconditions**: stale local storage + app lifecycle edge conditions.

---

## Final Verdict

**System is not production-ready.**

### Top 5 blockers

1. Replace client-side OTP verification with server-authoritative verification using `two_factor_sessions`.
2. Add robust abuse controls for public edge endpoints (`send-email`, `reset-password`, `check-resource-overlap` exposure posture).
3. Fix overlap-check permission/deployment contract so scheduling conflict prevention is deterministic.
4. Consolidate realtime lifecycle ownership to a single manager with strict auth-bound start/stop.
5. Remove local-random-token auth gating and align session restore strictly with Supabase session validity.

---

## Confidence Labels

- **Confirmed**: findings based on direct code evidence and/or live endpoint behavior observed in this audit.
- **Probable**: high-confidence architectural/runtime risk inferred from code integration patterns.
- **Unverified (permission-limited)**: requires elevated DB metadata access (full policy/function catalog export) to prove exact live RLS/policy internals.

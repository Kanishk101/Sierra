# Sierra FMS — Remaining Fixes Overview

All 14 audit prompts are implemented. The following issues remain after the final verification of Phases 1–14.

---

## Status Summary (post-Phase 14)

### ✅ Resolved (confirmed in latest commit)

| Issue | Fix location |
|---|---|
| C-01 Silent Pass Inspection Bug | PreTripInspectionViewModel — `allItemsChecked` guard |
| C-02 No Trip Acceptance Flow | TripDetailDriverView + AppDataStore+TripAcceptance |
| C-03 Post-Trip Inspection Orphaned | AppDataStore.addProofOfDelivery (no auto-complete) |
| C-04 No Push Notifications | PushTokenService + SierraAppDelegate + edge function |
| C-05 Trip Assignment Never Notifies Driver | AppDataStore.addTrip → NotificationService |
| C-06 Staff Creation Race Condition | create-staff-account edge function |
| C-07 Admin Cannot Delete Auth Users | delete-staff-member edge function |
| C-08 VIN Scanning Missing | VINScannerView + CameraPreviewView |
| C-09 Geofencing Notifications | DB trigger + TripNavigationCoordinator client-side |
| C-10 Fuel Quantity Validation | FuelLogViewModel (OCR + mismatch check) |
| C-11 Mapbox Token Exposed | Info.plist → `$(MAPBOX_ACCESS_TOKEN)` xcconfig |
| C-12 TripUpdatePayload Wipes GPS | TripService.TripUpdatePayload (Phase 2) |
| C-13 CRUD Failures (RLS) | Migration 20260322000001 (role strings still need Fix A) |
| H-01 No Trip Reminders | TripReminderService |
| H-02 Filter Chips Wrong UX | FilterSheetView |
| H-03 Profile Tab Misuse | Driver tab restructure |
| H-04 DriverHistoryView Dead Code | DriverTripHistoryView (wiring: see Fix D) |
| H-05 Dashboard Ellipsis Bug | DashboardHomeView KPI card font constraints |
| H-06 Notification Bell Wrong Side | DashboardHomeView `.topBarTrailing` |
| H-07 KPI Cards Not Interactive | DashboardHomeView Button wrappers |
| H-08 Fuel Math Validation Missing | FuelLogViewModel.hasTotalCostMismatch |
| H-09 No OCR for Receipts | FuelLogViewModel.processReceiptWithOCR |
| H-10 No Mandatory Photo for Failed Items | PreTripInspectionViewModel.failedItemsMissingPhoto |
| H-11 Emergency Alert Never Notifies Admins | AppDataStore.addEmergencyAlert |
| H-13 Navigation Split | MapService + VoiceNavigationService |
| H-14 No Turn-by-Turn | TripNavigationCoordinator step tracking + HUD |
| H-15 Geofence Events No Notifications | DB trigger + coordinator |
| H-16 DashboardHomeView Zero ViewModels | DashboardViewModel |
| H-17 AddVehicleView God View | AddVehicleViewModel + refactored AddVehicleView |
| H-19 Maintenance Stale Vehicle Status | update-vehicle-status edge function |
| NSCameraUsageDescription missing | Info.plist (Phase 14) |
| push_tokens migration missing | 20260322000002 |
| fuel-receipts bucket migration missing | 20260322000003 |
| TripReminderService not wired in loadDriverData | AppDataStore.loadDriverData |
| abortTrip doesn't cancel reminders | AppDataStore.abortTrip |
| maintenanceComplete notification type missing | SierraNotification.NotificationType |

---

## 🔴 Still Open — Fix Prompts

| Fix | File | Severity | Description |
|---|---|---|---|
| **A** | [FIX-A-role-string-normalisation.md](FIX-A-role-string-normalisation.md) | 🔴 Critical | Role strings differ between RLS, edge functions, and Swift — all role-gated features silently fail |
| **B** | [FIX-B-document-expiry-auto-check.md](FIX-B-document-expiry-auto-check.md) | 🟠 High | No proactive document expiry alerts — H-12 |
| **C** | [FIX-C-dead-code-cleanup.md](FIX-C-dead-code-cleanup.md) | 🟡 Medium | Double edge-function call, dead TripAcceptanceService, .DS_Store in repo |
| **D** | [FIX-D-driver-history-nav-wiring.md](FIX-D-driver-history-nav-wiring.md) | 🟡 Medium | DriverTripHistoryView exists but nav path unconfirmed — H-04 |
| **E** | [FIX-E-trip-navigation-coordinator-split.md](FIX-E-trip-navigation-coordinator-split.md) | 🟡 Medium | TripNavigationCoordinator is 19.7KB god object — H-18 |

---

## Explicitly Out of Scope (audit-flagged, not implemented)

| Issue | Reason |
|---|---|
| H-20 Driver Rating admin UI | Never scoped in any prompt — requires new UI + DB schema |
| M-10 Passkeys / FIDO2 | Aspirational NFR, no SRS requirement |
| M-11 GDPR data export | Not in SRS |
| L-01 App Intents | Nice-to-have |
| L-02 Core ML predictive maintenance | Nice-to-have |
| L-06 Unit tests | Not in original 54-issue scope |

---

## Recommended Implementation Order

1. **Fix A** — Role strings (do this first, everything depends on it working)
2. **Fix C** — Dead code cleanup (quick, reduces confusion)
3. **Fix D** — Driver history wiring (quick verification + small change)
4. **Fix B** — Document expiry (requires Fix A to be applied first for correct role string in trigger)
5. **Fix E** — Coordinator split (largest refactor, save for last)

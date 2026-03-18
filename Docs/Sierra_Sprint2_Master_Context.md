# SIERRA PROJECT MASTER CONTEXT DOCUMENT

> **Purpose:** Complete portable context transfer file generated from the full Sprint 2 audit conversation. Contains every technical finding, architecture decision, implementation task, security issue, performance issue, Figma flow, Jira story, and repository finding. Nothing has been omitted or summarised.

---

## 1. Project Overview

### System Description

Sierra is a Fleet Management System (FMS) iOS application. It is not built for a specific client but is designed to be extensible and adaptable for deployment and integration into any logistics network.

### Project Objectives
- Provide a centralised platform for managing vehicle information and maintenance schedules
- Facilitate real-time tracking of vehicle locations and usage
- Optimise vehicle routing and dispatching
- Track fuel consumption and other operational costs
- Enhance communication and collaboration among fleet managers, drivers, and maintenance personnel
- AI-driven predictive maintenance, fuel optimisation, intelligent routing (v1.0 features, future scope)

### Three User Roles

**1. Fleet Manager / Admin**
- Staff account management
- Staff verification and approval
- Delivery task management with unique Task IDs
- Driver availability monitoring
- Vehicle management
- Live GPS tracking
- Maintenance management
- Priority alerts and task reassignment
- Vehicle document monitoring (insurance/registration expiry)
- Reporting and analytics
- Geofencing

**2. Driver**
- Secure login using admin-generated credentials
- Availability status management
- Trip management (start/end, mileage)
- Route navigation
- Delivery execution (proof via photo/signature/OTP)
- Pre/post-trip vehicle inspection
- Fuel logging (quantity, cost, receipt upload)
- Emergency alerts with GPS location

**3. Maintenance Personnel**
- Maintenance task and activity tracking (repair details, parts, labour costs)
- VIN scanning via camera
- Work order management (view/update/close)
- Breakdown handling (receive alerts, record repair actions)

### Technology Stack
- **Platform:** iOS 26+, iPhone and iPad
- **UI Framework:** SwiftUI
- **Architecture:** MVVM with Swift Concurrency
- **Frameworks:** Core ML, Vision, App Intents
- **Backend:** Supabase (project: Sierra-FMS-v2, ID: ldqcdngdlbbiojlnbnjg, region: ap-south-1)
- **Maps/Navigation:** Mapbox
- **Security:** 2FA, role-based auth, encryption, GDPR compliance

### Repository Details
- **Working repo (private):** mantosh23/Sierra
- **Documentation repo (public):** Kanishk101/Sierra
- **Supabase org ID:** uwjhxrdmukrrpkvnifno

### SRS Versions
- **v1.0** by Virag Bardiya — includes AI-driven predictive maintenance, fuel optimisation, intelligent routing, voice-based trip logging, AI spare parts forecasting, automated work order prioritisation, automated compliance alerts, geofencing
- **v2.0** by Prasad B S — current implementation target; geofencing carried forward from v1.0

### Non-Functional Requirements
- Fast load time on slow network connections
- Handle high volumes of data and support thousands of concurrent users
- Zero memory leaks
- Zero constraint warnings or conflict errors
- Secure login protocols including 2FA
- Role-based authentication for accessing functional modules
- Secure data storage and encryption
- GDPR compliance
- User-friendly interface
- Scalability to accommodate growth
- Reliability with minimal downtime
- Accessibility for widest range of capabilities

### Submission Deliverables
- Codebase
- App video demo
- Memory profile screenshot
- Flow diagram

---

## 2. Sprint Structure

### Sprint 1 — Closed (March 10–15, 2026)

**Goal:**
> Secure Login + 2-FA + Forgot Password, Role Verification, Fleet Manager Dashboard (Create Staff Accounts, Approve Staff, Remove Staff, Vehicle Management, Create Trip, Assign Driver & Vehicle), Driver Dashboard (Onboarding, Set Availability, Profile), Maintenance Personal Dashboard (Onboarding, Profile)

**All Sprint 1 stories are marked Done in Jira.**

### Sprint 2 — Active (March 17–22, 2026)

**Goal:**
> Fleet Manager Dashboard: Create Geo fence, Define Route of the Trip, Monitor Live Trip, Get alert when route not followed and geo fenced areas are entered, Get SOS and Defect alerts, Approve maintenance requests.
> Driver Dashboard: Start Trip, Perform Pre Trip Inspection, Follow Route, Complete Delivery, Upload Proof, Raise SOS and Defects Alert, Create Maintenance Request.
> Maintenance Personal Dashboard: See assigned request, Update request, Add status Updates.

**Sprint 2 Deadline: March 22, 2026.**

### Modules Defined for Sprint 2
- Fleet Manager monitoring module (live map, geofencing, alerts)
- Driver trip lifecycle module (start → inspect → navigate → deliver → end)
- Maintenance workflow module (receive → update → complete)
- Alerts and notifications module (SOS, route deviation, geofence breach)

---

## 3. Architecture Design

### MVVM Structure
- Architecture: MVVM + Swift Concurrency
- Views must contain zero business logic
- ViewModels own all state and business logic
- Services are injected or called from ViewModels only, never from Views
- AppDataStore is the global singleton for shared app state

### AppDataStore Architecture
- AppDataStore must remain `@Observable` singleton
- File: `Sierra/Shared/Services/AppDataStore.swift`
- Currently 39 KB in size (flagged as large but accepted as normal for production SwiftUI apps at this stage)
- Contains subscription methods: `subscribeToVehicles()`, `subscribeToTrips()`, `subscribeToAlerts()`
- ChatGPT assessment: 30–50 KB store files are normal for MVVM SwiftUI apps. Refactoring mid-sprint is inadvisable.
- Claude initial assessment: flagged as a violation. This was later accepted as over-criticism for the current stage.

### Supabase Usage Rules
- The Supabase client must always be the global `supabase` instance
- Never manually update vehicle status when trip status changes — DB triggers handle it
- Specifically: `handle_trip_started`, `handle_trip_completed`, `handle_trip_cancelled` are PostgreSQL triggers that automatically manage vehicle status
- Never call vehicle status update from iOS code when a trip starts or ends
- OTP must only store hash in DB, never plaintext

### Mapbox Navigation Integration Rules
- `NavigationViewController` must only be created in `makeUIViewController`
- Mapbox Directions API calls must never be reactive (must not be called from `onChange`, `onAppear`, or inside `body`)
- `TripNavigationView.swift` wraps Mapbox NavigationViewController as UIViewControllerRepresentable

### Realtime Subscription Handling
- Realtime subscriptions needed for Sprint 2:
  - `vehicle_location_history` — Fleet Manager live map
  - `emergency_alerts` — Fleet Manager SOS inbox
  - `route_deviation_events` — Fleet Manager route alerts
  - `geofence_events` — Fleet Manager geofence breach alerts
  - `maintenance_tasks` — Maintenance staff assigned requests
- ChatGPT assessment: A dedicated `RealtimeSubscriptionManager` is not necessary. Existing AppDataStore subscription methods are sufficient. Do not build new infrastructure mid-sprint.
- Claude initial assessment: recommended building a `RealtimeSubscriptionManager`. This was later accepted as over-engineering.

### Swift Concurrency Rules
- All async operations must use Swift Concurrency (`async/await`)
- No DispatchQueue unless wrapping legacy APIs
- Task cancellation must be handled at ViewModel level

### Location Publishing Throttling
- Location publishing must be throttled to minimum 5 seconds between writes
- `VehicleLocationService.publishLocation()` must implement this throttle
- Correct implementation:
```swift
private var lastPublishTime: Date?

func publishLocation(...) async {
    guard shouldPublish() else { return }
    lastPublishTime = Date()
    try await supabase
        .from("vehicle_location_history")
        .insert(...)
}
```
- `shouldPublish()` checks `Date().timeIntervalSince(lastPublishTime) >= 5.0`
- Without throttle: up to 10,000 writes per hour per vehicle
- With 5 vehicles at 5s throttle: 720 rows/hour/vehicle — acceptable
- `VehicleLocationService.swift` is currently only 2.85 KB — likely does not implement throttle correctly; must be verified

### Photo Upload Rules
- All photo uploads must be sequential, not concurrent
- `ProofOfDeliveryViewModel` must implement sequential upload pattern
- `ProofOfDeliveryView` is 13.1 KB with no ViewModel — this is a critical gap

### OTP Security Rules
- OTP must only store hash in DB
- Never store OTP plaintext
- `CryptoService.swift` exists for this purpose

### Known Auth Bugs (Sprint 1 carry-over)
1. **2FA bug during forced password change:** `ForcePasswordChangeView` explicitly calls `generateOTP()`, causing 2FA to appear during forced password change flow for new staff. Fix: remove `generateOTP()` call from `ForcePasswordChangeViewModel`.
2. **Face ID not appearing after sign-out:** Session token is cleared on `signOut()`, causing `hasSessionToken()` check to fail. Fix: restore `hasSessionToken()` check independently of biometric flag.
3. **Auth flow sequencing:** `isAuthenticated = true` was set in `signIn()`, which triggered `ContentView` to swap out `LoginView` before OTP verification. Fix: remove `isAuthenticated = true` from `signIn()`, add `completeAuthentication()` called only post-OTP, avoid manually clearing `showTwoFactor` before `completeAuthentication()` to prevent iOS 17 chained fullScreenCover conflicts.

---

## 4. GitHub Repository Audit

### Repository: Kanishk101/Sierra (public, branch: main)

### Top-Level Directory Structure
```
Sierra/
├── .DS_Store
├── .gitignore
├── Docs/
├── Sierra.xcodeproj/
├── Sierra/
│   ├── Auth/
│   ├── ContentView.swift
│   ├── Driver/
│   ├── FleetManager/
│   ├── Info.plist
│   ├── Maintenance/
│   ├── Onboarding/
│   ├── Shared/
│   ├── SierraApp.swift
│   └── sendEmail.swift
└── supabase/
```

### Auth Module — `Sierra/Auth/`
| File | Size | Notes |
|------|------|-------|
| AppLifecycleMonitor.swift | 1.6 KB | |
| AuthManager.swift | 16 KB | Central auth state machine |
| BiometricEnrollmentSheet.swift | 3.5 KB | |
| BiometricLockView.swift | 6.7 KB | |
| BiometricManager.swift | 3.6 KB | |
| ChangePasswordView.swift | 3.1 KB | |
| DriverOnboardingView.swift | 3.2 KB | |
| ForcePasswordChangeView.swift | 7.4 KB | 🔴 Bug: calls generateOTP() |
| ForgotPasswordView.swift | 14.4 KB | |
| LoginView.swift | 14.5 KB | |
| PendingApprovalView.swift | 2.8 KB | |
| TwoFactorView.swift | 9.5 KB | |
| Models/ | dir | |
| Services/ | dir | |
| ViewModels/ | dir | |

### Shared Models — `Sierra/Shared/Models/`
| File | Size | Sprint 2 Use |
|------|------|-------------|
| ActivityLog.swift | 5.5 KB | Audit logging |
| AuthUser.swift | 0.8 KB | Auth identity |
| DriverProfile.swift | 2.0 KB | Driver data |
| EmergencyAlert.swift | 2.3 KB | SOS alerts |
| FuelLog.swift | 1.6 KB | Fuel/toll receipts |
| Geofence.swift | 3.8 KB | Create/manage geofences |
| GeofenceEvent.swift | 1.4 KB | Geofence breach events |
| MaintenanceProfile.swift | 2.3 KB | Maintenance staff profile |
| MaintenanceRecord.swift | 4.6 KB | Work completion records |
| MaintenanceTask.swift | 3.3 KB | Maintenance requests |
| OnboardingPage.swift | 1.5 KB | Onboarding flow |
| PartUsed.swift | 1.1 KB | Parts tracking |
| ProofOfDelivery.swift | 2.2 KB | Photo/OTP/signature |
| RouteDeviationEvent.swift | 1.6 KB | Route deviation tracking |
| SierraNotification.swift | 2.1 KB | Notification system |
| SparePartsRequest.swift | 2.4 KB | Parts requests |
| StaffApplication.swift | 9.2 KB | Staff onboarding |
| StaffMember.swift | 10.7 KB | Staff data |
| Trip.swift | 11.6 KB | Trip lifecycle |
| TripExpense.swift | 1.4 KB | Expense logging |
| TwoFactorSession.swift | 1.9 KB | 2FA session |
| UserRole.swift | 0.6 KB | Role enum |
| Vehicle.swift | 6.4 KB | Vehicle data |
| VehicleDocument.swift | 5.8 KB | Doc management |
| VehicleInspection.swift | 3.0 KB | Pre/post-trip inspection |
| VehicleLocationHistory.swift | 1.2 KB | GPS history |
| WorkOrder.swift | 2.6 KB | Work orders |

**Missing Models:**
- `VehicleServiceHistory` — needed for FMS1-17 (vehicle service history tracking)
- `TripSummaryReport` — needed for FMS1-20/21 (fleet usage reports)
- `DriverActivityReport` — needed for FMS1-21 (driver activity reports)

### Shared Services — `Sierra/Shared/Services/`
| File | Size | Notes |
|------|------|-------|
| ActivityLogService.swift | 1.8 KB | |
| AppDataStore.swift | **39 KB** | Global state singleton |
| CryptoService.swift | 1.3 KB | OTP hashing |
| DriverProfileService.swift | 5.0 KB | |
| EmailService.swift | 4.6 KB | |
| EmergencyAlertService.swift | 3.9 KB | |
| FuelLogService.swift | 3.4 KB | |
| GeofenceEventService.swift | 2.8 KB | |
| GeofenceService.swift | 4.1 KB | |
| KeychainService.swift | 1.9 KB | |
| MaintenanceProfileService.swift | 5.5 KB | |
| MaintenanceRecordService.swift | 3.9 KB | |
| MaintenanceTaskService.swift | 7.7 KB | |
| NotificationService.swift | 4.3 KB | |
| OnboardingService.swift | 0.4 KB | |
| PartUsedService.swift | 1.9 KB | |
| ProofOfDeliveryService.swift | 3.1 KB | |
| RouteDeviationService.swift | 4.0 KB | |
| SparePartsRequestService.swift | 3.9 KB | |
| StaffApplicationService.swift | 7.4 KB | |
| StaffApplicationStore.swift | **0.25 KB** | 🟡 Duplicate mini-store |
| StaffMemberService.swift | 12.4 KB | |
| SupabaseManager.swift | 1.2 KB | |
| TripExpenseService.swift | 1.7 KB | |
| TripService.swift | 12.3 KB | |
| TwoFactorSessionService.swift | 4.2 KB | |
| VehicleDocumentService.swift | 3.4 KB | |
| VehicleInspectionService.swift | 6.4 KB | |
| VehicleLocationService.swift | **2.85 KB** | 🔴 Likely missing 5s throttle |
| VehicleService.swift | 6.7 KB | |
| WorkOrderService.swift | 6.2 KB | |

**Missing Services:**
- `RealtimeSubscriptionManager` — no centralised realtime channel manager (ChatGPT: not needed for sprint, AppDataStore methods sufficient)
- `LocationThrottleManager` — 5-second throttle enforcement (may be missing inside VehicleLocationService; must verify)
- `RouteMatchingService` — route deviation logic needs a service to compute deviation from planned waypoints

### Driver Module — `Sierra/Driver/`

**Views:**
| File | Size | Status |
|------|------|--------|
| DriverApplicationSubmittedView.swift | 8.9 KB | ✅ Sprint 1 |
| DriverHomeView.swift | 11.9 KB | ✅ Sprint 1 |
| DriverProfilePage1View.swift | 10.0 KB | ✅ Sprint 1 |
| DriverProfilePage2View.swift | 13.3 KB | ✅ Sprint 1 |
| DriverProfileSetupView.swift | 2.4 KB | ✅ Sprint 1 |
| DriverTripHistoryView.swift | **2.9 KB** | 🔴 Stub — needs real data |
| IncidentReportSheet.swift | 4.2 KB | ✅ Done (FMS1-43) |
| NavigationHUDOverlay.swift | 10.3 KB | 🟡 Needs SOS/defect buttons |
| PostTripInspectionView.swift | 5.6 KB | 🟡 No ViewModel |
| PreTripInspectionView.swift | 13.8 KB | 🔵 In Review |
| ProofOfDeliveryView.swift | 13.1 KB | 🔴 No ViewModel |
| SOSAlertSheet.swift | 7.4 KB | 🟡 No ViewModel |
| StartTripSheet.swift | 10.2 KB | 🔵 In Review — needs wiring |
| TripDetailDriverView.swift | 11.2 KB | 🟡 Exists |
| TripNavigationContainerView.swift | 2.6 KB | 🟡 Exists |
| TripNavigationView.swift | 2.8 KB | 🟡 Likely stub |

**ViewModels:**
| File | Size | Status |
|------|------|--------|
| DriverProfileViewModel.swift | 11 KB | ✅ Sprint 1 |
| PreTripInspectionViewModel.swift | 7.8 KB | ✅ Exists |
| TripNavigationCoordinator.swift | 15.7 KB | ✅ Exists |

**Missing Driver ViewModels:**
- `TripViewModel` — start trip, end trip, active trip state, mileage update, location publishing (HIGHEST PRIORITY)
- `PostTripInspectionViewModel` — post-trip checklist submission
- `ProofOfDeliveryViewModel` — photo/OTP/signature upload sequencing
- `SOSAlertViewModel` — SOS creation, GPS attachment
- `RouteDeviationViewModel` — deviation detection logic
- `FuelLogViewModel` — fuel/toll receipt entry and upload
- `DriverTripHistoryViewModel` — trip history with real data

**Missing Driver Views:**
- `EndTripView` / `EndTripSheet` — no view for ending a trip (FMS1-38)
- `MaintenanceRequestCreationView` (driver-side) — FMS1-47
- `FuelLogEntryView` — FMS1-48
- `OdometerEntryView` — FMS1-49, should be inside `StartTripSheet`
- `RouteDeviationAlertView` — FMS1-50

### Fleet Manager Module — `Sierra/FleetManager/`

**Views:**
| File | Size | Status |
|------|------|--------|
| AddVehicleView.swift | **40 KB** | 🔴 MVVM violation — logic in View |
| AdminProfileView.swift | 2.3 KB | ✅ |
| AlertDetailView.swift | 9.4 KB | 🟡 Exists |
| AlertsInboxView.swift | 9.4 KB | 🟡 Needs AlertsViewModel |
| AnalyticsDashboardView.swift | **32 KB** | 🔴 MVVM violation |
| CreateGeofenceSheet.swift | 10.9 KB | 🟡 Needs GeofenceViewModel |
| CreateStaffView.swift | 14.6 KB | ✅ Sprint 1 |
| CreateTripView.swift | **27 KB** | 🔴 No ViewModel, no waypoints |
| DashboardHomeView.swift | **19 KB** | 🔴 No ViewModel |
| DriverHistoryView.swift | 11.7 KB | 🟡 No ViewModel |
| FleetLiveMapView.swift | 7.4 KB | 🟡 Needs realtime subscription |
| MaintenanceApprovalDetailView.swift | 13.4 KB | 🟡 Missing assign-technician step |
| MaintenanceRequestsView.swift | 5.2 KB | 🟡 Exists |
| PendingApprovalsView.swift | 5.6 KB | ✅ Sprint 1 |
| QuickActionsSheet.swift | 3.8 KB | ✅ |
| ReportsView.swift | 13.1 KB | 🟡 Exists |
| StaffListView.swift | 14.6 KB | ✅ Sprint 1 |
| StaffReviewSheet.swift | **16.5 KB** | 🟡 Oversized for its ViewModel |
| StaffTabView.swift | 12.8 KB | ✅ Sprint 1 |
| TripDetailView.swift | 12.3 KB | 🟡 Exists |
| TripsListView.swift | 7.9 KB | ✅ Sprint 1 |
| VehicleDetailView.swift | 8.3 KB | ✅ Sprint 1 |
| VehicleListView.swift | 11.2 KB | ✅ Sprint 1 |
| VehicleMapDetailSheet.swift | 8.0 KB | 🟡 Exists |
| VehicleStatusView.swift | 6.3 KB | 🟡 No ViewModel |
| VehicleServiceHistoryView.swift | ❌ | Missing |

**ViewModels:**
| File | Size | Status |
|------|------|--------|
| CreateStaffViewModel.swift | 4.7 KB | ✅ Sprint 1 |
| FleetLiveMapViewModel.swift | **2.7 KB** | 🔴 Too small — likely inline Supabase calls |
| StaffApprovalViewModel.swift | 1.6 KB | ✅ Sprint 1 |

**Missing Fleet Manager ViewModels:**
- `DashboardHomeViewModel` — extract 19 KB view logic
- `AlertsViewModel` — subscribe to emergency_alerts + route_deviation_events + geofence_events
- `GeofenceViewModel` — create/edit/delete geofences
- `VehicleStatusViewModel` — live status dashboard aggregation
- `MaintenanceRequestViewModel` — Fleet Manager approve/reject/assign flow
- `AnalyticsDashboardViewModel` — extract 32 KB view logic
- `DriverHistoryViewModel` — trip history and performance metrics

**Missing Fleet Manager Views:**
- `VehicleServiceHistoryView` — FMS1-17

### Maintenance Module — `Sierra/Maintenance/`

**Views:**
| File | Size | Status |
|------|------|--------|
| MaintenanceApplicationSubmittedView.swift | 10.5 KB | ✅ Sprint 1 |
| MaintenanceDashboardView.swift | 13.8 KB | 🟡 Exists |
| MaintenanceProfilePage1View.swift | 9.6 KB | ✅ Sprint 1 |
| MaintenanceProfilePage2View.swift | 18 KB | ✅ Sprint 1 |
| MaintenanceProfileSetupView.swift | 2.3 KB | ✅ Sprint 1 |
| MaintenanceTaskDetailView.swift | 18.1 KB | 🟡 VIN scan needed |
| SparePartsRequestSheet.swift | 5.9 KB | 🟡 Exists |
| WorkOrderListView.swift | ❌ | Missing |
| TaskStatusUpdateSheet.swift | ❌ | Missing |

**ViewModels:**
| File | Size | Status |
|------|------|--------|
| MaintenanceDashboardViewModel.swift | 2.2 KB | ✅ Exists |
| MaintenanceProfileViewModel.swift | 11 KB | ✅ Sprint 1 |

**Missing Maintenance ViewModels:**
- `MaintenanceTaskViewModel` — update task status, log work
- `WorkOrderViewModel` — work order management

**Missing Maintenance Views:**
- `WorkOrderListView` — only task detail exists, no list
- `TaskStatusUpdateSheet` — no dedicated status update UI (FMS1-55)

### Other Files
- `Sierra/sendEmail.swift` — 🟡 Not in a service folder, not namespaced
- `Sierra/Shared/Services/StaffApplicationStore.swift` — 🟡 254 bytes, duplicate mini-store violating single-source-of-truth principle

### Confirmed DB Triggers (from Supabase)
- `handle_trip_started` — auto-updates vehicle status when trip starts
- `handle_trip_completed` — auto-updates vehicle status to available when trip ends
- `handle_trip_cancelled` — auto-updates vehicle status when trip is cancelled
- `check_resource_overlap` — prevents double-booking of vehicles/drivers

---

## 5. Jira Story Analysis

### Project: FMS1 — Fleet Management System

### Sprint 1 Stories (All Done)

| Story ID | Role | Summary | Status |
|----------|------|---------|--------|
| FMS1-1 | Fleet Manager | Add new vehicle | ✅ Done |
| FMS1-2 | Fleet Manager | Edit vehicle details | ✅ Done |
| FMS1-3 | Fleet Manager | Delete vehicle records | ✅ Done |
| FMS1-4 | Fleet Manager | View all vehicles | ✅ Done |
| FMS1-5 | Fleet Manager | Search vehicles by number or model | ✅ Done |
| FMS1-6 | Fleet Manager | Register new drivers | ✅ Done |
| FMS1-7 | Fleet Manager | Approve driver profile | ✅ Done |
| FMS1-31 | Driver | Log in to the system | ✅ Done |
| FMS1-32 | Driver | Log out of the system | ✅ Done |
| FMS1-33 | Driver | Change password | ✅ Done |
| FMS1-34 | Driver | View profile | ✅ Done |
| FMS1-35 | Driver | Update profile details | ✅ Done |
| FMS1-51 | Maintenance | Log in to the system | ✅ Done |
| FMS1-52 | Maintenance | Log out of the system | ✅ Done |

### Sprint 2 Stories

| Story ID | Role | Summary | Jira Status | Implementation Status |
|----------|------|---------|-------------|----------------------|
| FMS1-8 | Fleet Manager | Deactivate drivers | In Progress | 🟡 Partially implemented |
| FMS1-9 | Fleet Manager | Define geofence boundaries (warehouses/delivery/restricted) | To Do | CreateGeofenceSheet exists, no ViewModel |
| FMS1-10 | Fleet Manager | View driver history | To Do | DriverHistoryView exists (shell), no ViewModel |
| FMS1-11 | Fleet Manager | See live vehicle location during active trip | To Do | FleetLiveMapView + VM exist, realtime sub status unknown |
| FMS1-12 | Fleet Manager | Receive alert if driver leaves planned route | To Do | AlertsInboxView + model exist, no ViewModel |
| FMS1-13 | Fleet Manager | Review maintenance requests from drivers | To Do | MaintenanceRequestsView + detail view exist |
| FMS1-14 | Fleet Manager | Make zones around delivery/restricted locations (geofence) | To Do | Duplicate of FMS1-9 scope |
| FMS1-15 | Fleet Manager | Receive SOS and defect alerts from drivers | To Do | AlertsInboxView UI exists, no realtime subscription |
| FMS1-16 | Fleet Manager | Reject maintenance requests | To Do | MaintenanceApprovalDetailView UI exists |
| FMS1-17 | Fleet Manager | Track vehicle service history | To Do | ❌ Not implemented — no view or model |
| FMS1-18 | Driver | Upload pre-trip vehicle photos | Done | ✅ Fully implemented |
| FMS1-19 | Fleet Manager | View vehicle status (active/under repair) | To Do | VehicleStatusView exists (shell) |
| FMS1-20 | Fleet Manager | Generate fleet usage reports | To Do | ReportsView + AnalyticsDashboardView exist |
| FMS1-21 | Fleet Manager | Access driver activity reports | To Do | Partially in AnalyticsDashboardView |
| FMS1-24 | Fleet Manager | View dashboard summary/stats | To Do | DashboardHomeView exists — no VM |
| FMS1-25 | Fleet Manager | Receive alerts for overdue maintenance | To Do | Alert system shells exist |
| FMS1-36 | Driver | Pre-trip vehicle inspection | In Review | ✅ View + ViewModel both present |
| FMS1-37 | Driver | Start a trip | In Review | StartTripSheet exists — no TripViewModel |
| FMS1-38 | Driver | End a trip | To Do | ❌ No EndTripView or ViewModel |
| FMS1-39 | Driver | See assigned route | To Do | TripNavigationView exists, Mapbox wiring needs audit |
| FMS1-40 | Driver | Mark delivery as completed | In Progress | ProofOfDeliveryView exists, no ViewModel |
| FMS1-41 | Driver | Update vehicle mileage | To Do | ❌ No dedicated UI |
| FMS1-42 | Driver | View trip history | To Do | DriverTripHistoryView exists (2.9 KB = stub) |
| FMS1-43 | Driver | Report vehicle defects during trip | Done | ✅ IncidentReportSheet |
| FMS1-44 | Driver | Upload proof of delivery | To Do | View exists, no ViewModel |
| FMS1-45 | Driver | Send SOS alert during emergency | To Do | SOSAlertSheet exists (7.4 KB), no ViewModel |
| FMS1-46 | Driver | Receive notifications for vehicle assignments | To Do | NotificationService exists, not wired |
| FMS1-47 | Driver | Request maintenance if vehicle problem detected | To Do | ❌ No dedicated maintenance request creation view |
| FMS1-48 | Driver | Upload fuel/toll receipts | To Do | FuelLogService exists, no UI |
| FMS1-49 | Driver | Record vehicle odometer reading before trip | To Do | ❌ No UI |
| FMS1-50 | Driver | Alert if driver leaves assigned route | To Do | RouteDeviationService + model exist |
| FMS1-53 | Maintenance | See assigned maintenance requests | To Do | MaintenanceDashboardView exists |
| FMS1-54 | Maintenance | View vehicle issue details | To Do | MaintenanceTaskDetailView exists |
| FMS1-55 | Maintenance | Update maintenance request status | To Do | ❌ No dedicated status update sheet |

### Future Backlog (No Sprint Assigned)

| Story ID | Role | Summary |
|----------|------|---------|
| FMS1-22 | Admin | Generate maintenance reports |
| FMS1-23 | Admin | Export reports to Excel |
| FMS1-26 | Admin | View trip records |
| FMS1-27 | Admin | Manage system roles |
| FMS1-28 | Admin | Reset user passwords |
| FMS1-29 | Admin | Lock user accounts |
| FMS1-30 | Admin | Monitor system logs |

---

## 6. Figma Flow Analysis

### FigJam Board URL
https://www.figma.com/board/b77le46eYMiVfLuHcwMGdW/FMS-TEAM---3

### Board Contents
The FigJam board contains:
1. A full end-to-end flow diagram in a "Sprint 1" section covering the entire application
2. A screenshot of what appears to be the app UI (node 24:246)
3. A mermaid diagram image (node 23:318)
4. A Sprint 1 sticky note from Gaurav listing Sprint 1 goals
5. A Sprint 2 text block (Section 138:1455) listing Sprint 2 goals matching Jira Sprint 2

### Sprint 1 Flows (from Figma section 45:1020)

**Authentication Flow:**
```
Start
  → Login Screen (Email, Password, Forgot Password)
  → Validate Credentials
  → Are credentials valid?
      → No → Show Login Error → back to Login
      → Yes → Send OTP for Two-Factor Authentication
            → OTP Verification Screen
            → Validate OTP
            → Is OTP valid?
                → No → Show OTP Error
                      → Retry or Request New?
                          → Retry → OTP Verification Screen
                          → Request New → Send OTP
                → Yes → Detect User Role
                      → Fleet Manager → Fleet Manager Dashboard
                      → Driver → First Login?
                              → Yes → Change Password → OTP Verification → Driver Dashboard
                              → No → OTP Verification → Driver Dashboard
                      → Maintenance Staff → First Login?
                                         → Yes → Change Password → OTP Verification → Maintenance Dashboard
                                         → No → OTP Verification → Maintenance Dashboard
```

**Fleet Manager Dashboard Actions (Sprint 1 portion):**
```
Fleet Manager Dashboard
  → Select Action:
      → Staff Management
            → Add Staff → Enter Name and Email → Generate Password Automatically
              → Send Credentials to Email → Approve or Reject Profile?
                  → Approve → Staff Profile Approved
                  → Reject → Staff Profile Rejected
      → Vehicle Management
            → Select Action:
                → Add Vehicle
                → Edit Vehicle Details
                → Update Vehicle Status
      → Trip Management
            → Create Trip → Assign Driver → Assign Vehicle → Schedule Trip → Trip Created
      → Assigns new vehicle for the trip
      → Geofencing (Sprint 1 node — Create Geofence → Define Start and End Point → Define Radius → Create Zones)
      → Monitor Live Trip → Create the specified route to follow → Perform live tracking → Get alerts when route not followed
      → AI powered maintenance → Receive automatic Maintenance alerts based on expiry and distance travelled
      → Maintenance Management → Approve maintenance request → Assign maintenance personal → Monitor maintenance process
                               → Get alert when maintenance completed → (Updates vehicle status)
```

**Driver Dashboard Actions (Sprint 1/2 combined):**
```
Driver Dashboard
  → Select Action:
      → Update Availability Status → back to Driver Dashboard
      → Perform Pre Trip Inspection
            → Issue Found?
                → Yes → Send alert to Fleet Manager → (Fleet Manager Dashboard)
                → No → Start the Trip
      → Follow the route assigned by Fleet Manager
            → Get alerts when route not followed
            → Complete Delivery
      → Upload Delivery Proof
            → Upload picture of delivered goods
            → End the trip
            → View Previous Trips
      → Perform Post Trip Inspection
            → Issue Found?
                → Yes → Raise maintenance request → (Fleet Manager Maintenance Management)
                → No → Vehicle status gets updated as available
      → Accident/Defect?
            → Yes → Send Automatic alert to admin
            → No → Continue with the Trip
      → View Assigned Delivery Tasks → Has Assigned Trip?
            → No → No Trip Assigned → back to Driver Dashboard
```

**Maintenance Dashboard Actions:**
```
Maintenance Dashboard
  → Select Action:
      → View maintenance request
      → Start maintenance
      → Update maintenance status
      → Complete maintenance task
```

### Sprint 2 Specific Flow Findings

#### Finding 1: Pre-Trip Inspection Alert Flow Is Missing
Figma explicitly shows:
```
Pre-Trip Inspection
     ↓
Issue Found?
     ↓
YES → Send alert to Fleet Manager → (Fleet Manager Dashboard)
     ↓
NO → Start the Trip
```
Current implementation: `PreTripInspectionViewModel` calls `submitInspection()` only, with no conditional alert to Fleet Manager.

**Required fix:**
```swift
if inspectionResult == .failed {
    try await EmergencyAlertService.createAlert(
        type: .defect,
        tripId: tripId,
        vehicleId: vehicleId,
        driverId: driverId,
        description: "Pre-trip inspection failure"
    )
}
```

#### Finding 2: Maintenance Approval Missing "Assign Technician" Step
Figma flow:
```
Approve Request
     ↓
Assign Maintenance Personnel   ← THIS IS MISSING
     ↓
Monitor maintenance process
     ↓
Get alert when maintenance completed
     ↓
Updates vehicle status
```
Current implementation: `MaintenanceApprovalDetailView` has Approve/Reject only.
DB schema: `maintenance_tasks.assigned_to` field exists but is never populated via UI.

**Required addition:**
```swift
Picker("Assign Technician", selection: $selectedTech) {
    ForEach(maintenanceStaff) { tech in
        Text(tech.name)
    }
}
// Then on approval: assigned_to = selectedTech.id
```

#### Finding 3: Maintenance Completion Notification to Fleet Manager Is Missing
Figma shows: "Get alert when maintenance completed" flows to Fleet Manager.
Current state: `MaintenanceTaskService` has no completion callback that creates a `notifications` record for Fleet Manager.

**Required addition in `MaintenanceTaskService.completeTask()`:**
- On status transition to `completed`, create a notification record for Fleet Manager

#### Finding 4: Post-Trip Vehicle Status Update Is Handled by DB Trigger (Correct)
Figma shows: Post-Trip Inspection → No Issues → Vehicle status gets updated as available.
This IS handled by the `handle_trip_completed` DB trigger. The iOS app must NOT call vehicle status update here manually.
However: `PostTripInspectionView` (5.6 KB) has no ViewModel — likely calling services directly from View, which is an MVVM violation.

#### Finding 5: Mid-Trip SOS/Defect Alert Is Accessible at Any Time
Figma shows a separate decision diamond during active trip:
```
Accident/Defect?
  → YES → Send Automatic alert to admin
  → NO  → Continue with Trip
```
This is separate from the Post-Trip Inspection issue-found flow.
`SOSAlertSheet` and `IncidentReportSheet` must be accessible at any point during active navigation.
`NavigationHUDOverlay` (10.3 KB) needs dedicated buttons to access both sheets.

#### Finding 6: Geofence Creation Is a Multi-Step Flow
Figma shows:
```
Create Geofence → Define Start and End Point → Define Radius → Create Zones
     → Alerts when vehicle moves out of the zone
```
`CreateGeofenceSheet` (10.9 KB) must implement all four sub-steps:
- Map coordinate picker for start/end point
- Numeric slider or input for radius
- Zone type selection: warehouse, delivery point, restricted

#### Finding 7: Route Creation Is a Fleet Manager Prerequisite for Live Tracking
Figma flow for Fleet Manager:
```
Monitor Live Trip → Create the specified route to follow → Perform live tracking → Get alerts when route not followed
```
Route waypoints must be defined at trip creation time by the Fleet Manager.
`CreateTripView` must include waypoint entry (origin + stops + destination).
Without defined waypoints, route deviation detection cannot function.
Current state: No evidence of waypoint/stop entry in `CreateTripView` or `Trip` model beyond basic coordinates.

#### Finding 8: Post-Trip → View Previous Trips Navigation
Figma shows:
```
End the trip → View Previous Trips
```
Post-trip navigation must route the driver to `DriverTripHistoryView`.
`EndTripView` doesn't exist yet, and `DriverTripHistoryView` (2.9 KB stub) is not wired to any post-trip navigation trigger.

#### Finding 9: Driver "View Assigned Delivery Tasks" Flow
Figma shows:
```
Driver Dashboard → View Assigned Delivery Tasks → Has Assigned Trip?
  → No → No Trip Assigned → back to Driver Dashboard
```
This is the entry point to the driver's trip flow.

---

## 7. Supabase Security Audit

### Project: Sierra-FMS-v2 (ID: ldqcdngdlbbiojlnbnjg)

### 🔴 CRITICAL: 5 Tables With RLS Enabled But Zero Policies (SPRINT 2 BLOCKERS)

These tables will REJECT ALL reads and writes from the iOS client at runtime:

| Table | Sprint 2 Impact |
|-------|-----------------|
| `vehicle_location_history` | GPS publishing will fail. Every location update insert will be rejected. Live map cannot function. |
| `route_deviation_events` | Route deviation recording will fail. Deviation events cannot be written. |
| `notifications` | Entire notification system is blocked. No driver/fleet manager notifications can be delivered. |
| `spare_parts_requests` | Maintenance parts requests cannot be created or read. |
| `trip_expenses` | Fuel/toll receipt uploads will fail at the DB level. |

**SQL Fixes Required (must run BEFORE Sprint 2 testing):**

```sql
-- 1. vehicle_location_history
create policy "drivers insert own locations"
on vehicle_location_history
for insert
with check (driver_id = (select auth.uid())::uuid);

create policy "fleet managers read all locations"
on vehicle_location_history
for select
using (true);

-- 2. route_deviation_events
create policy "service insert route deviations"
on route_deviation_events
for insert
with check (true);

create policy "authenticated read route deviations"
on route_deviation_events
for select
using (true);

-- 3. notifications
create policy "recipients read own notifications"
on notifications
for select
using (recipient_id = (select auth.uid())::uuid);

create policy "service insert notifications"
on notifications
for insert
with check (true);

-- 4. spare_parts_requests
create policy "maintenance staff crud own spare parts"
on spare_parts_requests
for all
using (requested_by_id = (select auth.uid())::uuid);

-- 5. trip_expenses
create policy "drivers crud own expenses"
on trip_expenses
for all
using (driver_id = (select auth.uid())::uuid);
```

### 🟠 HIGH: 20 Tables With Fully Permissive RLS Policies (`USING(true)` WITH CHECK `(true)`)

Every core Sprint 2 table has `USING (true) WITH CHECK (true)` for ALL operations. This means any authenticated user can read, modify, or delete any other user's data. A driver can read all trips, all staff profiles, all maintenance records. This directly violates the SRS RBAC requirement.

**Affected tables:**
- `activity_logs` — policy: `activity_logs_all`, ALL operations, USING(true)
- `driver_profiles` — policy: `driver_profiles_all`, ALL, USING(true)
- `emergency_alerts` — policy: `emergency_alerts_all`, ALL, USING(true)
- `fuel_logs` — policy: `fuel_logs_all`, ALL, USING(true)
- `geofence_events` — policy: `geofence_events_all`, ALL, USING(true)
- `geofences` — policy: `geofences_all`, ALL, USING(true)
- `maintenance_profiles` — policy: `maintenance_profiles_all`, ALL, USING(true)
- `maintenance_records` — policy: `maintenance_records_all`, ALL, USING(true)
- `maintenance_tasks` — policy: `maintenance_tasks_all`, ALL, USING(true)
- `parts_used` — policy: `parts_used_all`, ALL, USING(true)
- `proof_of_deliveries` — policy: `proof_of_deliveries_all`, ALL, USING(true)
- `staff_applications` — policy: `staff_applications_all`, ALL, USING(true)
- `staff_members` — policy: `staff_members_insert_all`, INSERT, WITH CHECK(true)
- `staff_members` — policy: `staff_members_update_all`, UPDATE, USING(true)
- `trips` — policy: `trips_all`, ALL, USING(true)
- `two_factor_sessions` — policy: `two_factor_sessions_all`, ALL, USING(true)
- `vehicle_documents` — policy: `vehicle_documents_all`, ALL, USING(true)
- `vehicle_inspections` — policy: `vehicle_inspections_all`, ALL, USING(true)
- `vehicles` — policy: `vehicles_all`, ALL, USING(true)
- `work_orders` — policy: `work_orders_all`, ALL, USING(true)

**Assessment:** ChatGPT noted this is "not urgent" for sprint velocity. Claude disagrees for assessment purposes — the SRS explicitly mandates RBAC, and a marker reviewing the DB will flag this. For demo purposes these policies are acceptable short-term, but must be addressed before submission review.

**Example proper policy:**
```sql
-- trips: drivers see only their assigned trips
create policy "drivers see own trips"
on trips for select
using (driver_id = (select auth.uid())::uuid);

-- trips: fleet managers see all
create policy "fleet managers see all trips"
on trips for select
using (
    exists (
        select 1 from staff_members
        where auth_user_id = (select auth.uid())
        and role = 'fleet_manager'
    )
);
```

### 🟠 HIGH: 4 DB Trigger Functions With Mutable `search_path`

| Function | Risk |
|----------|----- |
| `public.check_resource_overlap` | Search path injection — prevents double-booking; if redirected, booking conflicts could be missed |
| `public.handle_trip_started` | Search path injection — vehicle status update trigger |
| `public.handle_trip_completed` | Search path injection — vehicle available status trigger |
| `public.handle_trip_cancelled` | Search path injection — vehicle status trigger |

**SQL Fix:**
```sql
alter function public.handle_trip_started() set search_path = public;
alter function public.handle_trip_completed() set search_path = public;
alter function public.handle_trip_cancelled() set search_path = public;
alter function public.check_resource_overlap() set search_path = public;
```

### 🟡 MEDIUM: Leaked Password Protection Disabled

Supabase Auth is not checking new passwords against HaveIBeenPwned. Since Sierra issues credentials to staff, compromised passwords could be silently accepted.

**Fix:** Enable in Supabase Dashboard → Authentication → Password Security → Enable leaked password protection.

---

## 8. Supabase Performance Audit

### 🔴 CRITICAL: `vehicle_location_history` Has Unindexed Foreign Keys on `driver_id` and `trip_id`

This is the highest-traffic table in Sprint 2. Every GPS publish writes a row at 5-second intervals. Querying location history for a trip (fleet manager live map) performs a full table scan without indexes. With multiple active trips, this table will have millions of rows within days.

**SQL Fix:**
```sql
create index idx_vlh_trip_id on public.vehicle_location_history(trip_id);
create index idx_vlh_driver_id on public.vehicle_location_history(driver_id);
```

**ChatGPT assessment:** Not urgent before sprint deadline. At 5-second throttle with 5 vehicles = 720 rows/hour/vehicle. Performance degradation will not occur immediately.

### 🟠 HIGH: 34 Total Unindexed Foreign Keys Across Critical Sprint 2 Tables

| Table | Missing FK Indexes | Impact |
|-------|--------------------|--------|
| `emergency_alerts` | trip_id, vehicle_id, acknowledged_by | Alert lookup by trip/vehicle slow |
| `maintenance_tasks` | created_by_admin_id, source_alert_id, source_inspection_id, approved_by_id | Task filtering full-scans |
| `geofence_events` | driver_id, trip_id | Geofence breach history slow |
| `route_deviation_events` | driver_id, vehicle_id, acknowledged_by | Deviation history slow |
| `spare_parts_requests` | maintenance_task_id, work_order_id, requested_by_id, reviewed_by | Parts filtering slow |
| `trips` | created_by_admin_id, pre_inspection_id, post_inspection_id, proof_of_delivery_id, rated_by_id | Trip joins slow |
| `trip_expenses` | trip_id, driver_id, vehicle_id | Expense listing slow |
| `vehicle_inspections` | driver_id, raised_task_id | Inspection history slow |
| `work_orders` | vehicle_id | Work order lookup slow |
| `geofences` | created_by_admin_id | Minor |
| `driver_profiles` | current_vehicle FK | Minor |
| `maintenance_records` | maintenance_task_id, performed_by_id | |
| `staff_applications` | reviewed_by | |

### 🟡 MEDIUM: RLS Policy Re-Evaluates `auth.uid()` Per Row

Table `staff_members`, policy `staff_members_delete_authenticated` re-evaluates `current_setting()` / `auth.uid()` for each row.

**Fix:**
```sql
-- Replace auth.uid() with (select auth.uid()) in the policy
```

### ℹ️ INFO: 30 Unused Indexes (Confirming Sprint 2 Not Yet Live)

Every Sprint 2-related index is currently unused, confirming no Sprint 2 data flows are active yet. Full list:

- `idx_staff_role` on `staff_members`
- `idx_staff_status` on `staff_members`
- `idx_staff_availability` on `staff_members`
- `idx_2fa_expires` on `two_factor_sessions`
- `idx_vehicles_status` on `vehicles`
- `idx_trips_scheduled` on `trips`
- `idx_inspect_result` on `vehicle_inspections`
- `idx_work_orders_status` on `work_orders`
- `idx_parts_work_order` on `parts_used`
- `idx_alerts_status` on `emergency_alerts`
- `idx_alerts_time` on `emergency_alerts`
- `idx_maint_tasks_status` on `maintenance_tasks`
- `idx_maint_rec_wo` on `maintenance_records`
- `idx_geofences_active` on `geofences`
- `idx_geo_events_geofence` on `geofence_events`
- `idx_geo_events_time` on `geofence_events`
- `idx_logs_type` on `activity_logs`
- `idx_logs_severity` on `activity_logs`
- `idx_logs_is_read` on `activity_logs`
- `idx_logs_timestamp` on `activity_logs`
- `idx_rde_trip_ack` on `route_deviation_events`
- `idx_notifications_recipient_read` on `notifications`
- `idx_trips_driver_status` on `trips`
- `idx_trips_vehicle_status` on `trips`
- `idx_notifications_recipient` on `notifications`
- `idx_emergency_alerts_status` on `emergency_alerts`

Note: `idx_trips_scheduled` — verify that `CreateTripView` uses `scheduled_at` in queries, otherwise this index may be permanently unused.

---

## 9. Feature Gaps Identified

### From GitHub Repository Analysis
1. No `TripViewModel` — the single most critical missing file
2. No `EndTripView` / end trip UI (FMS1-38)
3. No `ProofOfDeliveryViewModel` — 13 KB view with no ViewModel handling sequential uploads
4. No `SOSAlertViewModel` — 7.4 KB view with no ViewModel
5. No `FuelLogEntryView` — fuel/toll receipt upload (FMS1-48)
6. No `OdometerEntryView` — odometer recording before trip (FMS1-49)
7. No `RouteDeviationAlertView` — driver notification on deviation (FMS1-50)
8. No `MaintenanceRequestCreationView` (driver-side) (FMS1-47)
9. No `GeofenceViewModel` — `CreateGeofenceSheet` unwired
10. No `AlertsViewModel` — `AlertsInboxView` unwired
11. No `DashboardHomeViewModel` — 19 KB view with embedded logic
12. No `AnalyticsDashboardViewModel` — 32 KB view with embedded logic
13. No `DriverHistoryViewModel`
14. No `VehicleStatusViewModel`
15. No `MaintenanceRequestViewModel` (Fleet Manager approve/reject/assign)
16. No `MaintenanceTaskViewModel`
17. No `WorkOrderViewModel`
18. No `WorkOrderListView`
19. No `TaskStatusUpdateSheet`
20. No `VehicleServiceHistoryView`
21. No `VehicleServiceHistory` model
22. No `TripSummaryReport` model
23. No `DriverActivityReport` model
24. `DriverTripHistoryView` is a stub (2.9 KB) — no real data loading
25. `VehicleLocationService` may not implement 5-second throttle
26. No realtime subscription on any Sprint 2 table confirmed as active

### From Figma Analysis
27. Pre-trip inspection failure does not send alert to Fleet Manager
28. Maintenance approval is missing the "Assign Technician" step
29. `maintenance_tasks.assigned_to` field is never populated via UI
30. Maintenance completion does not trigger a notification to Fleet Manager
31. `NavigationHUDOverlay` does not have SOS/defect buttons accessible mid-trip
32. `CreateGeofenceSheet` does not implement full 4-step geofence creation flow
33. `CreateTripView` does not include waypoint/stop entry for route definition
34. Post-trip navigation does not route driver to `DriverTripHistoryView`
35. Mid-trip accident/defect flow is not explicitly connected to the HUD overlay

### From Supabase Analysis
36. `vehicle_location_history` has no RLS policies — all GPS writes will fail
37. `route_deviation_events` has no RLS policies — deviation writes will fail
38. `notifications` has no RLS policies — all notifications blocked
39. `spare_parts_requests` has no RLS policies — parts requests blocked
40. `trip_expenses` has no RLS policies — fuel/toll uploads blocked
41. `handle_trip_started`, `handle_trip_completed`, `handle_trip_cancelled`, `check_resource_overlap` all have mutable search_path
42. All 20 core tables have permissive `USING(true)` RLS — any user can access any other user's data
43. No error handling in `CreateTripViewModel` for `check_resource_overlap` constraint violation — will cause confusing crash if double-booking is attempted
44. Leaked password protection is disabled

### From Jira Analysis (stories with no implementation)
45. FMS1-17: Vehicle service history — no model, service, or view
46. FMS1-38: End trip — no view or ViewModel
47. FMS1-41: Update vehicle mileage — no dedicated UI
48. FMS1-45: SOS alert — view exists but no ViewModel
49. FMS1-46: Driver notifications for vehicle assignments — service exists but not wired
50. FMS1-47: Driver maintenance request creation — no view
51. FMS1-48: Fuel/toll receipt upload — no view
52. FMS1-49: Odometer recording — no UI
53. FMS1-55: Maintenance status update — no sheet UI

---

## 10. Missing Components

### Missing Swift Models
1. `VehicleServiceHistory` — needed for FMS1-17
2. `TripSummaryReport` — needed for FMS1-20/21
3. `DriverActivityReport` — needed for FMS1-21

### Missing Services
1. `RealtimeSubscriptionManager` — centralised realtime channel manager (ChatGPT: not needed for sprint)
2. `LocationThrottleManager` — 5-second throttle enforcement (may be inside VehicleLocationService; verify)
3. `RouteMatchingService` — compute deviation from planned waypoints

### Missing Views
1. `EndTripView` / `EndTripSheet` — FMS1-38
2. `MaintenanceRequestCreationView` (driver-side) — FMS1-47
3. `FuelLogEntryView` — FMS1-48
4. `OdometerEntryView` — FMS1-49, should be inside `StartTripSheet`
5. `RouteDeviationAlertView` — FMS1-50
6. `WorkOrderListView` — Maintenance module
7. `TaskStatusUpdateSheet` — FMS1-55
8. `VehicleServiceHistoryView` — FMS1-17

### Missing ViewModels (Full Exhaustive List)
1. `TripViewModel` — start, publish location, end, mileage (HIGHEST PRIORITY)
2. `PostTripInspectionViewModel`
3. `ProofOfDeliveryViewModel`
4. `SOSAlertViewModel`
5. `RouteDeviationViewModel`
6. `FuelLogViewModel`
7. `DriverTripHistoryViewModel`
8. `DashboardHomeViewModel`
9. `AlertsViewModel`
10. `GeofenceViewModel`
11. `VehicleStatusViewModel`
12. `MaintenanceRequestViewModel` (Fleet Manager side)
13. `AnalyticsDashboardViewModel`
14. `DriverHistoryViewModel`
15. `MaintenanceTaskViewModel`
16. `WorkOrderViewModel`

**ChatGPT trimmed priority list (minimum needed for Sprint 2):**
1. `TripViewModel` — yes
2. `ProofOfDeliveryViewModel` — yes
3. `SOSAlertViewModel` — yes
4. `MaintenanceApprovalViewModel` (or `MaintenanceRequestViewModel`) — yes
5. `AlertsViewModel` — yes

### Missing DB Interactions
1. Realtime subscription on `vehicle_location_history` (Fleet Manager live map)
2. Realtime subscription on `emergency_alerts` (Fleet Manager SOS inbox)
3. Realtime subscription on `route_deviation_events` (Fleet Manager route alerts)
4. Realtime subscription on `geofence_events` (Fleet Manager geofence alerts)
5. Realtime subscription on `maintenance_tasks` (Maintenance staff assigned requests)
6. RLS policies for 5 blocked tables (all inserts/reads fail without these)
7. Completion notification insert in `MaintenanceTaskService.completeTask()`
8. Fleet Manager alert insert in `PreTripInspectionViewModel` on inspection failure
9. `assigned_to` field population in maintenance approval flow
10. Error handling for `check_resource_overlap` constraint in `CreateTripViewModel`

---

## 11. Architecture Violations

| # | Violation | Location | Severity | Status |
|---|-----------|----------|----------|--------|
| 1 | `AppDataStore.swift` is 39 KB — single file containing all application state | Shared/Services/AppDataStore.swift | Debated — ChatGPT says acceptable | Not a problem for sprint |
| 2 | `FleetLiveMapViewModel` is only 2.7 KB — likely contains inline Supabase calls | FleetManager/ViewModels/ | 🔴 High | Needs audit |
| 3 | `sendEmail.swift` at root level — not in service folder, not namespaced | Sierra/sendEmail.swift | 🟡 Medium | Cleanup |
| 4 | `StaffApplicationStore.swift` (254 bytes) — duplicate mini-store next to AppDataStore | Shared/Services/ | 🟡 Medium | |
| 5 | No `RealtimeSubscriptionManager` — realtime channels likely opened ad hoc (ChatGPT: not needed) | Shared/Services/ | Debated | Not blocking |
| 6 | `VehicleLocationService.swift` is only 2.85 KB — almost certainly missing 5-second throttle rule | Shared/Services/ | 🔴 Critical | Verify immediately |
| 7 | `AnalyticsDashboardView.swift` is 32 KB — likely contains data loading logic | FleetManager/Views/ | 🔴 MVVM violation | Extract to VM |
| 8 | `AddVehicleView.swift` is 40 KB — almost certainly contains business logic | FleetManager/Views/ | 🔴 MVVM violation | Extract to VM |
| 9 | `CreateTripView.swift` is 27 KB with no `CreateTripViewModel` | FleetManager/Views/ | 🔴 MVVM violation | Extract to VM |
| 10 | `DashboardHomeView.swift` is 19 KB with no `DashboardHomeViewModel` | FleetManager/Views/ | 🔴 MVVM violation | Extract to VM |
| 11 | `StaffReviewSheet.swift` is 16 KB with only a 1.6 KB ViewModel | FleetManager/Views/ | 🟡 MVVM violation | |
| 12 | `ForcePasswordChangeView` calls `generateOTP()` — 2FA incorrectly appears during forced password change | Auth/ | 🔴 Auth bug | Fix in Sprint 2 |
| 13 | Face ID not appearing after sign-out (session token cleared on signOut()) | Auth/AuthManager.swift | 🔴 Auth bug | Fix in Sprint 2 |
| 14 | `ProofOfDeliveryView.swift` is 13.1 KB with no ViewModel — photo uploads likely not sequential | Driver/Views/ | 🔴 Critical | |
| 15 | 5 tables have RLS enabled but NO policies — all writes/reads fail at runtime | Supabase | 🔴 Sprint Blocker | Fix immediately |
| 16 | ALL tables have USING(true) permissive RLS — any user accesses any other user's data | Supabase | 🔴 Security Critical | |
| 17 | DB trigger functions have mutable search_path | Supabase | 🟠 Security High | |
| 18 | Pre-trip inspection passes with issues but no alert sent to Fleet Manager | Figma vs GitHub | 🔴 Feature Gap | |
| 19 | Maintenance approval missing "Assign maintenance personnel" step — assigned_to never populated | Figma vs GitHub | 🔴 Feature Gap | |
| 20 | `CreateTripView` has no waypoint/stop entry — route deviation detection cannot work without it | Figma vs GitHub | 🟠 Feature Gap | |
| 21 | No error handling for `check_resource_overlap` constraint violation in trip creation | Supabase vs GitHub | 🟠 Runtime Error Risk | |
| 22 | 34 missing FK indexes on high-traffic Sprint 2 tables | Supabase | 🟠 Performance | Not urgent |

---

## 12. Technical Risks

| Risk | Severity | Description |
|------|----------|-------------|
| 5 tables with no RLS policies | 🔴 Critical | GPS writes, deviation events, notifications, expenses all silently fail. Sprint 2 cannot be tested at all without fixing these. |
| VehicleLocationService throttle | 🔴 Critical | Without 5s throttle, GPS can fire at 1Hz = 3,600 writes/hour/vehicle. Will exhaust Supabase rate limits and free tier write capacity immediately. |
| TripViewModel missing | 🔴 Critical | Everything in the driver flow depends on this single ViewModel. No other driver Sprint 2 feature can be completed without it. |
| check_resource_overlap crash | 🟠 High | If demo creates two trips with the same vehicle/driver, the DB constraint throws with no error handler in the iOS app — confusing failure. |
| Mapbox Navigation wiring | 🟠 High | TripNavigationView is 2.8 KB, likely a stub. NavigationViewController creation rules need verification before demo. |
| OTP hash storage | 🟠 High | ProofOfDeliveryView (13 KB) without ViewModel — OTP may be stored as plaintext if view calls DB directly. |
| Sprint 2 deadline | 🟠 High | Sprint closes March 22 — 4 days from audit date (March 18) with 14+ missing components. |
| RBAC policies permissive | 🟡 Medium | All tables use USING(true). Any authenticated user can read all data. Grading risk for security requirement. |
| No Sprint 2 Architecture Spec | 🟡 Medium | The Sprint 2 Master Implementation Context referenced in the original audit request was not provided. Stage 4 could not be validated against its explicit rules. |
| AppDataStore 39 KB | Accepted | ChatGPT assessment: not a real problem for this stage. Normal for production SwiftUI MVVM apps. |
| Missing ViewModels (14) | Managed | ChatGPT trimmed to 5 critical ones. Others can stay in existing VMs. |

---

## 13. Sprint 2 Implementation Roadmap

### 🔴 P0 — Critical Infrastructure (Do First — Everything Depends on This)

**Task 0a** — Fix Supabase RLS for 5 blocked tables (SQL provided in Section 7)

**Task 0b** — Fix DB trigger search_path on 4 functions (SQL provided in Section 7)

**Task 0c** — Add FK indexes on `vehicle_location_history` (SQL in Section 8)

**Task 1** — Fix `ForcePasswordChangeView` 2FA bug: remove `generateOTP()` call

**Task 2** — Fix Face ID post-signout bug: restore `hasSessionToken()` check independently of biometric flag

**Task 3** — Create `TripViewModel` — single source of truth for active trip state:
- `startTrip()`
- Location publishing with 5s throttle verification
- `endTrip()`
- Mileage calculation
- Active trip state (`@Published var activeTrip: Trip?`)

**Task 4** — Verify and fix 5-second throttle in `VehicleLocationService.publishLocation()`

**Task 5** — Add `check_resource_overlap` error handling in `CreateTripViewModel` (catch constraint violation, show user-readable error)

### 🟠 P1 — Core Driver Flow

**Task 6** — Wire `StartTripSheet` → `TripViewModel.startTrip()` with pre-trip inspection gate

**Task 6a** — Wire `PreTripInspectionViewModel` failure path → create `emergency_alerts` record → notify Fleet Manager

**Task 7** — Implement `TripViewModel.endTrip()` + create `EndTripView`

**Task 8** — Create `ProofOfDeliveryViewModel`:
- Sequential photo upload
- OTP hash storage (NOT plaintext)
- Signature upload
- Wire to `ProofOfDeliveryView`

**Task 9** — Create `SOSAlertViewModel`:
- Capture GPS coordinates
- Write to `emergency_alerts` table
- Trigger Fleet Manager notification
- Wire to `SOSAlertSheet`

**Task 10** — Create `FuelLogEntryView` + `FuelLogViewModel`

**Task 11** — Add `OdometerEntryView` inside `StartTripSheet`

**Task 12** — Create `MaintenanceRequestCreationView` (driver-side) + wire to `MaintenanceTaskService`

**Task 13** — Implement route deviation alerting for driver (FMS1-50): use `RouteDeviationService` + create `RouteDeviationAlertView`

**Task 14** — Flesh out `DriverTripHistoryView` with real data loading via `DriverTripHistoryViewModel`

**Task 15** — Wire post-trip navigation to `DriverTripHistoryView` from `EndTripView`

**Task 16** — Add SOS and Defect buttons to `NavigationHUDOverlay` accessible mid-navigation

### 🟡 P2 — Fleet Manager Monitoring

**Task 17** — Implement realtime subscription on `vehicle_location_history` in `FleetLiveMapViewModel`

**Task 17a** — Add maintenance personnel assignment picker to `MaintenanceApprovalDetailView` — must populate `maintenance_tasks.assigned_to`

**Task 18** — Create `AlertsViewModel`:
- Subscribe to `emergency_alerts` realtime channel
- Subscribe to `route_deviation_events` realtime channel
- Subscribe to `geofence_events` realtime channel
- Wire to `AlertsInboxView`

**Task 19** — Create `GeofenceViewModel`:
- Create geofence (multi-step: start/end point, radius, zone type)
- Edit geofence
- Delete geofence
- Wire to `CreateGeofenceSheet`

**Task 20** — Create `VehicleStatusViewModel` — aggregate live vehicle states

**Task 20a** — Add route waypoint entry (origin + stops + destination) to `CreateTripView` / `CreateTripViewModel`

**Task 21** — Create `DashboardHomeViewModel` — extract logic from `DashboardHomeView` (19 KB)

**Task 22** — Implement driver deactivation in `StaffMemberService` + wire FMS1-8

### 🟡 P3 — Alerts System

**Task 23** — Wire `AlertsInboxView` to `AlertsViewModel` with realtime SOS/deviation/geofence streams

**Task 24** — Implement geofence breach detection in `GeofenceEventService` — subscribe to location updates, compare against active geofences

**Task 25** — Implement overdue maintenance alerts (FMS1-25) via `NotificationService`

**Task 26** — Wire `NotificationService` to driver for vehicle assignment notifications (FMS1-46)

### 🟢 P4 — Maintenance Workflow

**Task 27** — Create `MaintenanceRequestViewModel` — Fleet Manager approve/reject/assign flow

**Task 28** — Create `MaintenanceTaskViewModel`:
- Maintenance staff view assigned tasks
- Update status
- Log work
- Trigger completion notification to Fleet Manager

**Task 28a** — Add maintenance completion notification in `MaintenanceTaskService.completeTask()` — create `notifications` record for Fleet Manager

**Task 29** — Create `WorkOrderViewModel` + `WorkOrderListView`

**Task 30** — Add VIN scanner (camera + Vision framework) to `MaintenanceTaskDetailView`

**Task 31** — Create `TaskStatusUpdateSheet` (FMS1-55)

### 🔵 P5 — Dashboard & Analytics

**Task 32** — Create `AnalyticsDashboardViewModel` — extract all data loading from `AnalyticsDashboardView` (32 KB)

**Task 33** — Create `DriverHistoryViewModel` for `DriverHistoryView`

**Task 34** — Create `VehicleServiceHistoryView` + `VehicleServiceHistory` model (FMS1-17)

**Task 35** — Implement fleet usage report generation (FMS1-20)

### 🟣 P6 — Architecture Cleanup (Post-Sprint)

**Task 36** — Extract business logic from `AddVehicleView` (40 KB) into `AddVehicleViewModel`

**Task 37** — Extract business logic from `CreateTripView` (27 KB) into `CreateTripViewModel`

**Task 38** — Extract business logic from `AnalyticsDashboardView` into `AnalyticsDashboardViewModel`

---

## 14. Additional Observations — ChatGPT Review of Audit Findings

### Overall ChatGPT Assessment

| Area | Accuracy | Notes |
|------|----------|-------|
| GitHub architecture audit | ⭐⭐⭐⭐ | Mostly correct |
| Missing ViewModels analysis | ⭐⭐⭐⭐ | Very useful |
| Figma flow extraction | ⭐⭐⭐⭐ | Reasonable interpretation |
| Sprint story mapping | ⭐⭐⭐⭐ | Mostly accurate |
| Supabase security advisors | ⭐⭐⭐⭐⭐ | Most important section |
| Performance advisors | ⭐⭐⭐⭐ | Correct but less urgent |
| Architecture criticism | ⭐⭐⭐ | Some over-engineering suggestions |

**Overall reliability: ~80–85%**

### ChatGPT: Findings That Are Over-Engineering

**AppDataStore 39 KB criticism:**
- ChatGPT: "This is not a real problem. For an MVVM SwiftUI app, 30–50 KB store files are normal. Many production apps do this. Refactoring this during a sprint would slow you down. Ignore this for now."
- Claude agrees: Original flagging was premature for this stage.

**RealtimeSubscriptionManager:**
- ChatGPT: "Nice architecture idea but not necessary. Your current design with AppDataStore subscription methods is perfectly fine. Do NOT build a new manager mid-sprint."
- Claude agrees: Over-engineering suggestion for sprint deadline.

**14 Missing ViewModels:**
- ChatGPT: "That is overkill. You only need ViewModels for complex logic. Minimal set actually needed: TripViewModel, ProofOfDeliveryViewModel, SOSAlertViewModel, MaintenanceApprovalViewModel, AlertsViewModel."
- Claude partially agrees: The full list is correct for a complete implementation, but ChatGPT's trimmed list is correct for the sprint deadline.

**Performance Indexes:**
- ChatGPT: "Correct but not urgent. At 5-second throttle with 5 vehicles = 720 rows/hour/vehicle. No performance issues immediately."
- Claude agrees for sprint deadline, but `vehicle_location_history` indexes are still recommended before load testing.

### ChatGPT: Findings That Are Correct and Critical

**RLS Blocking Tables:**
- ChatGPT: "This is a real Supabase issue and happens often. This would break: Live vehicle tracking, Route deviation alerts, Notification system, Spare parts workflow, Fuel/toll logging. You must add policies BEFORE testing Sprint 2."

**Pre-Trip Inspection Alert Flow:**
- ChatGPT: "Claude correctly caught this from Figma. This is a legitimate missing business rule."

**Maintenance Approval Missing Assign Technician:**
- ChatGPT: "Another real missing piece."

### ChatGPT: What Claude Didn't Check Properly

**VehicleLocationService throttle:**
- ChatGPT: "Claude assumed it might not throttle correctly. You must verify this. Without throttle you could generate 10k writes per hour."
- This must be manually verified in the working repo (mantosh23/Sierra) as the public docs repo may not have the latest implementation.

### Claude's Counter-Assessment of ChatGPT's Review

**Disagreement 1: Permissive RLS urgency**
- ChatGPT said permissive `USING(true)` is "not urgent"
- Claude disagrees: The SRS explicitly mandates role-based access control. A marker reviewing the database will flag this. This is a grading risk, not just production hygiene.

**Disagreement 2: check_resource_overlap crash**
- ChatGPT did not mention this
- Claude flags it: If a demo creates two trips assigning the same vehicle or driver, the DB throws a constraint violation that `CreateTripViewModel` has no error handler for. The demo will silently fail. One `do/catch` block is needed.

**Agreement with ChatGPT overall:** The audit was calibrated for completeness and correctness. ChatGPT's review correctly recalibrated it for sprint velocity. Both assessments are valid depending on whether the goal is finishing by March 22 or preparing for grading review.

---

## 15. Corrected Priorities (Post-ChatGPT Review)

### Final Priority Order for Finishing Sprint 2

**Step 1: Fix Supabase RLS policies (before any Swift code)**
- vehicle_location_history
- route_deviation_events
- notifications
- spare_parts_requests
- trip_expenses

**Step 2: Implement TripViewModel**
- This is the central piece everything connects to

**Step 3: Finish driver trip lifecycle**
```
PreTripInspection → alert on failure
StartTrip
Navigation (with SOS/Defect accessible)
ProofOfDelivery
PostTripInspection
EndTrip → DriverTripHistoryView
```

**Step 4: Implement FleetLiveMapView with realtime subscription**

**Step 5: Implement AlertsInboxView with realtime subscriptions**

**Step 6: Finish Maintenance approval flow with technician assignment**

**Step 7 (if time): Route waypoints in CreateTripView**

**Step 8 (if time): check_resource_overlap error handling**

### Sprint 2 Remaining Work Summary (after ChatGPT calibration)

**Core driver flow:**
- Trip start
- Trip end
- Pre-trip inspection (+ fleet manager alert on failure)
- Post-trip inspection
- Proof of delivery
- SOS alerts

**Fleet manager monitoring:**
- Live vehicle map (realtime)
- Geofence creation
- Alerts inbox (realtime)
- Maintenance approval (+ technician assignment)

**Maintenance workflow:**
- Assign technician
- Complete work order
- Status update sheet

---

## 16. Implementation Recommendations

### TripViewModel — Recommended Architecture

```swift
@Observable
final class TripViewModel {
    
    // Active trip state
    var activeTrip: Trip? = nil
    var isNavigating: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // Location throttle
    private var lastPublishTime: Date? = nil
    private let locationThrottleInterval: TimeInterval = 5.0
    
    func startTrip(_ trip: Trip) async throws {
        isLoading = true
        defer { isLoading = false }
        try await TripService.startTrip(tripId: trip.id)
        // Do NOT manually update vehicle status — DB trigger handles it
        activeTrip = trip
        isNavigating = true
    }
    
    func publishLocation(lat: Double, lng: Double, tripId: UUID, driverId: UUID, vehicleId: UUID) async {
        guard shouldPublish() else { return }
        lastPublishTime = Date()
        do {
            try await VehicleLocationService.publishLocation(
                tripId: tripId, driverId: driverId, vehicleId: vehicleId,
                latitude: lat, longitude: lng
            )
        } catch {
            // Non-fatal — log but don't surface to user
            print("📍 Location publish failed: \(error)")
        }
    }
    
    private func shouldPublish() -> Bool {
        guard let last = lastPublishTime else { return true }
        return Date().timeIntervalSince(last) >= locationThrottleInterval
    }
    
    func endTrip(tripId: UUID, endMileage: Double) async throws {
        isLoading = true
        defer { isLoading = false }
        try await TripService.endTrip(tripId: tripId, endMileage: endMileage)
        // Do NOT manually update vehicle status — DB trigger handles it
        activeTrip = nil
        isNavigating = false
    }
}
```

### PreTripInspection Alert Addition

```swift
// Inside PreTripInspectionViewModel.submit()
if inspectionResult == .failed {
    try await EmergencyAlertService.createAlert(
        type: .defect,
        tripId: tripId,
        vehicleId: vehicleId,
        driverId: driverId,
        description: "Pre-trip inspection failure",
        notes: failedItems.map(\.description).joined(separator: ", ")
    )
}
```

### Maintenance Technician Assignment UI

```swift
// Inside MaintenanceApprovalDetailView or MaintenanceRequestViewModel
@State private var selectedTechnician: StaffMember? = nil

Picker("Assign Technician", selection: $selectedTechnician) {
    Text("Select technician").tag(Optional<StaffMember>.none)
    ForEach(maintenanceStaff) { tech in
        Text(tech.fullName).tag(Optional(tech))
    }
}

// On approve:
if let tech = selectedTechnician {
    try await MaintenanceTaskService.approve(
        taskId: task.id,
        assignedTo: tech.id
    )
}
```

### check_resource_overlap Error Handling

```swift
// Inside CreateTripViewModel.createTrip()
do {
    try await TripService.createTrip(trip)
} catch let error as PostgrestError where error.code == "P0001" {
    // DB constraint violation from check_resource_overlap
    errorMessage = "This vehicle or driver is already assigned to another trip at this time."
} catch {
    errorMessage = "Failed to create trip: \(error.localizedDescription)"
}
```

### ProofOfDelivery Sequential Upload

```swift
// Inside ProofOfDeliveryViewModel — photos must be sequential, NOT concurrent
func submitDelivery() async throws {
    var uploadedPhotoUrls: [String] = []
    
    // Sequential — not async let, not TaskGroup
    for photo in photos {
        let url = try await StorageService.uploadPhoto(photo, bucket: "proof-of-delivery")
        uploadedPhotoUrls.append(url)
    }
    
    let otpHash = CryptoService.hash(otp) // NEVER store raw OTP
    
    let proof = ProofOfDelivery(
        tripId: tripId,
        photoUrls: uploadedPhotoUrls,
        signatureUrl: signatureUrl,
        otpHash: otpHash, // Store hash, not raw value
        deliveredAt: Date()
    )
    try await ProofOfDeliveryService.submit(proof)
}
```

### Realtime Subscription Pattern for AlertsViewModel

```swift
@Observable
final class AlertsViewModel {
    
    var sosAlerts: [EmergencyAlert] = []
    var deviationEvents: [RouteDeviationEvent] = []
    var geofenceBreaches: [GeofenceEvent] = []
    
    private var subscriptionTask: Task<Void, Never>? = nil
    
    func startListening() {
        subscriptionTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.subscribeToSOS() }
                group.addTask { await self.subscribeToDeviations() }
                group.addTask { await self.subscribeToGeofenceBreaches() }
            }
        }
    }
    
    func stopListening() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }
    
    deinit {
        stopListening()
    }
}
```

### Mapbox NavigationViewController Rule

```swift
// CORRECT — only in makeUIViewController
struct TripNavigationView: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> NavigationViewController {
        // NavigationViewController MUST only be created here
        let navigationController = NavigationViewController(for: routeResponse, routeIndex: 0, routeOptions: options)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: NavigationViewController, context: Context) {
        // Do not recreate NavigationViewController here
    }
}

// WRONG — never call Mapbox Directions API reactively
.onChange(of: destination) { _ in
    fetchDirections() // ❌ This is wrong
}
```

---

## 17. Final Sprint-2 Completion Strategy

### "Do This Tonight" Order (March 18–22 Sprint Window)

**Hour 1 — Unblock the Database (Run These SQL Commands in Supabase Dashboard)**

```sql
-- Block 1: RLS policies for 5 blocked tables
create policy "drivers insert own" on vehicle_location_history
  for insert with check (driver_id = (select auth.uid())::uuid);
create policy "fleet managers read all" on vehicle_location_history
  for select using (true);

create policy "service insert" on route_deviation_events
  for insert with check (true);
create policy "authenticated read" on route_deviation_events
  for select using (true);

create policy "recipients read own" on notifications
  for select using (recipient_id = (select auth.uid())::uuid);
create policy "service insert" on notifications
  for insert with check (true);

create policy "maint staff crud own" on spare_parts_requests
  for all using (requested_by_id = (select auth.uid())::uuid);

create policy "drivers crud own" on trip_expenses
  for all using (driver_id = (select auth.uid())::uuid);

-- Block 2: Fix trigger search_path
alter function public.handle_trip_started() set search_path = public;
alter function public.handle_trip_completed() set search_path = public;
alter function public.handle_trip_cancelled() set search_path = public;
alter function public.check_resource_overlap() set search_path = public;
```

**Hours 2–3 — Create TripViewModel.swift**
- Implement: `startTrip()`, `endTrip()`, `publishLocation()` with 5s throttle, `activeTrip` state
- Verify VehicleLocationService existing throttle implementation
- Place at: `Sierra/Driver/ViewModels/TripViewModel.swift`

**Hours 4–5 — Wire Driver Trip Lifecycle**
- Wire `StartTripSheet` → `TripViewModel.startTrip()`
- Add failure alert to `PreTripInspectionViewModel`
- Create `ProofOfDeliveryViewModel` with sequential uploads + OTP hash
- Create `SOSAlertViewModel` with GPS capture

**Hours 6–7 — Fleet Manager Monitoring**
- Wire realtime subscription in `FleetLiveMapViewModel`
- Create `AlertsViewModel` with three realtime channels

**Hours 8–9 — Maintenance Approval + Completion**
- Add staff picker to `MaintenanceApprovalDetailView`
- Create `MaintenanceTaskViewModel`
- Add completion notification in `MaintenanceTaskService.completeTask()`

**Everything else** (reports, analytics, trip history, service history, VIN scanner) is lower priority and can be done after the critical path above is complete.

### Key Non-Negotiable Rules During Implementation
- Never manually update vehicle status from iOS — DB triggers handle it
- Location publishing must be throttled to minimum 5 seconds
- Mapbox Directions API calls must never be reactive
- `NavigationViewController` must only be created in `makeUIViewController`
- All photo uploads must be sequential
- OTP must only store hash in DB (use `CryptoService`)
- AppDataStore must remain `@Observable` singleton
- Supabase client must always be the global `supabase` instance

---

*Document generated: March 18, 2026. Sources: Jira FMS1 (79 stories), GitHub Kanishk101/Sierra main branch, FigJam board b77le46eYMiVfLuHcwMGdW, Supabase project ldqcdngdlbbiojlnbnjg security and performance advisors, SRS v2.0 by Prasad B S.*

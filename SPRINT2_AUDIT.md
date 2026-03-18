# Sierra Fleet Management System — Sprint 2 Complete Implementation Audit

> **Audit Date:** 2026-03-18
> **Sprint 2 Deadline:** 2026-03-22 (4 days remaining)
> **Auditor:** Claude (Senior Software Architect + Technical Project Auditor + iOS Systems Engineer)
> **Sources Analysed:** GitHub/main · Jira FMS1 (79 stories) · Supabase migrations · SRS v2 · Figma FigJam board (b77le46eYMiVfLuHcwMGdW) · Sprint scope photo

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Figma Board Analysis — Stage 1](#2-figma-board-analysis--stage-1)
3. [Sprint 1 Implementation Status](#3-sprint-1-implementation-status)
4. [Sprint 2 Required Features](#4-sprint-2-required-features)
5. [Jira Story Implementation Matrix](#5-jira-story-implementation-matrix)
6. [Supabase Backend Capability Map](#6-supabase-backend-capability-map)
7. [Repository Architecture Review](#7-repository-architecture-review)
8. [Missing Components](#8-missing-components)
9. [Security Findings](#9-security-findings)
10. [Performance Findings](#10-performance-findings)
11. [Architecture Violations](#11-architecture-violations)
12. [Sprint 2 Implementation Roadmap](#12-sprint-2-implementation-roadmap)
13. [Recommended File Structure](#13-recommended-file-structure)
14. [Exact Implementation Tasks](#14-exact-implementation-tasks)

---

## 1. System Overview

Sierra is an iOS Fleet Management System (SwiftUI + MVVM + Supabase + Mapbox) for three roles:
**Fleet Manager**, **Driver**, and **Maintenance Personnel**.

| Domain | Sprint 1 Status | Sprint 2 Status |
|---|---|---|
| Fleet Manager — Auth & Vehicle CRUD | ✅ Done | N/A |
| Fleet Manager — Staff Management | ✅ Done | N/A |
| Fleet Manager — Trip Creation | ✅ Done | N/A |
| Fleet Manager — Live Map (realtime) | ⚠️ UI shell exists | Backend realtime NOT wired |
| Fleet Manager — Geofence Create/Manage | ⚠️ Create sheet exists | No list/edit/event listener |
| Fleet Manager — Route Definition in Trip | ⚠️ CreateTripView exists | Route waypoints/polyline unverified |
| Fleet Manager — Alerts Inbox | ⚠️ UI shell exists | No realtime subscription |
| Fleet Manager — Maintenance Approval | ⚠️ UI shell exists | Approve/reject DB call unverified |
| Fleet Manager — Vehicle Reassignment | ❌ Missing | No reassignment flow after inspection fail |
| Driver — Auth & Profile | ✅ Done | N/A |
| Driver — Pre-Trip Inspection | ⚠️ In Review | Sequential photo upload guarantee unverified |
| Driver — Trip Navigation (Mapbox) | ⚠️ Partial | Location throttle unverified |
| Driver — Proof of Delivery | ⚠️ Partial | OTP hash rule unverified |
| Driver — SOS / Defect Alerts | ⚠️ Partial | No realtime push to FM |
| Driver — Create Maintenance Request | ❌ Missing | Not built |
| Driver — Fuel Logging | ❌ Missing | Service exists, no view |
| Driver — Geofence Notifications | ❌ Missing | No client monitor |
| Maintenance — Dashboard | ⚠️ Partial | ViewModel is stub |
| Maintenance — Task Update | ⚠️ Partial | DB save call not wired |
| Supabase Realtime | ❌ Missing | Zero subscription infrastructure |
| DB Triggers | ⚠️ Partial | 2 migrations present; trip→status triggers absent from repo |

---

## 2. Figma Board Analysis — Stage 1

### Board Structure

The FigJam board (`b77le46eYMiVfLuHcwMGdW`) contains:

| Element | Content |
|---|---|
| Red sticky (Sprint 1 scope) | Secure Login + 2FA, Role Verification, FM: Staff/Vehicle/Trip, Driver: Onboarding/Availability/Profile, Maintenance: Onboarding/Profile |
| Section: "Sprint 1" (node 45:1020) | Combined flowchart covering ALL three roles including Sprint 2 flows — mislabelled; the sticky notes are the authoritative sprint boundaries |
| Section: "Sprint 2" (node 138:1455) | Text block confirming Sprint 2 scope (matches photo provided) |
| Sticky: "Sprint 3" (node 223:453) | Empty — Sprint 3 not yet planned |
| Screenshot node (24:246) | App UI mock screenshot |
| Mermaid diagram (23:318) | Architecture/sequence diagram |

### ⚠️ INCONSISTENCY FOUND — Figma Section Label vs Sprint Sticky

The Figma section is titled **"Sprint 1"** but its flowchart contains all Sprint 2 flows (geofencing, live tracking, maintenance approval, pre-trip inspection, proof of delivery, SOS). The **sticky notes are the authoritative source** for sprint boundaries. The section is a single combined system flow diagram, not a Sprint 1-only diagram.

**Impact:** Zero feature scope change — the sticky notes match the photo you shared. This is a documentation issue in Figma only.

---

### UI Flow Map Extracted from Figma

#### Authentication Flow (Sprint 1 — All Roles)

```
Start
  → Login Screen (Email, Password, Forgot Password)
  → Validate Credentials
  → [Invalid] → Show Login Error → back to Login
  → [Valid] → Send OTP for 2FA
  → OTP Verification Screen
  → Validate OTP
  → [Invalid] → Show OTP Error → Retry/Request New
  → [Valid] → Detect User Role
      → Fleet Manager Dashboard
      → Driver [First Login? → Change Password → OTP → Driver Dashboard]
      → Maintenance [First Login? → Change Password → OTP → Maintenance Dashboard]
```

---

#### Fleet Manager Flow (Sprint 1 + Sprint 2)

```
Fleet Manager Dashboard
  → Select Action
      ├── Staff Management (Sprint 1)
      │     Add Staff → Enter Name/Email → Generate Password
      │     → Send Credentials to Email → Approve or Reject Profile
      │
      ├── Vehicle Management (Sprint 1)
      │     Select Action → Add Vehicle / Edit Details / Update Status
      │
      ├── Trip Management (Sprint 1)
      │     Create Trip → Assign Driver → Assign Vehicle → Schedule → Trip Created
      │
      ├── Geofencing (Sprint 2) ← ⭐ KEY FLOW
      │     Create Geofence → Define Start and End Point
      │     → Define Radius → Create Zones
      │     → Alerts when vehicle moves out of zone
      │
      ├── Monitor Live Trip (Sprint 2) ← ⭐ KEY FLOW
      │     Create the specified route to follow
      │     → Perform live tracking
      │     → Get alerts when route not followed
      │
      ├── Maintenance Management (Sprint 2) ← ⭐ KEY FLOW
      │     Approve maintenance request
      │     → Assign maintenance personnel
      │     → Monitor maintenance process
      │     → Get alert when maintenance completed
      │     → Vehicle status updated as available (DB trigger)
      │
      ├── AI Powered Maintenance (Sprint 3 — future)
      │     Receive automatic alerts based on expiry + distance
      │
      └── Assigns new vehicle for the trip (Sprint 2) ← ⭐ KEY FLOW
            [Triggered when pre-trip inspection fails → FM reassigns vehicle]
```

---

#### Driver Flow (Sprint 2)

```
Driver Dashboard → Select Action
  ├── Update Availability Status (Sprint 1)
  │
  ├── View Assigned Delivery Tasks → Has Assigned Trip?
  │     [No] → No Trip Assigned → back
  │     [Yes] → ...
  │
  ├── Perform Pre-Trip Inspection (Sprint 2) ← ⭐
  │     → Issue Found?
  │         [Yes] → Send alert to Fleet Manager → (FM assigns new vehicle)
  │         [No]  → Start the Trip
  │
  ├── Follow the Route (Sprint 2) ← ⭐
  │     → Get alerts when route not followed
  │     → Complete Delivery
  │
  ├── Upload Delivery Proof (Sprint 2) ← ⭐
  │     → Upload picture of delivered goods
  │     → End the trip
  │     → View Previous Trips
  │
  ├── Perform Post-Trip Inspection (Sprint 2) ← ⭐
  │     → Issue Found?
  │         [Yes] → Raise maintenance request → [goes to FM Maintenance Management]
  │         [No]  → Vehicle status gets updated as available (DB trigger)
  │
  └── Accident/Defect? (Sprint 2) ← ⭐ (SOS/Defect)
        [Yes] → Send Automatic alert to admin
        [No]  → Continue with the Trip
```

---

#### Maintenance Flow (Sprint 2 — Figma Scope)

```
Maintenance Dashboard → Select Action
  → View maintenance request
  → Start maintenance
  → Update maintenance status
  → Complete maintenance task
```

> **IMPORTANT:** Figma Sprint 2 scope for Maintenance is ONLY these 4 steps.
> Spare parts requests, VIN scanner, and repair images are **SRS requirements** but are **NOT** in the Figma Sprint 2 scope.
> These should be deprioritised for Sprint 2 and moved to Sprint 3 backlog.

---

### NEW FINDINGS from Figma (Delta vs Previous Audit)

| # | Finding | Impact |
|---|---|---|
| F1 | **Vehicle Reassignment Flow** — When pre-trip inspection fails, FM assigns a new vehicle for the trip. This is an explicit Sprint 2 flow in Figma with no corresponding implementation in repo. | Missing: reassignment action in `AlertDetailView` or new `VehicleReassignmentSheet` |
| F2 | **Route Definition is FM responsibility** — Figma shows FM creates the specified route, which driver then follows. `CreateTripView` (27 KB) may not include a route/waypoint drawing step. If route isn't saved as waypoints to DB, the follow-route feature cannot work. | Must verify `CreateTripView` includes Mapbox route drawing + DB storage of route geometry |
| F3 | **Post-trip inspection → maintenance request is a circular flow** — Post-trip fail → maintenance request → FM approval → assign staff → complete → vehicle available. This circular flow must be architecturally coherent. | `PostTripInspectionView` must navigate to driver maintenance request creation, which then triggers FM alert |
| F4 | **Figma section label "Sprint 1" is misleading** — All flows including Sprint 2 are in the same section. Authoritative sprint scope = sticky notes. | Documentation issue, zero feature impact |
| F5 | **Maintenance Sprint 2 scope is simpler than SRS** — Figma shows only 4 steps (view, start, update, complete). Spare parts, VIN scanner, repair images are Sprint 3. | Remove those from Sprint 2 priority; adjust roadmap |
| F6 | **"Get alert when maintenance completed" goes back to vehicle status update** — Figma explicitly connects maintenance completion to vehicle status becoming Available. Must be DB trigger. | Confirms trigger requirement in Task B2 |
| F7 | **No "Fuel Logging" in Figma Sprint 2** — Fuel logging appears in SRS and Jira (FMS1-48) but is NOT in the Sprint 2 Figma scope section. | Move fuel logging to lower priority / Sprint 3 |
| F8 | **Geofence scope = Create + Define radius + Create zones + Alert on exit** — The Figma geofence flow is more detailed than "draw a polygon". It has: define start/end point, define radius (circular geofence?), create zones. This suggests a **radius-based geofence**, not polygon. `CreateGeofenceSheet.swift` must support this. | Verify `CreateGeofenceSheet` supports radius/circle geofences, not just polygon |

---

## 3. Sprint 1 Implementation Status

### ✅ Confirmed Implemented

| Story | Feature | Evidence |
|---|---|---|
| FMS1-1 | Add vehicle | `AddVehicleView.swift` (40 KB) |
| FMS1-2 | Edit vehicle | `VehicleService.swift` |
| FMS1-3 | Delete vehicle | `VehicleService.swift` |
| FMS1-4 | View all vehicles | `VehicleListView.swift` |
| FMS1-5 | Search vehicles | `VehicleListView.swift` |
| FMS1-6 | Register drivers | `CreateStaffView.swift` |
| FMS1-7 | Approve driver profile | `StaffReviewSheet.swift` + `StaffApprovalViewModel` |
| FMS1-8 | Deactivate drivers | `StaffMemberService.swift` |
| FMS1-18 | Upload pre-trip photos | `PreTripInspectionView.swift` + `VehicleInspectionService` |
| FMS1-31–35 | Driver auth + profile | Auth module + `DriverProfilePage1/2View` |
| FMS1-43 | Report defects | `IncidentReportSheet.swift` |
| FMS1-51–52 | Maintenance auth | Auth module |
| FMS1-71 | Create trips | `CreateTripView.swift` (27 KB) |
| FMS1-72 | Check driver/vehicle availability | `check_resource_overlap()` DB function |
| FMS1-73 | Driver views assigned trip | `DriverTripsListView.swift` |
| FMS1-74 | Driver starts trip | `StartTripSheet.swift` |
| FMS1-75 | Driver sets availability | `DriverHomeView.swift` |
| FMS1-76 | FM login/logout | Auth module |

### Supabase Sprint 1 Confirmed

- `vehicle_status` enum + `Busy` value (migration 1)
- `staff_availability` enum + `Busy` value (migration 1)
- `check_resource_overlap()` function — double-booking prevention (migration 2)

---

## 4. Sprint 2 Required Features

Reconciled from: **Figma Sprint 2 sticky** + **photo** + **SRS** + **Jira** (Figma is authoritative for sprint boundary)

### Fleet Manager Dashboard

| # | Feature | Source | Jira |
|---|---|---|---|
| FM-1 | Create Geofence (start/end point + radius + zones) | Figma ✅ | FMS1-9, 14 |
| FM-2 | Define route of trip (waypoints in CreateTripView) | Figma ✅ | FMS1-39 |
| FM-3 | Monitor live trip (vehicle pin moves via realtime) | Figma ✅ | FMS1-11 |
| FM-4 | Alert when route not followed | Figma ✅ | FMS1-12 |
| FM-5 | Alert when vehicle enters/exits geofence zone | Figma ✅ | FMS1-14, 15 |
| FM-6 | Receive SOS alerts | Figma ✅ | FMS1-15 |
| FM-7 | Receive defect/inspection-fail alerts | Figma ✅ | FMS1-15 |
| FM-8 | Approve maintenance requests | Figma ✅ | FMS1-13 |
| FM-9 | Reject maintenance requests | SRS/Jira | FMS1-16 |
| FM-10 | Assign new vehicle after inspection fail | Figma ✅ | — (implicit) |
| FM-11 | Get alert when maintenance completed | Figma ✅ | — |

### Driver Dashboard

| # | Feature | Source | Jira |
|---|---|---|---|
| D-1 | Pre-trip inspection (pass/fail) | Figma ✅ | FMS1-36 |
| D-2 | Start trip | Figma ✅ | FMS1-37 |
| D-3 | Follow assigned route (Mapbox turn-by-turn) | Figma ✅ | FMS1-39 |
| D-4 | Live location publish (5-sec throttle) | Architecture rule | FMS1-11 |
| D-5 | Complete delivery | Figma ✅ | FMS1-40 |
| D-6 | Upload proof of delivery (photo + OTP hash) | Figma ✅ | FMS1-44 |
| D-7 | Post-trip inspection | Figma ✅ | FMS1-36 |
| D-8 | End trip | Figma ✅ | FMS1-38 |
| D-9 | Raise SOS / defect alert | Figma ✅ | FMS1-45, 43 |
| D-10 | Create maintenance request (post-trip fail) | Figma ✅ | FMS1-47 |
| D-11 | View previous trips | Figma ✅ | FMS1-42, 79 |
| D-12 | Get notified on geofence entry/exit | Figma ✅ | FMS1-77, 78 |
| D-13 | Get notified on route deviation | Figma ✅ | FMS1-50 |

> **Downgraded from Sprint 2 (not in Figma Sprint 2 scope):**
> - Fuel logging (FMS1-48) → Sprint 3
> - Odometer recording (FMS1-49) → Sprint 3

### Maintenance Personnel Dashboard

| # | Feature | Source | Jira |
|---|---|---|---|
| M-1 | View assigned maintenance requests | Figma ✅ | FMS1-53 |
| M-2 | Start maintenance (update status to In Progress) | Figma ✅ | FMS1-55 |
| M-3 | Add status updates / repair notes | Figma ✅ | FMS1-57 |
| M-4 | Complete maintenance task | Figma ✅ | FMS1-56 |

> **Downgraded from Sprint 2 (SRS only, NOT in Figma Sprint 2):**
> - Spare parts requests (FMS1-61, 62) → Sprint 3
> - Repair image upload (FMS1-58) → Sprint 3
> - VIN scanner (SRS 4.3.3) → Sprint 3
> - Filter by vehicle/status (FMS1-63, 64) → Sprint 3

---

## 5. Jira Story Implementation Matrix

### Fleet Manager Module

| Story ID | Summary | Sprint | Jira Status | Implementation |
|---|---|---|---|---|
| FMS1-1 | Add vehicle | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-2 | Edit vehicle | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-3 | Delete vehicle | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-4 | View all vehicles | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-5 | Search vehicles | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-6 | Register drivers | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-7 | Approve driver profile | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-8 | Deactivate drivers | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-9 | Define geofences | 2 | To Do | ⚠️ PARTIALLY — `CreateGeofenceSheet` exists; radius/circle support unverified; no list/edit/event listener |
| FMS1-10 | Driver history | 2 | To Do | ⚠️ PARTIALLY — `DriverHistoryView` exists; data queries may not be connected |
| FMS1-11 | Live vehicle tracking | 2 | In Review | ⚠️ PARTIALLY — `FleetLiveMapView` exists; realtime NOT wired |
| FMS1-12 | Route deviation alerts | 2 | In Progress | ⚠️ PARTIALLY — `RouteDeviationService` exists; no realtime FM listener |
| FMS1-13 | Approve maintenance requests | 2 | In Progress | ⚠️ PARTIALLY — `MaintenanceApprovalDetailView` exists; approve Supabase call unverified |
| FMS1-14 | Geofence event monitoring | 2 | To Do | ❌ NOT IMPLEMENTED — No geofence event listener |
| FMS1-15 | SOS and defect alerts | 2 | To Do | ⚠️ PARTIALLY — `AlertsInboxView` exists; no realtime subscription |
| FMS1-16 | Reject maintenance requests | 2 | In Progress | ⚠️ PARTIALLY — Reject path likely in `MaintenanceApprovalDetailView`; unverified |
| FMS1-19 | Vehicle status view | 2 | To Do | ⚠️ PARTIALLY — `VehicleStatusView` exists; freshness unverified |
| FMS1-24 | Dashboard summary stats | 2 | To Do | ⚠️ PARTIALLY — `DashboardHomeView` exists; no live DB stat queries |
| FMS1-71 | Create trips | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-72 | Driver/vehicle availability check | 1 | Done | ✅ FULLY IMPLEMENTED |
| — | Vehicle reassignment after inspection fail | 2 | — | ❌ NOT IMPLEMENTED — No flow exists in repo |

### Driver Module

| Story ID | Summary | Sprint | Jira Status | Implementation |
|---|---|---|---|---|
| FMS1-18 | Upload pre-trip photos | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-31–35 | Auth + profile | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-36 | Pre-trip inspection | 2 | In Review | ⚠️ PARTIALLY — View + VM exist; sequential photo upload guarantee unverified |
| FMS1-37 | Start trip | 2 | In Review | ⚠️ PARTIALLY — `StartTripSheet` exists; trigger dependency unverified |
| FMS1-38 | End trip | 2 | In Progress | ⚠️ PARTIALLY — No dedicated EndTripView; logic in DriverHomeView unclear |
| FMS1-39 | See assigned route | 2 | To Do | ⚠️ PARTIALLY — Mapbox nav exists; route polyline from DB unverified |
| FMS1-40 | Mark delivery complete | 2 | In Progress | ⚠️ PARTIALLY — `ProofOfDeliveryView` exists; completion DB call unverified |
| FMS1-42 | Trip history | 2 | To Do | ⚠️ PARTIALLY — `DriverTripHistoryView` is stub (2.9 KB) |
| FMS1-43 | Report defects | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-44 | Upload proof of delivery | 2 | To Do | ⚠️ PARTIALLY — View exists; OTP hash rule compliance unverified |
| FMS1-45 | SOS alert | 2 | To Do | ⚠️ PARTIALLY — `SOSAlertSheet` + service exist; no realtime push to FM |
| FMS1-47 | Create maintenance request | 2 | To Do | ❌ NOT IMPLEMENTED |
| FMS1-50 | Route deviation notification | 2 | To Do | ⚠️ PARTIALLY — Service exists; client-side detection in coordinator unverified |
| FMS1-73–75 | View trip / start trip / availability | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-77 | Geofence entry notification | 2 | To Do | ❌ NOT IMPLEMENTED |
| FMS1-78 | Geofence exit notification | 2 | To Do | ❌ NOT IMPLEMENTED |
| FMS1-79 | View previous trips | 2 | To Do | ⚠️ PARTIALLY — view is stub |

### Maintenance Module

| Story ID | Summary | Sprint | Jira Status | Implementation |
|---|---|---|---|---|
| FMS1-51–52 | Auth | 1 | Done | ✅ FULLY IMPLEMENTED |
| FMS1-53 | View assigned tasks | 2 | To Do | ⚠️ PARTIALLY — `MaintenanceDashboardView` + stub VM; connectivity unverified |
| FMS1-54 | View vehicle issue details | 2 | To Do | ⚠️ PARTIALLY — `MaintenanceTaskDetailView` (18 KB) exists |
| FMS1-55 | Update status | 2 | To Do | ⚠️ PARTIALLY — Service has update method; VM wiring absent |
| FMS1-56 | Mark complete | 2 | To Do | ⚠️ PARTIALLY — In detail view; DB trigger unverified |
| FMS1-57 | Add repair notes | 2 | To Do | ⚠️ PARTIALLY — `MaintenanceRecordService` exists; not wired to VM |
| FMS1-58 | Repair images | **Sprint 3** | To Do | ❌ MOVED TO SPRINT 3 (not in Figma Sprint 2) |
| FMS1-61–62 | Spare parts | **Sprint 3** | To Do | ❌ MOVED TO SPRINT 3 (not in Figma Sprint 2) |
| FMS1-63–64 | Filters | **Sprint 3** | To Do | ❌ MOVED TO SPRINT 3 |

---

## 6. Supabase Backend Capability Map

### Tables → Features

| Table | Feature | Status |
|---|---|---|
| `vehicles` | Vehicle CRUD, status | ✅ Ready — enum has 'Busy' |
| `staff_members` | Staff accounts, availability | ✅ Ready — enum has 'Busy' |
| `trips` | Trip dispatch, overlap check | ✅ Ready |
| `vehicle_location_history` | Live tracking | ⚠️ Table likely exists; no realtime in app |
| `geofences` | Geofence create/edit | ⚠️ Table likely exists; client listener missing |
| `geofence_events` | Geofence breach alerts | ⚠️ Model exists; no realtime subscription |
| `route_deviation_events` | Route deviation alerts | ⚠️ Model + service exist; no FM push |
| `emergency_alerts` | SOS alerts | ⚠️ Model + service exist; no FM realtime |
| `maintenance_tasks` | Maintenance assignments | ⚠️ Partially wired |
| `maintenance_records` | Repair notes | ⚠️ Service exists |
| `work_orders` | Work order management | ⚠️ Model + service exist |
| `proof_of_deliveries` | POD | ⚠️ View + service; OTP hash unverified |
| `sierra_notifications` | In-app notifications | ⚠️ Model exists; no realtime listener |

### Confirmed DB Functions

| Function | Purpose | Status |
|---|---|---|
| `check_resource_overlap()` | Double-booking prevention | ✅ Deployed (migration 2) |

### ❌ CRITICAL — Missing DB Trigger Migrations

The rule: **"Never manually update vehicle status when trip status changes — DB triggers handle it."**
Zero trigger SQL files exist in the repository.

| Expected Trigger | Purpose |
|---|---|
| `on_trip_started` | vehicle → Busy, driver → Busy |
| `on_trip_completed` | vehicle → Available, driver → Available |
| `on_trip_cancelled` | revert vehicle/driver status |
| `on_maintenance_approved` | vehicle → In Maintenance |
| `on_maintenance_completed` | vehicle → Available *(Figma explicitly shows this)* |

### Missing Realtime Subscriptions

| Table | Who Subscribes | Event |
|---|---|---|
| `vehicle_location_history` | Fleet Manager | INSERT → update map pin |
| `emergency_alerts` | Fleet Manager | INSERT → SOS banner |
| `route_deviation_events` | Fleet Manager | INSERT → deviation alert |
| `geofence_events` | Fleet Manager | INSERT → geofence alert |
| `maintenance_tasks` | Maintenance Staff | UPDATE → dashboard refresh |
| `sierra_notifications` | Driver, Maintenance | INSERT → in-app notification |

---

## 7. Repository Architecture Review

### Structure

```
Sierra/
├── Auth/                         ✅
├── Driver/ (Views: 15, VMs: 3)   ⚠️ Under-VMd
├── FleetManager/ (Views: 25, VMs: 3)  ⚠️ Under-VMd
├── Maintenance/ (Views: 7, VMs: 2)    ⚠️ Under-VMd
└── Shared/
    ├── Models/   26 models  ✅
    ├── Services/ 32 services ✅
    ├── Components/
    ├── Theme/
    └── Views/
```

**ViewModel deficit:** 47 views, only 8 ViewModels. Most views call services directly → MVVM violation.

**AppDataStore** is 39 KB — god-object storing all state. Acceptable per the @Observable singleton rule for Sprint 2 but must be refactored in Sprint 3.

**No centralised Realtime subscription manager exists.** There is no evidence of `.channel()` / `.subscribe()` calls wired into app lifecycle.

---

## 8. Missing Components

### Missing Services (Sprint 2 critical)

| Service | Purpose | Priority |
|---|---|---|
| `LocationPublishingService` | Throttled 5-sec GPS publish during active trip | 🔴 CRITICAL |
| `RealtimeSubscriptionManager` | Centralised channel lifecycle | 🔴 CRITICAL |
| `GeofenceMonitorService` | Client-side geofence enter/exit detection | 🟠 High |
| `DriverMaintenanceRequestService` | Driver creates maintenance request | 🟠 High |

### Missing Views (Sprint 2)

| View | Module | Jira | Priority |
|---|---|---|---|
| `DriverMaintenanceRequestView` | Driver | FMS1-47 | 🔴 CRITICAL |
| `VehicleReassignmentSheet` | Fleet Manager | Figma F1 | 🔴 CRITICAL |
| `RouteDeviationBannerView` | Driver | FMS1-50 | 🟠 High |
| `GeofenceListView` | Fleet Manager | FMS1-9, 14 | 🟠 High |
| `GeofenceEventHistoryView` | Fleet Manager | FMS1-14 | 🟡 Medium |

### Missing ViewModels (Sprint 2)

| ViewModel | Module | Priority |
|---|---|---|
| `DriverHomeViewModel` | Driver | 🔴 CRITICAL |
| `AlertsViewModel` | Fleet Manager | 🔴 CRITICAL |
| `MaintenanceTaskDetailViewModel` | Maintenance | 🔴 CRITICAL |
| `ProofOfDeliveryViewModel` | Driver | 🟠 High |
| `SOSAlertViewModel` | Driver | 🟠 High |
| `GeofenceViewModel` | Fleet Manager | 🟠 High |
| `MaintenanceApprovalViewModel` | Fleet Manager | 🟠 High |
| `PostTripInspectionViewModel` | Driver | 🟡 Medium |

### Missing Database Interactions

| Interaction | Priority |
|---|---|
| `vehicle_location_history` INSERT throttled 5s | 🔴 CRITICAL |
| `vehicle_location_history` Realtime subscription (FM) | 🔴 CRITICAL |
| `emergency_alerts` Realtime subscription (FM) | 🔴 CRITICAL |
| `route_deviation_events` Realtime subscription (FM) | 🟠 High |
| `geofence_events` Realtime subscription (FM) | 🟠 High |
| `maintenance_tasks` UPDATE (status, notes) | 🟠 High |
| `maintenance_tasks` Realtime subscription | 🟠 High |
| `proof_of_deliveries` INSERT (OTP hash only) | 🟠 High |
| Route geometry stored in `trips` table | 🟠 High (Figma F2) |

---

## 9. Security Findings

### 🔴 CRITICAL — No RLS Migration Files

Zero Row Level Security policy files in `supabase/migrations/`. Without RLS, any authenticated user can read/write all rows in all tables.

- Driver A can read Driver B's location history
- Maintenance staff can modify trip records
- Any authenticated user can read all SOS alerts

**Fix:** Create `20260318000005_add_rls_policies.sql`

### 🔴 HIGH — OTP Storage Rule Unverified

Rule: "OTP must only store hash in DB"

`CryptoService.swift` (1.3 KB) exists but without source inspection, raw OTP persistence cannot be ruled out. `TwoFactorSessionService` must be audited to confirm SHA-256 hash is stored, never the raw value.

### 🟠 HIGH — `anon` Role Can Call `check_resource_overlap()`

Migration 2 grants EXECUTE to `anon`. Scheduling data must not be accessible to unauthenticated users.

```sql
-- Fix in migration 20260318000007_revoke_anon_overlap.sql
REVOKE EXECUTE ON FUNCTION check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM anon;
```

### 🟡 MEDIUM — `.DS_Store` Committed to Repository

`.DS_Store` at both repo root and `Sierra/` leak directory structure.

```bash
echo "**/.DS_Store" >> .gitignore
git rm --cached .DS_Store Sierra/.DS_Store
```

### 🟡 MEDIUM — DB Triggers Not Managed as Migrations

If triggers exist only in the Supabase dashboard (manually applied), they will be lost on any schema reset and cannot be audited.

---

## 10. Performance Findings

### 🔴 CRITICAL — Location Publish Throttle Unverified

Rule: "Location publishing must be throttled to 5 seconds"

`VehicleLocationService.swift` (2.8 KB) exists. If publishing is triggered on every Mapbox delegate callback (~0.5–1s), this will:
- Flood `vehicle_location_history` with 5–10x excess rows
- Exhaust Supabase insert rate limits with concurrent active trips
- Drain device battery rapidly

Must confirm a `Task.sleep(for: .seconds(5))` loop or `Timer(timeInterval: 5)` pattern.

### 🟠 HIGH — Missing Indexes

No index migration files exist in the repository.

```sql
-- Required indexes (migration 20260318000006_add_indexes.sql):
CREATE INDEX idx_vlh_vehicle_id  ON vehicle_location_history(vehicle_id);
CREATE INDEX idx_vlh_trip_id     ON vehicle_location_history(trip_id);
CREATE INDEX idx_vlh_recorded_at ON vehicle_location_history(recorded_at DESC);
CREATE INDEX idx_rde_trip_id     ON route_deviation_events(trip_id);
CREATE INDEX idx_ge_vehicle_id   ON geofence_events(vehicle_id);
CREATE INDEX idx_ge_geofence_id  ON geofence_events(geofence_id);
CREATE INDEX idx_mt_assigned_to  ON maintenance_tasks(assigned_to);
CREATE INDEX idx_trips_driver_id ON trips(driver_id);
CREATE INDEX idx_trips_status    ON trips(status);
```

### 🟡 MEDIUM — Mapbox Directions API Reactive Call Risk

Rule: "Mapbox Directions API calls must never be reactive"

`TripNavigationCoordinator.swift` (15 KB) must not call Mapbox Directions inside a computed property, `onChange`, or Combine publisher. Must be a one-time call triggered by explicit user action.

---

## 11. Architecture Violations

| # | Violation | Rule | Risk |
|---|---|---|---|
| V1 | Only 8 ViewModels for 47 Views | MVVM separation | Views call services directly |
| V2 | `StaffApplicationStore` is a second Observable store | AppDataStore singleton | State fragmentation |
| V3 | `sendEmail.swift` at root level, separate from `EmailService.swift` | Project structure | Dead code risk |
| V4 | No DB trigger migrations in repo | Never manually update vehicle status | Triggers may not exist; manual status updates may be in code |
| V5 | `anon` role granted overlap-check access | Role-based access rules | Security violation |
| V6 | No Realtime subscription infrastructure | Realtime subscription handling | All live features non-functional |
| V7 | `NavigationViewController` creation location unverified | Only in `makeUIViewController` | Mapbox rendering bugs |
| V8 | Photo upload sequential guarantee unverified | All photo uploads must be sequential | Race conditions, partial upload failures |
| V9 | `.DS_Store` files committed | Git hygiene | Metadata leak |

---

## 12. Sprint 2 Implementation Roadmap

> **4 days: 18–22 March 2026**
> Figma-revised scope removes fuel logging, odometer, spare parts, VIN scanner, repair images from Sprint 2.

### Day 1 — Critical Infrastructure (18 March)

| Task | Area |
|---|---|
| B1: Create trip status DB triggers migration | Supabase |
| B2: Create maintenance status DB triggers migration | Supabase |
| B3: Create indexes migration | Supabase |
| B4: Revoke anon from overlap function | Supabase |
| S1: Implement `LocationPublishingService` (5-sec throttle) | Shared/Services |
| S2: Implement `RealtimeSubscriptionManager` | Shared/Services |
| S3: Wire realtime channels into `AppDataStore` + `SierraApp` | Shared/Services |

### Day 2 — Core Driver Flow (19 March)

| Task | Area |
|---|---|
| S4: Create `DriverHomeViewModel` | Driver/ViewModels |
| S5: Verify `StartTripSheet` uses trigger (not manual status update) | Driver/Views |
| S6: Wire `LocationPublishingService.startPublishing()` on trip Active | TripNavigationCoordinator |
| S7: Create `ProofOfDeliveryViewModel` (sequential photo + OTP hash) | Driver/ViewModels |
| S8: Create `DriverMaintenanceRequestView` (post-trip inspection fail → FM) | Driver/Views |
| S9: Verify `TwoFactorSessionService` stores only OTP hash | Shared/Services |
| S10: Complete `DriverTripHistoryView` — query trips filtered by driver_id | Driver/Views |

### Day 3 — Fleet Manager Monitoring (20 March)

| Task | Area |
|---|---|
| S11: Wire `FleetLiveMapView` to realtime vehicle location updates | FleetManager/ViewModels |
| S12: Create `AlertsViewModel` — subscribe to SOS, deviation, geofence | FleetManager/ViewModels |
| S13: Wire `AlertsInboxView` to `AlertsViewModel` realtime stream | FleetManager/Views |
| S14: Create `VehicleReassignmentSheet` — FM reassigns vehicle after inspection fail | FleetManager/Views |
| S15: Verify `CreateGeofenceSheet` supports radius/circle geofence (Figma F8) | FleetManager/Views |
| S16: Create `GeofenceListView` — list, activate, delete geofences | FleetManager/Views |
| S17: Complete `MaintenanceApprovalDetailView` — wire approve/reject to service | FleetManager/Views |

### Day 4 — Maintenance + Polish (21–22 March)

| Task | Area |
|---|---|
| S18: Create `MaintenanceTaskDetailViewModel` — load, update status, add notes | Maintenance/ViewModels |
| S19: Wire `MaintenanceDashboardViewModel` to realtime `maintenance_tasks` | Maintenance/ViewModels |
| S20: Wire `MaintenanceTaskDetailView` save actions to ViewModel | Maintenance/Views |
| S21: Insert `sierra_notifications` on task complete (notifies FM) | Shared/Services |
| S22: Wire `DashboardHomeView` stats to live DB queries | FleetManager/Views |
| S23: Merge `StaffApplicationStore` into `AppDataStore` | Shared/Services |
| S24: Move `sendEmail.swift` into `EmailService.swift` | Shared/Services |
| S25: Create RLS policies migration | Supabase |
| S26: Git cleanup — remove .DS_Store, update .gitignore | Git |

---

## 13. Recommended File Structure

```
Sierra/
├── SierraApp.swift
├── ContentView.swift
│
├── Auth/
│   └── Views/
│       ├── LoginView.swift
│       └── ForgotPasswordView.swift
│
├── Driver/
│   ├── DriverTabView.swift
│   ├── Views/
│   │   ├── DriverHomeView.swift
│   │   ├── DriverTripsListView.swift
│   │   ├── DriverTripHistoryView.swift        ← Complete stub
│   │   ├── TripDetailDriverView.swift
│   │   ├── StartTripSheet.swift
│   │   ├── TripNavigationContainerView.swift
│   │   ├── TripNavigationView.swift
│   │   ├── NavigationHUDOverlay.swift
│   │   ├── PreTripInspectionView.swift
│   │   ├── PostTripInspectionView.swift
│   │   ├── ProofOfDeliveryView.swift
│   │   ├── SOSAlertSheet.swift
│   │   ├── IncidentReportSheet.swift
│   │   ├── DriverMaintenanceRequestView.swift  ← CREATE (Sprint 2)
│   │   ├── RouteDeviationBannerView.swift      ← CREATE (Sprint 2)
│   │   ├── DriverProfileSetupView.swift
│   │   ├── DriverProfilePage1View.swift
│   │   ├── DriverProfilePage2View.swift
│   │   └── DriverApplicationSubmittedView.swift
│   └── ViewModels/
│       ├── DriverHomeViewModel.swift           ← CREATE (Sprint 2)
│       ├── DriverProfileViewModel.swift
│       ├── PreTripInspectionViewModel.swift
│       ├── PostTripInspectionViewModel.swift   ← CREATE (Sprint 2)
│       ├── ProofOfDeliveryViewModel.swift      ← CREATE (Sprint 2)
│       ├── SOSAlertViewModel.swift             ← CREATE (Sprint 2)
│       └── TripNavigationCoordinator.swift
│
├── FleetManager/
│   ├── AdminDashboardView.swift
│   ├── FleetManagerTabView.swift
│   ├── Views/
│   │   ├── DashboardHomeView.swift
│   │   ├── FleetLiveMapView.swift
│   │   ├── VehicleMapDetailSheet.swift
│   │   ├── VehicleListView.swift
│   │   ├── VehicleDetailView.swift
│   │   ├── VehicleStatusView.swift
│   │   ├── AddVehicleView.swift
│   │   ├── StaffTabView.swift
│   │   ├── StaffListView.swift
│   │   ├── StaffReviewSheet.swift
│   │   ├── CreateStaffView.swift
│   │   ├── DriverHistoryView.swift
│   │   ├── TripsListView.swift
│   │   ├── TripDetailView.swift
│   │   ├── CreateTripView.swift               ← Verify route waypoints saved to DB
│   │   ├── AlertsInboxView.swift
│   │   ├── AlertDetailView.swift
│   │   ├── MaintenanceRequestsView.swift
│   │   ├── MaintenanceApprovalDetailView.swift
│   │   ├── PendingApprovalsView.swift
│   │   ├── CreateGeofenceSheet.swift          ← Verify radius/circle support
│   │   ├── GeofenceListView.swift             ← CREATE (Sprint 2)
│   │   ├── VehicleReassignmentSheet.swift     ← CREATE (Sprint 2 — Figma F1)
│   │   ├── ReportsView.swift
│   │   ├── AnalyticsDashboardView.swift
│   │   ├── QuickActionsSheet.swift
│   │   └── AdminProfileView.swift
│   └── ViewModels/
│       ├── CreateStaffViewModel.swift
│       ├── StaffApprovalViewModel.swift
│       ├── FleetLiveMapViewModel.swift         ← Wire realtime
│       ├── AlertsViewModel.swift               ← CREATE (Sprint 2)
│       ├── GeofenceViewModel.swift             ← CREATE (Sprint 2)
│       └── MaintenanceApprovalViewModel.swift  ← CREATE (Sprint 2)
│
├── Maintenance/
│   ├── MaintenanceTabView.swift
│   ├── Views/
│   │   ├── MaintenanceDashboardView.swift
│   │   ├── MaintenanceTaskDetailView.swift     ← Wire to new VM
│   │   ├── SparePartsRequestSheet.swift        → Sprint 3
│   │   ├── MaintenanceProfileSetupView.swift
│   │   ├── MaintenanceProfilePage1View.swift
│   │   ├── MaintenanceProfilePage2View.swift
│   │   └── MaintenanceApplicationSubmittedView.swift
│   └── ViewModels/
│       ├── MaintenanceDashboardViewModel.swift ← Wire realtime
│       ├── MaintenanceProfileViewModel.swift
│       └── MaintenanceTaskDetailViewModel.swift ← CREATE (Sprint 2)
│
├── Shared/
│   ├── Models/
│   │   └── [all 26 existing models]
│   ├── Services/
│   │   ├── AppDataStore.swift                  ← Add realtime channel wiring
│   │   ├── SupabaseManager.swift
│   │   ├── LocationPublishingService.swift      ← CREATE (5-sec throttle)
│   │   ├── RealtimeSubscriptionManager.swift    ← CREATE
│   │   ├── GeofenceMonitorService.swift         ← CREATE
│   │   ├── EmailService.swift                   ← Merge sendEmail.swift here
│   │   └── [all other existing services]
│   ├── Components/
│   ├── Theme/
│   └── Views/
│
supabase/
└── migrations/
    ├── 20260315000001_add_busy_status.sql          ✅ exists
    ├── 20260315000002_add_overlap_check_fn.sql      ✅ exists
    ├── 20260318000003_add_trip_triggers.sql         ← CREATE
    ├── 20260318000004_add_maintenance_triggers.sql  ← CREATE
    ├── 20260318000005_add_rls_policies.sql          ← CREATE
    ├── 20260318000006_add_indexes.sql               ← CREATE
    └── 20260318000007_revoke_anon_overlap.sql       ← CREATE
```

---

## 14. Exact Implementation Tasks

### Backend / Supabase

**Task B1 — Trip Status Triggers**

```sql
-- supabase/migrations/20260318000003_add_trip_triggers.sql
CREATE OR REPLACE FUNCTION handle_trip_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status = 'Active' AND OLD.status != 'Active' THEN
    UPDATE vehicles      SET status       = 'Busy'      WHERE id::text = NEW.vehicle_id;
    UPDATE staff_members SET availability = 'Busy'      WHERE id::text = NEW.driver_id;
  ELSIF NEW.status IN ('Completed', 'Cancelled') THEN
    UPDATE vehicles      SET status       = 'Available' WHERE id::text = NEW.vehicle_id;
    UPDATE staff_members SET availability = 'Available' WHERE id::text = NEW.driver_id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trip_status_change_trigger
  AFTER UPDATE OF status ON trips
  FOR EACH ROW EXECUTE FUNCTION handle_trip_status_change();
```

**Task B2 — Maintenance Status Triggers**

```sql
-- supabase/migrations/20260318000004_add_maintenance_triggers.sql
CREATE OR REPLACE FUNCTION handle_maintenance_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status = 'Approved' AND OLD.status != 'Approved' THEN
    UPDATE vehicles SET status = 'In Maintenance' WHERE id::text = NEW.vehicle_id;
  ELSIF NEW.status = 'Completed' THEN
    UPDATE vehicles SET status = 'Available' WHERE id::text = NEW.vehicle_id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER maintenance_status_change_trigger
  AFTER UPDATE OF status ON maintenance_tasks
  FOR EACH ROW EXECUTE FUNCTION handle_maintenance_status_change();
```

**Task B3 — Indexes**

```sql
-- supabase/migrations/20260318000006_add_indexes.sql
CREATE INDEX idx_vlh_vehicle_id  ON vehicle_location_history(vehicle_id);
CREATE INDEX idx_vlh_trip_id     ON vehicle_location_history(trip_id);
CREATE INDEX idx_vlh_recorded_at ON vehicle_location_history(recorded_at DESC);
CREATE INDEX idx_rde_trip_id     ON route_deviation_events(trip_id);
CREATE INDEX idx_ge_vehicle_id   ON geofence_events(vehicle_id);
CREATE INDEX idx_ge_geofence_id  ON geofence_events(geofence_id);
CREATE INDEX idx_mt_assigned_to  ON maintenance_tasks(assigned_to);
CREATE INDEX idx_trips_driver_id ON trips(driver_id);
CREATE INDEX idx_trips_status    ON trips(status);
```

**Task B4 — Revoke anon**

```sql
-- supabase/migrations/20260318000007_revoke_anon_overlap.sql
REVOKE EXECUTE ON FUNCTION check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM anon;
```

### iOS / Swift

**Task S1 — LocationPublishingService.swift**
- Receives CLLocation from `TripNavigationCoordinator`
- **Must use** `Task { while isPublishing { await publish(); try await Task.sleep(for: .seconds(5)) } }`
- Calls `supabase.from("vehicle_location_history").insert(...)` — global `supabase` instance only
- Stops immediately on `stopPublishing()` call
- Never publishes when trip is not Active

**Task S2 — RealtimeSubscriptionManager.swift**
- @Observable class managing Supabase Realtime channels
- Channels: `vehicle-locations`, `emergency-alerts`, `route-deviations`, `geofence-events`, `maintenance-updates`, `notifications`
- `startSubscriptions()` called from `AppDataStore` after successful auth
- `stopSubscriptions()` called on logout, cancels all channels

**Task S3 — DriverHomeViewModel.swift**
- Reads `AppDataStore.currentDriver`, `AppDataStore.assignedTrip`
- `toggleAvailability()` → `StaffMemberService.updateAvailability()`
- **Does NOT** manually set vehicle status — trigger handles it
- Provides `startTrip()` → `TripService.startTrip()` → trigger fires automatically

**Task S4 — AlertsViewModel.swift**
- Observes `AppDataStore.emergencyAlerts`, `.routeDeviationEvents`, `.geofenceEvents`
- `markRead(id:)` → Supabase UPDATE
- `computedUnreadCount: Int` for badge
- All three alert types surfaced in `AlertsInboxView` with type-based icons

**Task S5 — MaintenanceTaskDetailViewModel.swift**
- `loadTask(id:)` → `MaintenanceTaskService.fetchTask(id:)`
- `updateStatus(to:)` → `MaintenanceTaskService.updateStatus()` — **does NOT** touch vehicles table
- `addNote(text:)` → `MaintenanceRecordService.addRecord()`
- `completeTask()` → sets status to Completed → trigger sets vehicle to Available → inserts into `sierra_notifications`

**Task S6 — VehicleReassignmentSheet.swift (NEW — Figma F1)**
- Sheet presented from `AlertDetailView` when alert type is `inspection_fail`
- Shows list of Available vehicles (filtered from `AppDataStore.vehicles`)
- On confirm → `TripService.reassignVehicle(tripId:newVehicleId:)`
- Dismisses and updates `AlertDetailView` to show reassignment confirmed

**Task S7 — DriverMaintenanceRequestView.swift**
- Fields: issue description, severity (Low/Medium/High/Critical), vehicle (pre-filled from trip)
- Photos: sequential capture using `for photo in photos { await upload(photo) }` — never `async let`
- Submit → `MaintenanceTaskService.createRequest(...)` with `requested_by_driver: true`
- On success → insert `sierra_notifications` for Fleet Manager

**Task S8 — ProofOfDeliveryViewModel.swift**
- `uploadPhotos(_ photos: [Data]) async`: sequential loop, not concurrent
- OTP flow: `CryptoService.sha256(rawOTP)` → store ONLY hash in `two_factor_sessions.otp_hash`
- **Never** store raw OTP string
- On POD complete → `TripService.completeDelivery(tripId:)` → trigger handles status

**Task S9 — Wire FleetLiveMapViewModel Realtime**
- Remove any `Timer`-based polling currently in `FleetLiveMapViewModel`
- Replace with observation of `AppDataStore.vehicleLocations` (fed by `RealtimeSubscriptionManager`)
- Update Mapbox annotation positions on each `@Observable` change

**Task S10 — GeofenceListView + GeofenceViewModel**
- `GeofenceViewModel`: CRUD geofences via `GeofenceService`, loads `AppDataStore.geofences`
- `GeofenceListView`: list with active/inactive toggle, swipe to delete, tap to edit
- `CreateGeofenceSheet` must be verified to save radius (circle) geometry — Figma F8 shows radius-based geofence, not polygon

---

## Appendix — Implementation Rules Compliance Checklist

| Rule | Status | Finding |
|---|---|---|
| Supabase client = global `supabase` instance | ✅ `SupabaseManager` provides singleton | Assumed compliant |
| Never manually update vehicle status | ❌ VIOLATION RISK | No trigger migrations in repo |
| Location publishing throttled to 5 seconds | ⚠️ UNVERIFIED | `VehicleLocationService` exists; throttle not confirmed |
| Mapbox Directions API never reactive | ⚠️ UNVERIFIED | `TripNavigationCoordinator` 15 KB — must audit |
| NavigationViewController only in `makeUIViewController` | ⚠️ UNVERIFIED | `TripNavigationView` 2.8 KB — must audit |
| All photo uploads sequential | ⚠️ UNVERIFIED | Multiple upload services present |
| OTP stores only hash in DB | ⚠️ UNVERIFIED | `CryptoService` exists; enforcement not confirmed |
| AppDataStore = @Observable singleton | ❌ VIOLATION | `StaffApplicationStore` is a second store |

---

*End of Sprint 2 Audit Report — Sierra Fleet Management System*
*Generated: 2026-03-18 | Sources: GitHub/main + Jira FMS1 (79 stories) + Supabase migrations + SRS v2 + Figma FigJam b77le46eYMiVfLuHcwMGdW*

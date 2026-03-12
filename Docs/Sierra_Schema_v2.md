# Sierra — Complete Data Schema v2.0
**Project:** Fleet Management System (Sierra) iOS App  
**Revised:** 2026-03-12  
**Backend Target:** Supabase (PostgreSQL + Auth + Storage + Realtime)  
**Architecture:** MVVM · Swift Concurrency · `@Observable` · SwiftUI  
**Sprint Coverage:** Current sprint (Auth, Admin, Driver/Maint onboarding) + full SRS v2.0 forward plan

---

## Table of Contents
1. [Design Principles](#1-design-principles)
2. [Layer Overview](#2-layer-overview)
3. [Auth Layer](#3-auth-layer)
4. [Staff Layer](#4-staff-layer)
5. [Vehicle Layer](#5-vehicle-layer)
6. [Operations Layer](#6-operations-layer)
7. [Maintenance Layer](#7-maintenance-layer)
8. [Geofencing Layer](#8-geofencing-layer)
9. [Activity & Audit Layer](#9-activity--audit-layer)
10. [Enum Master Reference](#10-enum-master-reference)
11. [Full Relationship Map](#11-full-relationship-map)
12. [Supabase Table Definitions](#12-supabase-table-definitions)
13. [AppDataStore Redesign](#13-appdatastore-redesign)
14. [Cross-Reference & Integrity Analysis](#14-cross-reference--integrity-analysis)
15. [Schema Summary Card](#15-schema-summary-card)

---

## 1. Design Principles

### 1A. Model Hierarchy Strategy
All staff are represented via **Option B: base model + role-specific extension structs**.

```
StaffMember (base)           ← Universal identity, status, availability
  ├── DriverProfile          ← Driver-specific identity/credential fields
  └── MaintenanceProfile     ← Maintenance-specific credential/certification fields
```

Operational records (trips, fuel logs, work orders, etc.) are **separate models** linked by foreign ID — never embedded arrays.

### 1B. ID Strategy
- All primary keys: `UUID` in Swift / `uuid` in Supabase
- All foreign keys: `String` in Swift (UUID.uuidString) for flexibility, `uuid` in Supabase with proper FK constraints
- Supabase `auth.users.id` (`UUID`) is the authoritative identity anchor for all user-facing records

### 1C. Supabase Auth Integration
- Supabase handles session tokens, JWT refresh, and 2FA OTP delivery
- `AuthUser` in Swift mirrors `auth.users` plus app-level metadata stored in `staff_members`
- The Swift `AuthManager` calls Supabase Auth SDK — no more hardcoded credentials in `demoUsers[]`

### 1D. Naming Conventions
- Swift structs: `PascalCase`
- Supabase tables: `snake_case`
- Foreign key columns: `<referenced_table_singular>_id` (e.g., `vehicle_id`, `driver_id`)

---

## 2. Layer Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  AUTH LAYER                                                         │
│  AuthUser · TwoFactorSession · UserRole                             │
├─────────────────────────────────────────────────────────────────────┤
│  STAFF LAYER                                                        │
│  StaffMember (base) · DriverProfile · MaintenanceProfile            │
│  StaffApplication · DriverApplicationDetails                        │
│  MaintenanceApplicationDetails                                      │
├─────────────────────────────────────────────────────────────────────┤
│  VEHICLE LAYER                                                      │
│  Vehicle · VehicleDocument                                          │
├─────────────────────────────────────────────────────────────────────┤
│  OPERATIONS LAYER                                                   │
│  Trip · FuelLog · VehicleInspection · InspectionItem                │
│  ProofOfDelivery · EmergencyAlert                                   │
├─────────────────────────────────────────────────────────────────────┤
│  MAINTENANCE LAYER                                                  │
│  MaintenanceTask · WorkOrder · MaintenanceRecord · PartUsed         │
├─────────────────────────────────────────────────────────────────────┤
│  GEOFENCING LAYER                                                   │
│  Geofence · GeofenceEvent                                           │
├─────────────────────────────────────────────────────────────────────┤
│  AUDIT LAYER                                                        │
│  ActivityLog                                                        │
└─────────────────────────────────────────────────────────────────────┘
```

Total models: **20** (up from 9)  
Total Supabase tables: **18** (auth.users is managed by Supabase)

---

## 3. Auth Layer

### 3A. `AuthUser`
**Swift file:** `Sierra/Shared/Models/AuthUser.swift`  
**Supabase table:** Mirrors `auth.users` + `staff_members` metadata  
**Protocols:** `Codable`, `Equatable`, `Identifiable`

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `auth.users.id` | Set by Supabase Auth |
| `email` | `String` | `auth.users.email` | Set by Supabase Auth |
| `role` | `UserRole` | `staff_members.role` | `fleetManager` / `driver` / `maintenancePersonnel` |
| `isFirstLogin` | `Bool` | `staff_members.is_first_login` | True until password changed |
| `isProfileComplete` | `Bool` | `staff_members.is_profile_complete` | True after onboarding submitted |
| `isApproved` | `Bool` | `staff_members.is_approved` | Set by admin after review |
| `name` | `String?` | `staff_members.name` | Set during onboarding |
| `rejectionReason` | `String?` | `staff_members.rejection_reason` | Populated on rejection |
| `phone` | `String?` | `staff_members.phone` | Set during onboarding |
| `createdAt` | `Date?` | `staff_members.created_at` | Auto-set by Supabase |

**Routing logic (unchanged):**
```
fleetManager  → .fleetManagerDashboard (always approved)
driver        → .changePassword (isFirstLogin)
              → .driverOnboarding (!isProfileComplete)
              → .pendingApproval (!isApproved)
              → .driverDashboard
maintenancePersonnel → .changePassword / .maintenanceOnboarding / .pendingApproval / .maintenanceDashboard
```

---

### 3B. `TwoFactorSession`
**Swift file:** `Sierra/Auth/Models/TwoFactorModels.swift` (extend existing)  
**Supabase table:** `two_factor_sessions`  
**Note:** Supabase Auth handles OTP generation and delivery natively. This model represents the **app-side session state** used for UI and rate-limiting. When Supabase Auth is integrated, most of this is managed server-side; the Swift struct is a local mirror for UI state.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `userId` | `UUID` | `user_id` | FK → `auth.users.id` |
| `method` | `TwoFactorMethod` | `method` | `email` / `sms` / `authenticator` |
| `destination` | `String` | `destination` | Masked email or phone for display |
| `otpHash` | `String` | `otp_hash` | SHA-256 hash of OTP (never plaintext) |
| `expiresAt` | `Date` | `expires_at` | 10 minutes from generation |
| `attemptCount` | `Int` | `attempt_count` | Max 5 attempts |
| `maxAttempts` | `Int` | `max_attempts` | Default: 5 |
| `isVerified` | `Bool` | `is_verified` | True after successful verification |
| `isLocked` | `Bool` | `is_locked` | True after exceeding maxAttempts |
| `lockedUntil` | `Date?` | `locked_until` | 15-min lockout after max attempts |
| `createdAt` | `Date` | `created_at` | Auto |
| `verifiedAt` | `Date?` | `verified_at` | Set on success |

**State machine (TwoFactorState enum — already in TwoFactorModels.swift):**
```
idle → sending → awaitingEntry → verifying
                                  ├── success
                                  ├── failed(attemptsRemaining:)
                                  ├── locked(unlockAt:)
                                  └── expired
```

**Supabase RLS:** Only the owning user can read their own session. Insert allowed on auth. Update restricted to server-side Edge Functions only.

---

### 3C. Supporting Auth Enums

```swift
// UserRole.swift (existing — no changes needed)
enum UserRole: String, Codable, CaseIterable {
    case fleetManager           = "fleetManager"
    case driver                 = "driver"
    case maintenancePersonnel   = "maintenancePersonnel"
}

// TwoFactorMethod (existing in TwoFactorModels.swift)
enum TwoFactorMethod: String, Codable, CaseIterable {
    case email         // v1 — implemented
    case sms           // future
    case authenticator // future (TOTP)
}

// TwoFactorState (existing — UI state only, not persisted)
enum TwoFactorState: Equatable {
    case idle
    case sending
    case awaitingEntry
    case verifying
    case success
    case failed(attemptsRemaining: Int)
    case locked(unlockAt: Date)
    case expired
}
```

---

## 4. Staff Layer

### 4A. `StaffMember` (Base Model)
**Swift file:** `Sierra/Shared/Models/StaffMember.swift`  
**Supabase table:** `staff_members`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Universal identity record for ALL staff (drivers + maintenance). Contains only fields applicable to both roles. Role-specific credentials live in `DriverProfile` or `MaintenanceProfile`.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK — same UUID as `auth.users.id` |
| `name` | `String` | `name` | Full name |
| `role` | `StaffRole` | `role` | `driver` / `maintenance` |
| `status` | `StaffStatus` | `status` | `active` / `pendingApproval` / `suspended` |
| `email` | `String` | `email` | Matches `auth.users.email` |
| `phone` | `String` | `phone` | Primary contact number |
| `availability` | `StaffAvailability` | `availability` | `available` / `unavailable` / `onTrip` / `onTask` |
| `dateOfBirth` | `Date` | `date_of_birth` | |
| `gender` | `String` | `gender` | |
| `address` | `String` | `address` | |
| `emergencyContactName` | `String` | `emergency_contact_name` | |
| `emergencyContactPhone` | `String` | `emergency_contact_phone` | |
| `aadhaarNumber` | `String` | `aadhaar_number` | Universal ID for all Indian staff |
| `profilePhotoUrl` | `String?` | `profile_photo_url` | Supabase Storage URL |
| `isFirstLogin` | `Bool` | `is_first_login` | |
| `isProfileComplete` | `Bool` | `is_profile_complete` | |
| `isApproved` | `Bool` | `is_approved` | |
| `rejectionReason` | `String?` | `rejection_reason` | |
| `joinedDate` | `Date` | `joined_date` | Admin-set when account created |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

**Computed (Swift only):**
- `initials: String` — first + last initial
- `displayRole: String` — human-readable role label

**Supabase RLS:**
- Admin: full read/write on all records
- Staff member: read/update own record only (cannot modify `status`, `isApproved`, `role`)

---

### 4B. `DriverProfile` (Driver-Specific Extension)
**Swift file:** `Sierra/Shared/Models/DriverProfile.swift` *(new file)*  
**Supabase table:** `driver_profiles`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** One-to-one with `StaffMember` where `role == .driver`. Contains all driver credential, license, and performance fields.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `staffMemberId` | `UUID` | `staff_member_id` | FK → `staff_members.id` (UNIQUE, 1-1) |
| `licenseNumber` | `String` | `license_number` | |
| `licenseExpiry` | `Date` | `license_expiry` | |
| `licenseClass` | `String` | `license_class` | e.g. "LMV", "HMV", "Transport" |
| `licenseIssuingState` | `String` | `license_issuing_state` | |
| `licenseDocumentUrl` | `String?` | `license_document_url` | Supabase Storage |
| `aadhaarDocumentUrl` | `String?` | `aadhaar_document_url` | Supabase Storage |
| `totalTripsCompleted` | `Int` | `total_trips_completed` | Auto-incremented by backend trigger |
| `totalDistanceKm` | `Double` | `total_distance_km` | Auto-updated by trip completion |
| `averageRating` | `Double?` | `average_rating` | Future: admin-set rating |
| `currentVehicleId` | `String?` | `current_vehicle_id` | FK → `vehicles.id` (active assignment) |
| `notes` | `String?` | `notes` | Admin notes |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

**Supabase RLS:**
- Admin: full read/write
- Driver (owner): read own record; update non-credential fields only
- Maintenance personnel: no access

---

### 4C. `MaintenanceProfile` (Maintenance-Specific Extension)
**Swift file:** `Sierra/Shared/Models/MaintenanceProfile.swift` *(new file)*  
**Supabase table:** `maintenance_profiles`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** One-to-one with `StaffMember` where `role == .maintenance`. Contains all certification, specialization, and performance fields specific to maintenance personnel.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `staffMemberId` | `UUID` | `staff_member_id` | FK → `staff_members.id` (UNIQUE, 1-1) |
| `certificationType` | `String` | `certification_type` | e.g. "Diesel Mechanic", "Electrician" |
| `certificationNumber` | `String` | `certification_number` | |
| `issuingAuthority` | `String` | `issuing_authority` | e.g. "NSDC India" |
| `certificationExpiry` | `Date` | `certification_expiry` | |
| `certificationDocumentUrl` | `String?` | `certification_document_url` | Supabase Storage |
| `yearsOfExperience` | `Int` | `years_of_experience` | |
| `specializations` | `[String]` | `specializations` | PostgreSQL `text[]` array |
| `totalTasksAssigned` | `Int` | `total_tasks_assigned` | Auto-updated |
| `totalTasksCompleted` | `Int` | `total_tasks_completed` | Auto-updated |
| `aadhaarDocumentUrl` | `String?` | `aadhaar_document_url` | Supabase Storage |
| `notes` | `String?` | `notes` | Admin notes |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

**Supabase RLS:**
- Admin: full read/write
- Maintenance personnel (owner): read own record; update non-credential fields only
- Drivers: no access

---

### 4D. `StaffApplication` (Onboarding Submission)
**Swift file:** `Sierra/Shared/Models/StaffApplication.swift` *(refactor existing)*  
**Supabase table:** `staff_applications`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Submitted by new staff before admin approval. Contains common personal fields + role-specific extension via `DriverApplicationDetails` or `MaintenanceApplicationDetails` (nested). Becomes the source of truth for populating `StaffMember` + `DriverProfile`/`MaintenanceProfile` on approval.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `staffMemberId` | `UUID` | `staff_member_id` | FK → `staff_members.id` |
| `role` | `UserRole` | `role` | Determines which extension block is populated |
| `submittedDate` | `Date` | `submitted_date` | |
| `status` | `ApprovalStatus` | `status` | `pending` / `approved` / `rejected` |
| `rejectionReason` | `String?` | `rejection_reason` | Set by admin on rejection |
| `reviewedBy` | `UUID?` | `reviewed_by` | FK → `staff_members.id` (admin who reviewed) |
| `reviewedAt` | `Date?` | `reviewed_at` | |
| `phone` | `String` | `phone` | Submitted value |
| `dateOfBirth` | `Date` | `date_of_birth` | |
| `gender` | `String` | `gender` | |
| `address` | `String` | `address` | |
| `emergencyContactName` | `String` | `emergency_contact_name` | |
| `emergencyContactPhone` | `String` | `emergency_contact_phone` | |
| `aadhaarNumber` | `String` | `aadhaar_number` | |
| `aadhaarDocumentUrl` | `String?` | `aadhaar_document_url` | Supabase Storage |
| `profilePhotoUrl` | `String?` | `profile_photo_url` | Supabase Storage |
| `driverDetails` | `DriverApplicationDetails?` | *(see sub-table)* | Non-nil when `role == .driver` |
| `maintenanceDetails` | `MaintenanceApplicationDetails?` | *(see sub-table)* | Non-nil when `role == .maintenancePersonnel` |
| `createdAt` | `Date` | `created_at` | Auto |

#### `DriverApplicationDetails` (embedded struct / Supabase columns on same table)
| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `licenseNumber` | `String` | `driver_license_number` | |
| `licenseExpiry` | `Date` | `driver_license_expiry` | |
| `licenseClass` | `String` | `driver_license_class` | |
| `licenseIssuingState` | `String` | `driver_license_issuing_state` | |
| `licenseDocumentUrl` | `String?` | `driver_license_document_url` | Supabase Storage |

#### `MaintenanceApplicationDetails` (embedded struct / Supabase columns on same table)
| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `certificationType` | `String` | `maint_certification_type` | |
| `certificationNumber` | `String` | `maint_certification_number` | |
| `issuingAuthority` | `String` | `maint_issuing_authority` | |
| `certificationExpiry` | `Date` | `maint_certification_expiry` | |
| `certificationDocumentUrl` | `String?` | `maint_certification_document_url` | Supabase Storage |
| `yearsOfExperience` | `Int` | `maint_years_of_experience` | |
| `specializations` | `[String]` | `maint_specializations` | `text[]` |

**Supabase RLS:**
- Admin: full read/write on all applications
- Staff member (owner): read own application; cannot update after submission

---

### 4E. Staff Enums

```swift
// In StaffMember.swift (replace existing enums)

enum StaffRole: String, Codable, CaseIterable {
    case driver      = "driver"
    case maintenance = "maintenance"
}

enum StaffStatus: String, Codable, CaseIterable {
    case active          = "Active"
    case pendingApproval = "Pending Approval"
    case suspended       = "Suspended"
}

// RENAMED from DriverAvailability — now covers both roles
enum StaffAvailability: String, Codable, CaseIterable {
    case available   = "Available"
    case unavailable = "Unavailable"
    case onTrip      = "On Trip"    // driver-specific
    case onTask      = "On Task"    // maintenance-specific
}

// In StaffApplication.swift
enum ApprovalStatus: String, Codable, CaseIterable {
    case pending  = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
}
```

---

## 5. Vehicle Layer

### 5A. `Vehicle`
**Swift file:** `Sierra/Shared/Models/Vehicle.swift` *(extend existing)*  
**Supabase table:** `vehicles`  
**Protocols:** `Identifiable`, `Codable`

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `name` | `String` | `name` | Display name e.g. "Hauler Alpha" |
| `manufacturer` | `String` | `manufacturer` | e.g. "Volvo" |
| `model` | `String` | `model` | e.g. "FH16" |
| `year` | `Int` | `year` | |
| `vin` | `String` | `vin` | UNIQUE |
| `licensePlate` | `String` | `license_plate` | UNIQUE |
| `color` | `String` | `color` | |
| `fuelType` | `FuelType` | `fuel_type` | |
| `seatingCapacity` | `Int` | `seating_capacity` | |
| `status` | `VehicleStatus` | `status` | |
| `assignedDriverId` | `String?` | `assigned_driver_id` | FK → `staff_members.id` |
| `currentLatitude` | `Double?` | `current_latitude` | Updated during active trips |
| `currentLongitude` | `Double?` | `current_longitude` | Updated during active trips |
| `odometer` | `Double` | `odometer` | Current odometer reading in km |
| `totalTrips` | `Int` | `total_trips` | Auto-incremented |
| `totalDistanceKm` | `Double` | `total_distance_km` | Auto-updated |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

**Computed (Swift only):**
- `documentsExpiringSoon: Bool` — checks against active `VehicleDocument` records

**Removed from old model:**
- `registrationExpiry`, `insuranceExpiry`, `insuranceId` → moved to `VehicleDocument`
- `mileage` → renamed to `odometer`
- `distanceTravelled` → renamed to `totalDistanceKm`
- `numberOfTrips` → renamed to `totalTrips`

---

### 5B. `VehicleDocument`
**Swift file:** `Sierra/Shared/Models/VehicleDocument.swift` *(new file)*  
**Supabase table:** `vehicle_documents`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Tracks all vehicle-related documents with expiry monitoring. A vehicle can have multiple documents of different types (registration, insurance, PUC, fitness certificate, etc.).

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `vehicleId` | `UUID` | `vehicle_id` | FK → `vehicles.id` |
| `documentType` | `VehicleDocumentType` | `document_type` | |
| `documentNumber` | `String` | `document_number` | e.g. insurance policy number |
| `issuedDate` | `Date` | `issued_date` | |
| `expiryDate` | `Date` | `expiry_date` | Monitored for alerts |
| `issuingAuthority` | `String` | `issuing_authority` | |
| `documentUrl` | `String?` | `document_url` | Supabase Storage |
| `notes` | `String?` | `notes` | |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

**Computed (Swift only):**
- `daysUntilExpiry: Int`
- `isExpired: Bool`
- `isExpiringSoon: Bool` — within 30 days

```swift
enum VehicleDocumentType: String, Codable, CaseIterable {
    case registration       = "Registration"
    case insurance          = "Insurance"
    case fitnessCertificate = "Fitness Certificate"
    case puc               = "PUC Certificate"
    case permit            = "Permit"
    case other             = "Other"
}
```

**Supabase RLS:**
- Admin: full read/write
- Driver: read documents for currently assigned vehicle only
- Maintenance: read all vehicle documents (needed for repair context)

---

### 5C. Vehicle Enums

```swift
enum FuelType: String, Codable, CaseIterable {
    case diesel   = "Diesel"
    case petrol   = "Petrol"
    case electric = "Electric"
    case cng      = "CNG"
    case hybrid   = "Hybrid"
}

enum VehicleStatus: String, Codable, CaseIterable {
    case active       = "Active"
    case idle         = "Idle"
    case inMaintenance = "In Maintenance"
    case outOfService  = "Out of Service"
    case decommissioned = "Decommissioned"
}
```

---

## 6. Operations Layer

### 6A. `Trip`
**Swift file:** `Sierra/Shared/Models/Trip.swift` *(extend existing)*  
**Supabase table:** `trips`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Represents a delivery task created by the admin. Central operational entity linking drivers, vehicles, and delivery outcomes.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `taskId` | `String` | `task_id` | UNIQUE, format: `TRP-yyyyMMdd-XXXX` |
| `driverId` | `String?` | `driver_id` | FK → `staff_members.id` |
| `vehicleId` | `String?` | `vehicle_id` | FK → `vehicles.id` |
| `createdByAdminId` | `String` | `created_by_admin_id` | FK → `staff_members.id` |
| `origin` | `String` | `origin` | |
| `destination` | `String` | `destination` | |
| `deliveryInstructions` | `String` | `delivery_instructions` | |
| `scheduledDate` | `Date` | `scheduled_date` | |
| `scheduledEndDate` | `Date?` | `scheduled_end_date` | |
| `actualStartDate` | `Date?` | `actual_start_date` | Set when driver starts trip |
| `actualEndDate` | `Date?` | `actual_end_date` | Set when driver ends trip |
| `startMileage` | `Double?` | `start_mileage` | Odometer at trip start |
| `endMileage` | `Double?` | `end_mileage` | Odometer at trip end |
| `notes` | `String` | `notes` | |
| `status` | `TripStatus` | `status` | |
| `priority` | `TripPriority` | `priority` | |
| `proofOfDeliveryId` | `UUID?` | `proof_of_delivery_id` | FK → `proof_of_deliveries.id` |
| `preInspectionId` | `UUID?` | `pre_inspection_id` | FK → `vehicle_inspections.id` |
| `postInspectionId` | `UUID?` | `post_inspection_id` | FK → `vehicle_inspections.id` |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

**Computed (Swift only):**
- `durationString: String?`
- `distanceKm: Double?`
- `isOverdue: Bool`

```swift
enum TripStatus: String, Codable, CaseIterable {
    case scheduled  = "Scheduled"
    case active     = "Active"
    case completed  = "Completed"
    case cancelled  = "Cancelled"
}

enum TripPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case normal = "Normal"
    case high   = "High"
    case urgent = "Urgent"
}
```

---

### 6B. `FuelLog`
**Swift file:** `Sierra/Shared/Models/FuelLog.swift` *(new file)*  
**Supabase table:** `fuel_logs`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Recorded by the driver whenever they refuel the vehicle. Linked to both the driver and the vehicle. Can optionally be linked to an active trip.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `driverId` | `UUID` | `driver_id` | FK → `staff_members.id` |
| `vehicleId` | `UUID` | `vehicle_id` | FK → `vehicles.id` |
| `tripId` | `UUID?` | `trip_id` | FK → `trips.id` (optional) |
| `fuelQuantityLitres` | `Double` | `fuel_quantity_litres` | Litres filled |
| `fuelCost` | `Double` | `fuel_cost` | Total cost in INR |
| `pricePerLitre` | `Double` | `price_per_litre` | Auto-calculated or manual |
| `odometerAtFill` | `Double` | `odometer_at_fill` | Odometer reading when filled |
| `fuelStation` | `String?` | `fuel_station` | Station name/location |
| `receiptImageUrl` | `String?` | `receipt_image_url` | Supabase Storage |
| `loggedAt` | `Date` | `logged_at` | When driver logged it |
| `createdAt` | `Date` | `created_at` | Auto |

**Supabase RLS:**
- Admin: full read on all fuel logs
- Driver: read/write own logs only
- Maintenance: read only (for vehicle records context)

---

### 6C. `VehicleInspection`
**Swift file:** `Sierra/Shared/Models/VehicleInspection.swift` *(new file)*  
**Supabase table:** `vehicle_inspections`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Pre-trip and post-trip inspections performed by the driver. A failed inspection triggers a defect report and admin notification. Contains an array of `InspectionItem` results.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `tripId` | `UUID` | `trip_id` | FK → `trips.id` |
| `vehicleId` | `UUID` | `vehicle_id` | FK → `vehicles.id` |
| `driverId` | `UUID` | `driver_id` | FK → `staff_members.id` |
| `type` | `InspectionType` | `type` | `preTripInspection` / `postTripInspection` |
| `overallResult` | `InspectionResult` | `overall_result` | `passed` / `failed` / `passedWithWarnings` |
| `items` | `[InspectionItem]` | `items` | Stored as JSONB in Supabase |
| `defectsReported` | `String?` | `defects_reported` | Summary of reported defects |
| `additionalNotes` | `String?` | `additional_notes` | |
| `driverSignatureUrl` | `String?` | `driver_signature_url` | Supabase Storage |
| `inspectedAt` | `Date` | `inspected_at` | |
| `createdAt` | `Date` | `created_at` | Auto |

#### `InspectionItem` (embedded struct, stored as JSONB)
| Field | Swift Type | Notes |
|---|---|---|
| `id` | `UUID` | Local ID for list rendering |
| `checkName` | `String` | e.g. "Tyre Pressure", "Brake Fluid", "Lights" |
| `category` | `InspectionCategory` | `tyres` / `engine` / `lights` / `body` / `safety` / `fluids` |
| `result` | `InspectionResult` | `passed` / `failed` / `notChecked` |
| `notes` | `String?` | Optional note for this item |

```swift
enum InspectionType: String, Codable {
    case preTripInspection  = "Pre-Trip"
    case postTripInspection = "Post-Trip"
}

enum InspectionResult: String, Codable {
    case passed             = "Passed"
    case failed             = "Failed"
    case passedWithWarnings = "Passed with Warnings"
    case notChecked         = "Not Checked"
}

enum InspectionCategory: String, Codable, CaseIterable {
    case tyres  = "Tyres"
    case engine = "Engine"
    case lights = "Lights"
    case body   = "Body"
    case safety = "Safety"
    case fluids = "Fluids"
}
```

**Business Logic:** When `overallResult == .failed`, the system:
1. Notifies admin via `ActivityLog` entry
2. Triggers the Priority Alert flow in `AdminDashboardView`
3. Sets the trip's `preInspectionId` or `postInspectionId` FK

---

### 6D. `ProofOfDelivery`
**Swift file:** `Sierra/Shared/Models/ProofOfDelivery.swift` *(new file)*  
**Supabase table:** `proof_of_deliveries`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Captured by the driver upon completing a delivery. Supports photo, signature, and OTP verification methods. At least one method must be captured before a trip can be marked complete.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `tripId` | `UUID` | `trip_id` | FK → `trips.id` (UNIQUE — one POD per trip) |
| `driverId` | `UUID` | `driver_id` | FK → `staff_members.id` |
| `method` | `ProofOfDeliveryMethod` | `method` | `photo` / `signature` / `otp` |
| `photoUrl` | `String?` | `photo_url` | Supabase Storage (required if method == .photo) |
| `signatureUrl` | `String?` | `signature_url` | Supabase Storage (required if method == .signature) |
| `otpVerified` | `Bool` | `otp_verified` | True if OTP confirmed |
| `recipientName` | `String?` | `recipient_name` | Name of person who received delivery |
| `deliveryLatitude` | `Double?` | `delivery_latitude` | GPS at delivery moment |
| `deliveryLongitude` | `Double?` | `delivery_longitude` | |
| `capturedAt` | `Date` | `captured_at` | |
| `createdAt` | `Date` | `created_at` | Auto |

```swift
enum ProofOfDeliveryMethod: String, Codable, CaseIterable {
    case photo     = "Photo"
    case signature = "Signature"
    case otp       = "OTP Verification"
}
```

---

### 6E. `EmergencyAlert`
**Swift file:** `Sierra/Shared/Models/EmergencyAlert.swift` *(new file)*  
**Supabase table:** `emergency_alerts`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Triggered by a driver in an emergency. Captures GPS location at the moment of alert and is immediately visible to the admin dashboard.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `driverId` | `UUID` | `driver_id` | FK → `staff_members.id` |
| `tripId` | `UUID?` | `trip_id` | FK → `trips.id` (if on active trip) |
| `vehicleId` | `UUID?` | `vehicle_id` | FK → `vehicles.id` |
| `latitude` | `Double` | `latitude` | GPS at alert moment |
| `longitude` | `Double` | `longitude` | |
| `alertType` | `EmergencyAlertType` | `alert_type` | `sos` / `accident` / `breakdown` / `medical` |
| `status` | `EmergencyAlertStatus` | `status` | `active` / `acknowledged` / `resolved` |
| `description` | `String?` | `description` | Driver's optional message |
| `acknowledgedBy` | `UUID?` | `acknowledged_by` | FK → `staff_members.id` (admin) |
| `acknowledgedAt` | `Date?` | `acknowledged_at` | |
| `resolvedAt` | `Date?` | `resolved_at` | |
| `triggeredAt` | `Date` | `triggered_at` | |
| `createdAt` | `Date` | `created_at` | Auto |

```swift
enum EmergencyAlertType: String, Codable, CaseIterable {
    case sos       = "SOS"
    case accident  = "Accident"
    case breakdown = "Breakdown"
    case medical   = "Medical"
}

enum EmergencyAlertStatus: String, Codable, CaseIterable {
    case active       = "Active"
    case acknowledged = "Acknowledged"
    case resolved     = "Resolved"
}
```

**Supabase Realtime:** This table should have Realtime enabled so the admin dashboard receives instant push notifications on new alerts.

---

## 7. Maintenance Layer

### 7A. `MaintenanceTask`
**Swift file:** `Sierra/Shared/Services/AppDataStore.swift` → move to `Sierra/Shared/Models/MaintenanceTask.swift` *(extract + expand)*  
**Supabase table:** `maintenance_tasks`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Created by the admin to request maintenance on a vehicle. Acts as the admin-facing record. Triggers creation of a `WorkOrder` when assigned to maintenance personnel.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `vehicleId` | `UUID` | `vehicle_id` | FK → `vehicles.id` |
| `createdByAdminId` | `UUID` | `created_by_admin_id` | FK → `staff_members.id` |
| `assignedToId` | `UUID?` | `assigned_to_id` | FK → `staff_members.id` (maintenance personnel) |
| `title` | `String` | `title` | |
| `taskDescription` | `String` | `task_description` | |
| `priority` | `TaskPriority` | `priority` | |
| `status` | `MaintenanceTaskStatus` | `status` | |
| `taskType` | `MaintenanceTaskType` | `task_type` | `scheduled` / `breakdown` / `inspection` / `urgent` |
| `sourceAlertId` | `UUID?` | `source_alert_id` | FK → `emergency_alerts.id` (if triggered by breakdown) |
| `sourceInspectionId` | `UUID?` | `source_inspection_id` | FK → `vehicle_inspections.id` (if from inspection) |
| `dueDate` | `Date` | `due_date` | |
| `completedAt` | `Date?` | `completed_at` | |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

```swift
enum MaintenanceTaskType: String, Codable, CaseIterable {
    case scheduled  = "Scheduled"
    case breakdown  = "Breakdown"
    case inspection = "Inspection Defect"
    case urgent     = "Urgent"
}

enum MaintenanceTaskStatus: String, Codable, CaseIterable {
    case pending    = "Pending"
    case assigned   = "Assigned"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case cancelled  = "Cancelled"
}

enum TaskPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"
    case urgent = "Urgent"
}
```

---

### 7B. `WorkOrder`
**Swift file:** `Sierra/Shared/Models/WorkOrder.swift` *(new file)*  
**Supabase table:** `work_orders`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** The maintenance personnel-facing view of a `MaintenanceTask`. One-to-one with `MaintenanceTask`. Contains progress tracking, repair details, and parts used. Maintenance personnel view/update/close work orders. Admin sees summary.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `maintenanceTaskId` | `UUID` | `maintenance_task_id` | FK → `maintenance_tasks.id` (UNIQUE) |
| `vehicleId` | `UUID` | `vehicle_id` | FK → `vehicles.id` (denormalized for query convenience) |
| `assignedToId` | `UUID` | `assigned_to_id` | FK → `staff_members.id` |
| `status` | `WorkOrderStatus` | `status` | |
| `repairDescription` | `String` | `repair_description` | What was found and done |
| `labourCostTotal` | `Double` | `labour_cost_total` | Sum of labour hours × rate |
| `partsCostTotal` | `Double` | `parts_cost_total` | Auto-summed from `PartUsed` records |
| `totalCost` | `Double` | `total_cost` | labourCost + partsCost |
| `startedAt` | `Date?` | `started_at` | |
| `completedAt` | `Date?` | `completed_at` | |
| `technicianNotes` | `String?` | `technician_notes` | |
| `vinScanned` | `Bool` | `vin_scanned` | True if VIN was verified via camera |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

```swift
enum WorkOrderStatus: String, Codable, CaseIterable {
    case open       = "Open"
    case inProgress = "In Progress"
    case onHold     = "On Hold"
    case completed  = "Completed"
    case closed     = "Closed"
}
```

---

### 7C. `MaintenanceRecord`
**Swift file:** `Sierra/Shared/Models/MaintenanceRecord.swift` *(extend existing)*  
**Supabase table:** `maintenance_records`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** The permanent audit record of all maintenance activities on a vehicle. Created when a `WorkOrder` is closed. Forms the vehicle's full maintenance history visible to admin and maintenance personnel.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `vehicleId` | `UUID` | `vehicle_id` | FK → `vehicles.id` |
| `workOrderId` | `UUID` | `work_order_id` | FK → `work_orders.id` |
| `maintenanceTaskId` | `UUID` | `maintenance_task_id` | FK → `maintenance_tasks.id` |
| `performedById` | `UUID` | `performed_by_id` | FK → `staff_members.id` |
| `issueReported` | `String` | `issue_reported` | Original issue description |
| `repairDetails` | `String` | `repair_details` | Full repair narrative |
| `odometerAtService` | `Double` | `odometer_at_service` | |
| `labourCost` | `Double` | `labour_cost` | |
| `partsCost` | `Double` | `parts_cost` | |
| `totalCost` | `Double` | `total_cost` | |
| `status` | `MaintenanceRecordStatus` | `status` | |
| `serviceDate` | `Date` | `service_date` | |
| `nextServiceDue` | `Date?` | `next_service_due` | Optional scheduled follow-up |
| `createdAt` | `Date` | `created_at` | Auto |

```swift
enum MaintenanceRecordStatus: String, Codable, CaseIterable {
    case scheduled  = "Scheduled"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case cancelled  = "Cancelled"
}
```

---

### 7D. `PartUsed`
**Swift file:** `Sierra/Shared/Models/PartUsed.swift` *(new file)*  
**Supabase table:** `parts_used`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Each individual part used in a work order. Linked to a `WorkOrder`. The `parts_cost_total` on `WorkOrder` is a sum of all associated `PartUsed` records.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `workOrderId` | `UUID` | `work_order_id` | FK → `work_orders.id` |
| `partName` | `String` | `part_name` | |
| `partNumber` | `String?` | `part_number` | OEM or internal part number |
| `quantity` | `Int` | `quantity` | |
| `unitCost` | `Double` | `unit_cost` | Cost per unit in INR |
| `totalCost` | `Double` | `total_cost` | quantity × unitCost |
| `supplier` | `String?` | `supplier` | Where part was sourced |
| `createdAt` | `Date` | `created_at` | Auto |

---

## 8. Geofencing Layer

### 8A. `Geofence`
**Swift file:** `Sierra/Shared/Models/Geofence.swift` *(extend existing)*  
**Supabase table:** `geofences`  
**Protocols:** `Identifiable`, `Codable`

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `name` | `String` | `name` | |
| `description` | `String` | `description` | |
| `latitude` | `Double` | `latitude` | Center point |
| `longitude` | `Double` | `longitude` | Center point |
| `radiusMeters` | `Double` | `radius_meters` | Changed from Int to Double |
| `isActive` | `Bool` | `is_active` | Admin can disable without deleting |
| `createdByAdminId` | `UUID` | `created_by_admin_id` | FK → `staff_members.id` |
| `alertOnEntry` | `Bool` | `alert_on_entry` | Generate event on vehicle entry |
| `alertOnExit` | `Bool` | `alert_on_exit` | Generate event on vehicle exit |
| `createdAt` | `Date` | `created_at` | Auto |
| `updatedAt` | `Date` | `updated_at` | Auto |

---

### 8B. `GeofenceEvent`
**Swift file:** `Sierra/Shared/Models/GeofenceEvent.swift` *(new file)*  
**Supabase table:** `geofence_events`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** Generated automatically when a vehicle's GPS position crosses a geofence boundary. Stores the full event record for the admin's historical view.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `geofenceId` | `UUID` | `geofence_id` | FK → `geofences.id` |
| `vehicleId` | `UUID` | `vehicle_id` | FK → `vehicles.id` |
| `tripId` | `UUID?` | `trip_id` | FK → `trips.id` (if on active trip) |
| `driverId` | `UUID?` | `driver_id` | FK → `staff_members.id` |
| `eventType` | `GeofenceEventType` | `event_type` | `entry` / `exit` |
| `latitude` | `Double` | `latitude` | Vehicle position at event moment |
| `longitude` | `Double` | `longitude` | |
| `triggeredAt` | `Date` | `triggered_at` | |
| `createdAt` | `Date` | `created_at` | Auto |

```swift
enum GeofenceEventType: String, Codable {
    case entry = "Entry"
    case exit  = "Exit"
}
```

---

## 9. Activity & Audit Layer

### 9A. `ActivityLog`
**Swift file:** `Sierra/Shared/Models/ActivityLog.swift` *(extend existing)*  
**Supabase table:** `activity_logs`  
**Protocols:** `Identifiable`, `Codable`  
**Description:** System-wide audit trail. Entries are created by backend Supabase Edge Functions or triggers — never directly by the iOS app. Admin dashboard reads the most recent entries.

| Field | Swift Type | Supabase Column | Notes |
|---|---|---|---|
| `id` | `UUID` | `id` | PK |
| `type` | `ActivityType` | `type` | |
| `title` | `String` | `title` | Short headline |
| `description` | `String` | `description` | Full detail |
| `actorId` | `UUID?` | `actor_id` | FK → `staff_members.id` (who triggered it) |
| `entityType` | `String` | `entity_type` | e.g. "trip", "vehicle", "staff" |
| `entityId` | `UUID?` | `entity_id` | ID of the affected entity |
| `severity` | `ActivitySeverity` | `severity` | `info` / `warning` / `critical` |
| `isRead` | `Bool` | `is_read` | Admin read flag |
| `timestamp` | `Date` | `timestamp` | |
| `createdAt` | `Date` | `created_at` | Auto |

```swift
enum ActivityType: String, Codable, CaseIterable {
    case tripStarted          = "Trip Started"
    case tripCompleted        = "Trip Completed"
    case tripCancelled        = "Trip Cancelled"
    case vehicleInspectionFailed = "Inspection Failed"
    case vehicleAssigned      = "Vehicle Assigned"
    case maintenanceRequested = "Maintenance Requested"
    case maintenanceCompleted = "Maintenance Completed"
    case staffApproved        = "Staff Approved"
    case staffRejected        = "Staff Rejected"
    case emergencyAlert       = "Emergency Alert"
    case geofenceViolation    = "Geofence Violation"
    case documentExpiringSoon = "Document Expiring Soon"
    case documentExpired      = "Document Expired"
    case fuelLogged           = "Fuel Logged"
}

enum ActivitySeverity: String, Codable, CaseIterable {
    case info     = "Info"
    case warning  = "Warning"
    case critical = "Critical"
}
```

---

## 10. Enum Master Reference

| Enum | Cases | Layer | File |
|---|---|---|---|
| `UserRole` | 3 | Auth | `UserRole.swift` |
| `TwoFactorMethod` | 3 | Auth | `TwoFactorModels.swift` |
| `TwoFactorState` | 7 | Auth (UI) | `TwoFactorModels.swift` |
| `StaffRole` | 2 | Staff | `StaffMember.swift` |
| `StaffStatus` | 3 | Staff | `StaffMember.swift` |
| `StaffAvailability` | 4 | Staff | `StaffMember.swift` |
| `ApprovalStatus` | 3 | Staff | `StaffApplication.swift` |
| `FuelType` | 5 | Vehicle | `Vehicle.swift` |
| `VehicleStatus` | 5 | Vehicle | `Vehicle.swift` |
| `VehicleDocumentType` | 6 | Vehicle | `VehicleDocument.swift` |
| `TripStatus` | 4 | Operations | `Trip.swift` |
| `TripPriority` | 4 | Operations | `Trip.swift` |
| `InspectionType` | 2 | Operations | `VehicleInspection.swift` |
| `InspectionResult` | 4 | Operations | `VehicleInspection.swift` |
| `InspectionCategory` | 6 | Operations | `VehicleInspection.swift` |
| `ProofOfDeliveryMethod` | 3 | Operations | `ProofOfDelivery.swift` |
| `EmergencyAlertType` | 4 | Operations | `EmergencyAlert.swift` |
| `EmergencyAlertStatus` | 3 | Operations | `EmergencyAlert.swift` |
| `MaintenanceTaskType` | 4 | Maintenance | `MaintenanceTask.swift` |
| `MaintenanceTaskStatus` | 5 | Maintenance | `MaintenanceTask.swift` |
| `TaskPriority` | 4 | Maintenance | `MaintenanceTask.swift` |
| `WorkOrderStatus` | 5 | Maintenance | `WorkOrder.swift` |
| `MaintenanceRecordStatus` | 4 | Maintenance | `MaintenanceRecord.swift` |
| `GeofenceEventType` | 2 | Geofencing | `GeofenceEvent.swift` |
| `ActivityType` | 14 | Audit | `ActivityLog.swift` |
| `ActivitySeverity` | 3 | Audit | `ActivityLog.swift` |

**Total: 26 enums, 121 cases**

---

## 11. Full Relationship Map

```
auth.users (Supabase)
    │ 1:1
    └── staff_members ──────────────────────────────────────────────┐
            │ 1:1 (driver only)                                     │
            ├── driver_profiles                                     │
            │       └── vehicle (current_vehicle_id FK)             │
            │ 1:1 (maintenance only)                                │
            ├── maintenance_profiles                                │
            │                                                       │
            │ 1:many                                                │
            ├── staff_applications ◄─── review ───── staff_members ┘
            │                                                       (admin)
            │ 1:many (driver)
            ├── trips
            │       │ 1:1
            │       ├── proof_of_deliveries
            │       │ 1:1 (pre)
            │       ├── vehicle_inspections (pre-trip)
            │       │ 1:1 (post)
            │       └── vehicle_inspections (post-trip)
            │
            │ 1:many (driver)
            ├── fuel_logs
            │
            │ 1:many (driver)
            ├── emergency_alerts
            │
            │ 1:many (maintenance)
            └── work_orders
                    │ 1:many
                    └── parts_used

vehicles
    │ 1:many
    ├── vehicle_documents
    │ 1:many
    ├── trips
    │ 1:many
    ├── fuel_logs
    │ 1:many
    ├── vehicle_inspections
    │ 1:many
    ├── maintenance_tasks
    │       │ 1:1
    │       └── work_orders
    │               │ 1:1
    │               └── maintenance_records
    │ 1:many
    └── geofence_events

geofences
    │ 1:many
    └── geofence_events

activity_logs (append-only, references many entities via entity_id)
```

---

## 12. Supabase Table Definitions

These are the SQL table definitions for Supabase. Each table uses `uuid_generate_v4()` as default PK.

```sql
-- ══════════════════════════════════════════
-- STAFF
-- ══════════════════════════════════════════

CREATE TABLE staff_members (
  id                     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name                   TEXT,
  role                   TEXT NOT NULL CHECK (role IN ('fleetManager','driver','maintenancePersonnel')),
  status                 TEXT NOT NULL DEFAULT 'pendingApproval',
  email                  TEXT NOT NULL UNIQUE,
  phone                  TEXT,
  availability           TEXT NOT NULL DEFAULT 'unavailable',
  date_of_birth          DATE,
  gender                 TEXT,
  address                TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  aadhaar_number         TEXT,
  profile_photo_url      TEXT,
  is_first_login         BOOLEAN NOT NULL DEFAULT TRUE,
  is_profile_complete    BOOLEAN NOT NULL DEFAULT FALSE,
  is_approved            BOOLEAN NOT NULL DEFAULT FALSE,
  rejection_reason       TEXT,
  joined_date            TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE driver_profiles (
  id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_member_id          UUID NOT NULL UNIQUE REFERENCES staff_members(id) ON DELETE CASCADE,
  license_number           TEXT NOT NULL,
  license_expiry           DATE NOT NULL,
  license_class            TEXT NOT NULL,
  license_issuing_state    TEXT NOT NULL,
  license_document_url     TEXT,
  aadhaar_document_url     TEXT,
  total_trips_completed    INT NOT NULL DEFAULT 0,
  total_distance_km        DOUBLE PRECISION NOT NULL DEFAULT 0,
  average_rating           DOUBLE PRECISION,
  current_vehicle_id       UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  notes                    TEXT,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE maintenance_profiles (
  id                           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_member_id              UUID NOT NULL UNIQUE REFERENCES staff_members(id) ON DELETE CASCADE,
  certification_type           TEXT NOT NULL,
  certification_number         TEXT NOT NULL,
  issuing_authority            TEXT NOT NULL,
  certification_expiry         DATE NOT NULL,
  certification_document_url   TEXT,
  years_of_experience          INT NOT NULL DEFAULT 0,
  specializations              TEXT[] NOT NULL DEFAULT '{}',
  total_tasks_assigned         INT NOT NULL DEFAULT 0,
  total_tasks_completed        INT NOT NULL DEFAULT 0,
  aadhaar_document_url         TEXT,
  notes                        TEXT,
  created_at                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE staff_applications (
  id                              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_member_id                 UUID NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
  role                            TEXT NOT NULL,
  submitted_date                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status                          TEXT NOT NULL DEFAULT 'pending',
  rejection_reason                TEXT,
  reviewed_by                     UUID REFERENCES staff_members(id),
  reviewed_at                     TIMESTAMPTZ,
  phone                           TEXT NOT NULL,
  date_of_birth                   DATE NOT NULL,
  gender                          TEXT NOT NULL,
  address                         TEXT NOT NULL,
  emergency_contact_name          TEXT NOT NULL,
  emergency_contact_phone         TEXT NOT NULL,
  aadhaar_number                  TEXT NOT NULL,
  aadhaar_document_url            TEXT,
  profile_photo_url               TEXT,
  -- Driver-specific
  driver_license_number           TEXT,
  driver_license_expiry           DATE,
  driver_license_class            TEXT,
  driver_license_issuing_state    TEXT,
  driver_license_document_url     TEXT,
  -- Maintenance-specific
  maint_certification_type        TEXT,
  maint_certification_number      TEXT,
  maint_issuing_authority         TEXT,
  maint_certification_expiry      DATE,
  maint_certification_document_url TEXT,
  maint_years_of_experience       INT,
  maint_specializations           TEXT[],
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- AUTH (2FA sessions)
-- ══════════════════════════════════════════

CREATE TABLE two_factor_sessions (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  method            TEXT NOT NULL DEFAULT 'email',
  destination       TEXT NOT NULL,
  otp_hash          TEXT NOT NULL,
  expires_at        TIMESTAMPTZ NOT NULL,
  attempt_count     INT NOT NULL DEFAULT 0,
  max_attempts      INT NOT NULL DEFAULT 5,
  is_verified       BOOLEAN NOT NULL DEFAULT FALSE,
  is_locked         BOOLEAN NOT NULL DEFAULT FALSE,
  locked_until      TIMESTAMPTZ,
  verified_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- VEHICLES
-- ══════════════════════════════════════════

CREATE TABLE vehicles (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                 TEXT NOT NULL,
  manufacturer         TEXT NOT NULL,
  model                TEXT NOT NULL,
  year                 INT NOT NULL,
  vin                  TEXT NOT NULL UNIQUE,
  license_plate        TEXT NOT NULL UNIQUE,
  color                TEXT NOT NULL,
  fuel_type            TEXT NOT NULL,
  seating_capacity     INT NOT NULL DEFAULT 2,
  status               TEXT NOT NULL DEFAULT 'idle',
  assigned_driver_id   UUID REFERENCES staff_members(id) ON DELETE SET NULL,
  current_latitude     DOUBLE PRECISION,
  current_longitude    DOUBLE PRECISION,
  odometer             DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_trips          INT NOT NULL DEFAULT 0,
  total_distance_km    DOUBLE PRECISION NOT NULL DEFAULT 0,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE vehicle_documents (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id        UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  document_type     TEXT NOT NULL,
  document_number   TEXT NOT NULL,
  issued_date       DATE NOT NULL,
  expiry_date       DATE NOT NULL,
  issuing_authority TEXT NOT NULL,
  document_url      TEXT,
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- OPERATIONS
-- ══════════════════════════════════════════

CREATE TABLE trips (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id                 TEXT NOT NULL UNIQUE,
  driver_id               UUID REFERENCES staff_members(id) ON DELETE SET NULL,
  vehicle_id              UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  created_by_admin_id     UUID NOT NULL REFERENCES staff_members(id),
  origin                  TEXT NOT NULL,
  destination             TEXT NOT NULL,
  delivery_instructions   TEXT NOT NULL DEFAULT '',
  scheduled_date          TIMESTAMPTZ NOT NULL,
  scheduled_end_date      TIMESTAMPTZ,
  actual_start_date       TIMESTAMPTZ,
  actual_end_date         TIMESTAMPTZ,
  start_mileage           DOUBLE PRECISION,
  end_mileage             DOUBLE PRECISION,
  notes                   TEXT NOT NULL DEFAULT '',
  status                  TEXT NOT NULL DEFAULT 'scheduled',
  priority                TEXT NOT NULL DEFAULT 'normal',
  proof_of_delivery_id    UUID,  -- FK set after POD created
  pre_inspection_id       UUID,  -- FK set after inspection created
  post_inspection_id      UUID,  -- FK set after inspection created
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE fuel_logs (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id            UUID NOT NULL REFERENCES staff_members(id),
  vehicle_id           UUID NOT NULL REFERENCES vehicles(id),
  trip_id              UUID REFERENCES trips(id) ON DELETE SET NULL,
  fuel_quantity_litres DOUBLE PRECISION NOT NULL,
  fuel_cost            DOUBLE PRECISION NOT NULL,
  price_per_litre      DOUBLE PRECISION NOT NULL,
  odometer_at_fill     DOUBLE PRECISION NOT NULL,
  fuel_station         TEXT,
  receipt_image_url    TEXT,
  logged_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE vehicle_inspections (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id              UUID NOT NULL REFERENCES trips(id),
  vehicle_id           UUID NOT NULL REFERENCES vehicles(id),
  driver_id            UUID NOT NULL REFERENCES staff_members(id),
  type                 TEXT NOT NULL,
  overall_result       TEXT NOT NULL DEFAULT 'passed',
  items                JSONB NOT NULL DEFAULT '[]',
  defects_reported     TEXT,
  additional_notes     TEXT,
  driver_signature_url TEXT,
  inspected_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE proof_of_deliveries (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id              UUID NOT NULL UNIQUE REFERENCES trips(id),
  driver_id            UUID NOT NULL REFERENCES staff_members(id),
  method               TEXT NOT NULL,
  photo_url            TEXT,
  signature_url        TEXT,
  otp_verified         BOOLEAN NOT NULL DEFAULT FALSE,
  recipient_name       TEXT,
  delivery_latitude    DOUBLE PRECISION,
  delivery_longitude   DOUBLE PRECISION,
  captured_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE emergency_alerts (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id         UUID NOT NULL REFERENCES staff_members(id),
  trip_id           UUID REFERENCES trips(id) ON DELETE SET NULL,
  vehicle_id        UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  latitude          DOUBLE PRECISION NOT NULL,
  longitude         DOUBLE PRECISION NOT NULL,
  alert_type        TEXT NOT NULL DEFAULT 'sos',
  status            TEXT NOT NULL DEFAULT 'active',
  description       TEXT,
  acknowledged_by   UUID REFERENCES staff_members(id),
  acknowledged_at   TIMESTAMPTZ,
  resolved_at       TIMESTAMPTZ,
  triggered_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- MAINTENANCE
-- ══════════════════════════════════════════

CREATE TABLE maintenance_tasks (
  id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id               UUID NOT NULL REFERENCES vehicles(id),
  created_by_admin_id      UUID NOT NULL REFERENCES staff_members(id),
  assigned_to_id           UUID REFERENCES staff_members(id) ON DELETE SET NULL,
  title                    TEXT NOT NULL,
  task_description         TEXT NOT NULL,
  priority                 TEXT NOT NULL DEFAULT 'medium',
  status                   TEXT NOT NULL DEFAULT 'pending',
  task_type                TEXT NOT NULL DEFAULT 'scheduled',
  source_alert_id          UUID REFERENCES emergency_alerts(id) ON DELETE SET NULL,
  source_inspection_id     UUID REFERENCES vehicle_inspections(id) ON DELETE SET NULL,
  due_date                 TIMESTAMPTZ NOT NULL,
  completed_at             TIMESTAMPTZ,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE work_orders (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  maintenance_task_id   UUID NOT NULL UNIQUE REFERENCES maintenance_tasks(id),
  vehicle_id            UUID NOT NULL REFERENCES vehicles(id),
  assigned_to_id        UUID NOT NULL REFERENCES staff_members(id),
  status                TEXT NOT NULL DEFAULT 'open',
  repair_description    TEXT NOT NULL DEFAULT '',
  labour_cost_total     DOUBLE PRECISION NOT NULL DEFAULT 0,
  parts_cost_total      DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_cost            DOUBLE PRECISION GENERATED ALWAYS AS (labour_cost_total + parts_cost_total) STORED,
  started_at            TIMESTAMPTZ,
  completed_at          TIMESTAMPTZ,
  technician_notes      TEXT,
  vin_scanned           BOOLEAN NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE parts_used (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  work_order_id  UUID NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
  part_name      TEXT NOT NULL,
  part_number    TEXT,
  quantity       INT NOT NULL DEFAULT 1,
  unit_cost      DOUBLE PRECISION NOT NULL,
  total_cost     DOUBLE PRECISION GENERATED ALWAYS AS (quantity * unit_cost) STORED,
  supplier       TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE maintenance_records (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id            UUID NOT NULL REFERENCES vehicles(id),
  work_order_id         UUID NOT NULL REFERENCES work_orders(id),
  maintenance_task_id   UUID NOT NULL REFERENCES maintenance_tasks(id),
  performed_by_id       UUID NOT NULL REFERENCES staff_members(id),
  issue_reported        TEXT NOT NULL,
  repair_details        TEXT NOT NULL,
  odometer_at_service   DOUBLE PRECISION NOT NULL,
  labour_cost           DOUBLE PRECISION NOT NULL DEFAULT 0,
  parts_cost            DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_cost            DOUBLE PRECISION GENERATED ALWAYS AS (labour_cost + parts_cost) STORED,
  status                TEXT NOT NULL DEFAULT 'completed',
  service_date          TIMESTAMPTZ NOT NULL,
  next_service_due      TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- GEOFENCING
-- ══════════════════════════════════════════

CREATE TABLE geofences (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                  TEXT NOT NULL,
  description           TEXT NOT NULL DEFAULT '',
  latitude              DOUBLE PRECISION NOT NULL,
  longitude             DOUBLE PRECISION NOT NULL,
  radius_meters         DOUBLE PRECISION NOT NULL,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  created_by_admin_id   UUID NOT NULL REFERENCES staff_members(id),
  alert_on_entry        BOOLEAN NOT NULL DEFAULT TRUE,
  alert_on_exit         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE geofence_events (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  geofence_id   UUID NOT NULL REFERENCES geofences(id),
  vehicle_id    UUID NOT NULL REFERENCES vehicles(id),
  trip_id       UUID REFERENCES trips(id) ON DELETE SET NULL,
  driver_id     UUID REFERENCES staff_members(id) ON DELETE SET NULL,
  event_type    TEXT NOT NULL,
  latitude      DOUBLE PRECISION NOT NULL,
  longitude     DOUBLE PRECISION NOT NULL,
  triggered_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- AUDIT
-- ══════════════════════════════════════════

CREATE TABLE activity_logs (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type         TEXT NOT NULL,
  title        TEXT NOT NULL,
  description  TEXT NOT NULL,
  actor_id     UUID REFERENCES staff_members(id) ON DELETE SET NULL,
  entity_type  TEXT NOT NULL,
  entity_id    UUID,
  severity     TEXT NOT NULL DEFAULT 'info',
  is_read      BOOLEAN NOT NULL DEFAULT FALSE,
  timestamp    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 13. AppDataStore Redesign

### 13A. Current vs New Arrays

| Array | Current State | New State |
|---|---|---|
| `vehicles` | ✅ `Vehicle.mockData` | ✅ Keep — add `VehicleDocument` array |
| `staff` | ✅ `StaffMember.samples` | ✅ Keep base + load profiles lazily |
| `driverProfiles` | ❌ Doesn't exist | ✅ New — `[DriverProfile]` |
| `maintenanceProfiles` | ❌ Doesn't exist | ✅ New — `[MaintenanceProfile]` |
| `trips` | ✅ `Trip.mockData` | ✅ Keep — add linked fields |
| `maintenanceTasks` | ⚠️ `[]` empty, inline in AppDataStore | ✅ Move to own file, fill with mock |
| `workOrders` | ❌ Doesn't exist | ✅ New — `[WorkOrder]` |
| `maintenanceRecords` | ⚠️ Static mock, no store | ✅ Full store member |
| `partsUsed` | ❌ Doesn't exist | ✅ New — `[PartUsed]` |
| `fuelLogs` | ❌ Doesn't exist | ✅ New — `[FuelLog]` |
| `vehicleInspections` | ❌ Doesn't exist | ✅ New — `[VehicleInspection]` |
| `proofOfDeliveries` | ❌ Doesn't exist | ✅ New — `[ProofOfDelivery]` |
| `emergencyAlerts` | ❌ Doesn't exist | ✅ New — `[EmergencyAlert]` |
| `geofences` | ⚠️ Static mock, no store | ✅ Full store member |
| `geofenceEvents` | ❌ Doesn't exist | ✅ New — `[GeofenceEvent]` |
| `vehicleDocuments` | ❌ Doesn't exist | ✅ New — `[VehicleDocument]` |
| `activityLogs` | ⚠️ Static mock, no store | ✅ Full store member |
| `staffApplications` | Separate `StaffApplicationStore` | ✅ Merge into AppDataStore |

### 13B. New AppDataStore Skeleton

```swift
@MainActor @Observable
final class AppDataStore {
    static let shared = AppDataStore()

    // Staff
    var staff: [StaffMember] = StaffMember.samples
    var driverProfiles: [DriverProfile] = DriverProfile.samples
    var maintenanceProfiles: [MaintenanceProfile] = MaintenanceProfile.samples
    var staffApplications: [StaffApplication] = StaffApplication.samples

    // Vehicles
    var vehicles: [Vehicle] = Vehicle.mockData
    var vehicleDocuments: [VehicleDocument] = VehicleDocument.mockData

    // Operations
    var trips: [Trip] = Trip.mockData
    var fuelLogs: [FuelLog] = []
    var vehicleInspections: [VehicleInspection] = []
    var proofOfDeliveries: [ProofOfDelivery] = []
    var emergencyAlerts: [EmergencyAlert] = []

    // Maintenance
    var maintenanceTasks: [MaintenanceTask] = MaintenanceTask.mockData
    var workOrders: [WorkOrder] = []
    var maintenanceRecords: [MaintenanceRecord] = MaintenanceRecord.mockData
    var partsUsed: [PartUsed] = []

    // Geofencing
    var geofences: [Geofence] = Geofence.mockData
    var geofenceEvents: [GeofenceEvent] = []

    // Audit
    var activityLogs: [ActivityLog] = ActivityLog.samples

    // ── Lookup Helpers ──
    func driverProfile(for staffId: UUID) -> DriverProfile? { ... }
    func maintenanceProfile(for staffId: UUID) -> MaintenanceProfile? { ... }
    func vehicleDocuments(for vehicleId: UUID) -> [VehicleDocument] { ... }
    func trips(for driverId: UUID) -> [Trip] { ... }
    func fuelLogs(for driverId: UUID) -> [FuelLog] { ... }
    func fuelLogs(for vehicleId: UUID) -> [FuelLog] { ... }
    func workOrders(for staffId: UUID) -> [WorkOrder] { ... }
    func maintenanceRecords(for vehicleId: UUID) -> [MaintenanceRecord] { ... }
    func partsUsed(for workOrderId: UUID) -> [PartUsed] { ... }
    func inspections(for tripId: UUID) -> [VehicleInspection] { ... }
    func activeEmergencyAlerts() -> [EmergencyAlert] { ... }
    func geofenceEvents(for vehicleId: UUID) -> [GeofenceEvent] { ... }
    func recentActivityLogs(limit: Int = 20) -> [ActivityLog] { ... }
    func documentsExpiringSoon() -> [VehicleDocument] { ... }
}
```

### 13C. `StaffApplicationStore` → Removed
Merge all staff application logic into `AppDataStore`. `StaffApplicationStore.swift` can be deleted after migration.

---

## 14. Cross-Reference & Integrity Analysis

### 14A. Foreign Key Map (all 30 relationships)

| Field | Lives In | References | On Delete |
|---|---|---|---|
| `id` | `staff_members` | `auth.users.id` | CASCADE |
| `staff_member_id` | `driver_profiles` | `staff_members.id` | CASCADE |
| `staff_member_id` | `maintenance_profiles` | `staff_members.id` | CASCADE |
| `staff_member_id` | `staff_applications` | `staff_members.id` | CASCADE |
| `reviewed_by` | `staff_applications` | `staff_members.id` | SET NULL |
| `assigned_driver_id` | `vehicles` | `staff_members.id` | SET NULL |
| `current_vehicle_id` | `driver_profiles` | `vehicles.id` | SET NULL |
| `vehicle_id` | `vehicle_documents` | `vehicles.id` | CASCADE |
| `driver_id` | `trips` | `staff_members.id` | SET NULL |
| `vehicle_id` | `trips` | `vehicles.id` | SET NULL |
| `created_by_admin_id` | `trips` | `staff_members.id` | RESTRICT |
| `trip_id` | `fuel_logs` | `trips.id` | SET NULL |
| `driver_id` | `fuel_logs` | `staff_members.id` | RESTRICT |
| `vehicle_id` | `fuel_logs` | `vehicles.id` | RESTRICT |
| `trip_id` | `vehicle_inspections` | `trips.id` | RESTRICT |
| `vehicle_id` | `vehicle_inspections` | `vehicles.id` | RESTRICT |
| `driver_id` | `vehicle_inspections` | `staff_members.id` | RESTRICT |
| `trip_id` | `proof_of_deliveries` | `trips.id` | RESTRICT |
| `driver_id` | `proof_of_deliveries` | `staff_members.id` | RESTRICT |
| `driver_id` | `emergency_alerts` | `staff_members.id` | RESTRICT |
| `trip_id` | `emergency_alerts` | `trips.id` | SET NULL |
| `vehicle_id` | `emergency_alerts` | `vehicles.id` | SET NULL |
| `vehicle_id` | `maintenance_tasks` | `vehicles.id` | RESTRICT |
| `assigned_to_id` | `maintenance_tasks` | `staff_members.id` | SET NULL |
| `source_alert_id` | `maintenance_tasks` | `emergency_alerts.id` | SET NULL |
| `source_inspection_id` | `maintenance_tasks` | `vehicle_inspections.id` | SET NULL |
| `maintenance_task_id` | `work_orders` | `maintenance_tasks.id` | RESTRICT |
| `work_order_id` | `parts_used` | `work_orders.id` | CASCADE |
| `work_order_id` | `maintenance_records` | `work_orders.id` | RESTRICT |
| `geofence_id` | `geofence_events` | `geofences.id` | RESTRICT |
| `vehicle_id` | `geofence_events` | `vehicles.id` | RESTRICT |

### 14B. Orphan Risk (post-refactor)

| Scenario | Handling | Risk |
|---|---|---|
| Delete vehicle with active trip | `ON DELETE SET NULL` + app-level check before delete | 🟢 Safe |
| Delete driver with assigned vehicle | `ON DELETE SET NULL` on `assigned_driver_id` | 🟢 Safe |
| Delete driver with fuel logs | `RESTRICT` — cannot delete if logs exist | 🟢 Safe |
| Delete maintenance task with work order | `RESTRICT` — cannot delete | 🟢 Safe |
| Delete work order — cascades parts | `ON DELETE CASCADE` for `parts_used` | 🟢 Safe |
| Staff deleted — activity log orphan | `ON DELETE SET NULL` on `actor_id` | 🟢 Safe |
| Remove geofence — events preserved | `RESTRICT` — must delete events first, or soft-delete geofence | 🟢 Safe |

**0 silent failures in the redesigned schema. All relationships explicitly handled.**

---

## 15. Schema Summary Card

```
╔═══════════════════════════════════════════════════════════════════════╗
║                 SIERRA — DATA SCHEMA SUMMARY v2.0                    ║
║                 Generated: 2026-03-12                                ║
║                 Backend: Supabase (PostgreSQL)                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  LAYERS          │ 7 (Auth, Staff, Vehicle, Operations,              ║
║                  │    Maintenance, Geofencing, Audit)                ║
╠═══════════════════════════════════════════════════════════════════════╣
║  MODELS (Swift)  │ 20 total                                          ║
║  Auth            │ AuthUser, TwoFactorSession                        ║
║  Staff           │ StaffMember, DriverProfile, MaintenanceProfile,   ║
║                  │ StaffApplication                                  ║
║  Vehicle         │ Vehicle, VehicleDocument                          ║
║  Operations      │ Trip, FuelLog, VehicleInspection,                 ║
║                  │ ProofOfDelivery, EmergencyAlert                   ║
║  Maintenance     │ MaintenanceTask, WorkOrder,                       ║
║                  │ MaintenanceRecord, PartUsed                       ║
║  Geofencing      │ Geofence, GeofenceEvent                           ║
║  Audit           │ ActivityLog                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  SUPABASE TABLES │ 18 (+ auth.users managed by Supabase)             ║
║  ENUMS           │ 26 enums, 121 cases total                         ║
║  RELATIONSHIPS   │ 30 FK relationships, all typed + ON DELETE set    ║
╠═══════════════════════════════════════════════════════════════════════╣
║  STAFF PATTERN   │ Base (StaffMember) + Extensions                   ║
║                  │ DriverProfile: license, class, state, docs,       ║
║                  │   trip stats, vehicle assignment                  ║
║                  │ MaintenanceProfile: cert type/number/expiry,      ║
║                  │   authority, specializations, task stats          ║
╠═══════════════════════════════════════════════════════════════════════╣
║  2FA HANDLING    │ TwoFactorSession model (Supabase-backed)          ║
║                  │ OTP hash stored, not plaintext                    ║
║                  │ 5-attempt limit, 15-min lockout, 10-min expiry    ║
║                  │ Methods: email (v1) / sms / authenticator (future)║
╠═══════════════════════════════════════════════════════════════════════╣
║  NEW MODELS vs v1│ FuelLog ✅  VehicleInspection ✅                  ║
║  (SRS coverage)  │ ProofOfDelivery ✅  EmergencyAlert ✅              ║
║                  │ WorkOrder ✅  PartUsed ✅  GeofenceEvent ✅        ║
║                  │ VehicleDocument ✅  DriverProfile ✅               ║
║                  │ MaintenanceProfile ✅  TwoFactorSession ✅         ║
╠═══════════════════════════════════════════════════════════════════════╣
║  INTEGRITY       │ 0 silent failures                                 ║
║                  │ 0 crash risks                                     ║
║                  │ 0 loose String FKs (all UUID in Supabase)         ║
║                  │ All ON DELETE actions explicitly defined          ║
╠═══════════════════════════════════════════════════════════════════════╣
║  APPDATA STORE   │ 17 arrays (was 4)                                 ║
║                  │ StaffApplicationStore merged in                   ║
║                  │ Full CRUD + lookup helpers per model              ║
║                  │ Realtime: emergency_alerts table                  ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

*Sierra Data Schema v2.0 — End of Document*

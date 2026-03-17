# Phase 1 — Sprint 2 Swift Models

## Context
You are working on Sierra, an iOS Fleet Management System app using SwiftUI, MVVM, Swift Concurrency, and Supabase as the backend.

The app is in the Kanishk101/Sierra repository, main branch.

The Supabase project is Sierra-FMS-v2 (project ID: ldqcdngdlbbiojlnbnjg, region: ap-south-1).

The existing Swift models live in Sierra/Shared/Models/. All models conform to Codable and use snake_case CodingKeys to match Supabase column names. UUID fields are typed as UUID. Timestamps are typed as Date. Enums are defined as Swift enums with String raw values matching the Postgres enum labels exactly.

## What changed in the database (Sprint 2)

The following NEW tables were added to Supabase:
- vehicle_location_history (id, vehicle_id, trip_id, driver_id, latitude, longitude, speed_kmh, recorded_at, created_at)
- route_deviation_events (id, trip_id, driver_id, vehicle_id, latitude, longitude, deviation_distance_m, is_acknowledged, acknowledged_by, acknowledged_at, detected_at, created_at)
- notifications (id, recipient_id, type [notification_type enum], title, body, entity_type, entity_id, is_read, read_at, sent_at, created_at)
- trip_expenses (id, trip_id, driver_id, vehicle_id, expense_type [trip_expense_type enum], amount, receipt_url, notes, logged_at, created_at)
- spare_parts_requests (id, maintenance_task_id, work_order_id, requested_by_id, part_name, part_number, quantity, estimated_unit_cost, supplier, reason, status [spare_parts_request_status enum], reviewed_by, reviewed_at, rejection_reason, fulfilled_at, created_at, updated_at)

The following NEW enum types were added:
- geofence_type: "Warehouse", "Delivery Point", "Restricted Zone", "Custom"
- notification_type: "Trip Assigned", "Trip Cancelled", "Vehicle Assigned", "Maintenance Approved", "Maintenance Rejected", "Maintenance Overdue", "SOS Alert", "Defect Alert", "Route Deviation", "Geofence Violation", "Inspection Failed", "General"
- trip_expense_type: "Toll", "Parking", "Other"
- spare_parts_request_status: "Pending", "Approved", "Rejected", "Fulfilled"

The following NEW values were added to existing enums:
- emergency_alert_type now includes "Defect" (add this case to EmergencyAlert.swift)
- activity_type now includes "Route Deviation" (add this case to ActivityLog.swift)

The following COLUMNS were added to existing tables:
- staff_members: failed_login_attempts (Int, default 0), account_locked_until (Date?, nullable)
- trips: origin_latitude (Double?), origin_longitude (Double?), destination_latitude (Double?), destination_longitude (Double?), route_polyline (String?), driver_rating (Int?), driver_rating_note (String?), rated_by_id (UUID?), rated_at (Date?)
- vehicle_inspections: photo_urls ([String], default []), is_defect_raised (Bool, default false), raised_task_id (UUID?)
- proof_of_deliveries: delivery_otp_hash (String?), delivery_otp_expires_at (Date?), notes (String?)
- work_orders: repair_image_urls ([String], default []), estimated_completion_at (Date?)
- maintenance_tasks: approved_by_id (UUID?), approved_at (Date?), rejection_reason (String?)
- geofences: geofence_type (GeofenceType enum, default .custom)

## Your tasks

1. Read the current files:
   - Sierra/Shared/Models/Trip.swift
   - Sierra/Shared/Models/VehicleInspection.swift
   - Sierra/Shared/Models/ProofOfDelivery.swift
   - Sierra/Shared/Models/WorkOrder.swift
   - Sierra/Shared/Models/MaintenanceTask.swift
   - Sierra/Shared/Models/Geofence.swift
   - Sierra/Shared/Models/EmergencyAlert.swift
   - Sierra/Shared/Models/ActivityLog.swift
   - Sierra/Shared/Models/StaffMember.swift

2. Update each of those files to add the new columns listed above. Do not remove or change anything existing. Only add the new properties with correct CodingKeys.

3. Create these NEW model files:
   - Sierra/Shared/Models/VehicleLocationHistory.swift
   - Sierra/Shared/Models/RouteDeviationEvent.swift
   - Sierra/Shared/Models/SierraNotification.swift (name it SierraNotification to avoid conflict with Foundation's Notification)
   - Sierra/Shared/Models/TripExpense.swift
   - Sierra/Shared/Models/SparePartsRequest.swift

4. For each new model follow this exact pattern:
   - struct conforming to Codable, Identifiable, Equatable
   - All UUID fields typed as UUID
   - All timestamp fields typed as Date
   - All nullable fields typed as Optional
   - Array fields (like photo_urls) typed as [String] with default []
   - Enums defined as nested enum with String rawValue OR as separate enum if shared

5. For SierraNotification, define NotificationType enum with all values listed above.

6. For TripExpense, define TripExpenseType enum: Toll, Parking, Other.

7. For SparePartsRequest, define SparePartsRequestStatus enum: Pending, Approved, Rejected, Fulfilled.

8. For Geofence.swift, add GeofenceType enum: Warehouse, DeliveryPoint, RestrictedZone, Custom — with raw values matching exactly: "Warehouse", "Delivery Point", "Restricted Zone", "Custom".

## Output
Commit all changes to main branch. Each file must compile with no errors. Use the existing code style in the repo exactly.


-- ══════════════════════════════════════════════════════════════
-- REVERT: Drop all RLS policies, triggers, and helper function
-- ══════════════════════════════════════════════════════════════

-- staff_members
DROP POLICY IF EXISTS "Admin: full access to staff_members" ON public.staff_members;
DROP POLICY IF EXISTS "Staff: read own record" ON public.staff_members;
DROP POLICY IF EXISTS "Staff: update own non-sensitive fields" ON public.staff_members;

-- driver_profiles
DROP POLICY IF EXISTS "Admin: full access to driver_profiles" ON public.driver_profiles;
DROP POLICY IF EXISTS "Driver: read own profile" ON public.driver_profiles;

-- maintenance_profiles
DROP POLICY IF EXISTS "Admin: full access to maintenance_profiles" ON public.maintenance_profiles;
DROP POLICY IF EXISTS "Maintenance: read own profile" ON public.maintenance_profiles;

-- staff_applications
DROP POLICY IF EXISTS "Admin: full access to staff_applications" ON public.staff_applications;
DROP POLICY IF EXISTS "Staff: read and insert own application" ON public.staff_applications;
DROP POLICY IF EXISTS "Staff: insert own application" ON public.staff_applications;

-- two_factor_sessions
DROP POLICY IF EXISTS "User: read own 2FA session" ON public.two_factor_sessions;

-- vehicles
DROP POLICY IF EXISTS "Admin: full access to vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Driver: read own assigned vehicle" ON public.vehicles;
DROP POLICY IF EXISTS "Maintenance: read all vehicles" ON public.vehicles;

-- vehicle_documents
DROP POLICY IF EXISTS "Admin: full access to vehicle_documents" ON public.vehicle_documents;
DROP POLICY IF EXISTS "Driver: read documents for assigned vehicle" ON public.vehicle_documents;
DROP POLICY IF EXISTS "Maintenance: read all vehicle documents" ON public.vehicle_documents;

-- trips
DROP POLICY IF EXISTS "Admin: full access to trips" ON public.trips;
DROP POLICY IF EXISTS "Driver: read own trips" ON public.trips;
DROP POLICY IF EXISTS "Driver: update own trips" ON public.trips;

-- fuel_logs
DROP POLICY IF EXISTS "Admin: read all fuel_logs" ON public.fuel_logs;
DROP POLICY IF EXISTS "Driver: read own fuel_logs" ON public.fuel_logs;
DROP POLICY IF EXISTS "Driver: insert own fuel_logs" ON public.fuel_logs;
DROP POLICY IF EXISTS "Maintenance: read all fuel_logs" ON public.fuel_logs;

-- vehicle_inspections
DROP POLICY IF EXISTS "Admin: read all vehicle_inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Driver: read own vehicle_inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Driver: insert own vehicle_inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Maintenance: read all vehicle_inspections" ON public.vehicle_inspections;

-- proof_of_deliveries
DROP POLICY IF EXISTS "Admin: read all proof_of_deliveries" ON public.proof_of_deliveries;
DROP POLICY IF EXISTS "Driver: read own proof_of_deliveries" ON public.proof_of_deliveries;
DROP POLICY IF EXISTS "Driver: insert own proof_of_deliveries" ON public.proof_of_deliveries;

-- emergency_alerts
DROP POLICY IF EXISTS "Admin: full access to emergency_alerts" ON public.emergency_alerts;
DROP POLICY IF EXISTS "Driver: read own emergency_alerts" ON public.emergency_alerts;
DROP POLICY IF EXISTS "Driver: insert emergency_alerts" ON public.emergency_alerts;

-- maintenance_tasks
DROP POLICY IF EXISTS "Admin: full access to maintenance_tasks" ON public.maintenance_tasks;
DROP POLICY IF EXISTS "Maintenance: read own assigned tasks" ON public.maintenance_tasks;
DROP POLICY IF EXISTS "Maintenance: update own assigned tasks" ON public.maintenance_tasks;

-- work_orders
DROP POLICY IF EXISTS "Admin: read all work_orders" ON public.work_orders;
DROP POLICY IF EXISTS "Maintenance: read own work_orders" ON public.work_orders;
DROP POLICY IF EXISTS "Maintenance: update own work_orders" ON public.work_orders;

-- parts_used
DROP POLICY IF EXISTS "Admin: read all parts_used" ON public.parts_used;
DROP POLICY IF EXISTS "Maintenance: manage parts on own work_orders" ON public.parts_used;

-- maintenance_records
DROP POLICY IF EXISTS "Admin: read all maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Maintenance: read own maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Maintenance: insert own maintenance_records" ON public.maintenance_records;

-- geofences
DROP POLICY IF EXISTS "Admin: full access to geofences" ON public.geofences;
DROP POLICY IF EXISTS "Driver: read active geofences" ON public.geofences;
DROP POLICY IF EXISTS "Maintenance: read all geofences" ON public.geofences;

-- geofence_events
DROP POLICY IF EXISTS "Admin: read all geofence_events" ON public.geofence_events;
DROP POLICY IF EXISTS "Driver: read own geofence_events" ON public.geofence_events;

-- activity_logs
DROP POLICY IF EXISTS "Admin: read all activity_logs" ON public.activity_logs;
DROP POLICY IF EXISTS "Admin: update activity_logs read status" ON public.activity_logs;

-- ── Drop updated_at triggers ──────────────────────────────────
DROP TRIGGER IF EXISTS trg_staff_members_updated_at ON public.staff_members;
DROP TRIGGER IF EXISTS trg_driver_profiles_updated_at ON public.driver_profiles;
DROP TRIGGER IF EXISTS trg_maintenance_profiles_updated_at ON public.maintenance_profiles;
DROP TRIGGER IF EXISTS trg_vehicles_updated_at ON public.vehicles;
DROP TRIGGER IF EXISTS trg_vehicle_documents_updated_at ON public.vehicle_documents;
DROP TRIGGER IF EXISTS trg_trips_updated_at ON public.trips;
DROP TRIGGER IF EXISTS trg_maintenance_tasks_updated_at ON public.maintenance_tasks;
DROP TRIGGER IF EXISTS trg_work_orders_updated_at ON public.work_orders;
DROP TRIGGER IF EXISTS trg_geofences_updated_at ON public.geofences;

DROP FUNCTION IF EXISTS public.set_updated_at();

-- ── Drop helper function ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.sierra_user_role();
;


-- ================================================================
-- SIERRA FMS v2 — SPRINT 2 COMPLETE SCHEMA MIGRATION
-- ================================================================

-- ----------------------------------------------------------------
-- STEP 1: New enum types
-- ----------------------------------------------------------------

CREATE TYPE geofence_type AS ENUM (
  'Warehouse', 'Delivery Point', 'Restricted Zone', 'Custom'
);

CREATE TYPE notification_type AS ENUM (
  'Trip Assigned', 'Trip Cancelled', 'Vehicle Assigned',
  'Maintenance Approved', 'Maintenance Rejected', 'Maintenance Overdue',
  'SOS Alert', 'Defect Alert', 'Route Deviation',
  'Geofence Violation', 'Inspection Failed', 'General'
);

CREATE TYPE trip_expense_type AS ENUM (
  'Toll', 'Parking', 'Other'
);

CREATE TYPE spare_parts_request_status AS ENUM (
  'Pending', 'Approved', 'Rejected', 'Fulfilled'
);

-- ----------------------------------------------------------------
-- STEP 2: Add new values to existing enums
-- ----------------------------------------------------------------

ALTER TYPE emergency_alert_type ADD VALUE IF NOT EXISTS 'Defect';
ALTER TYPE activity_type ADD VALUE IF NOT EXISTS 'Route Deviation';

-- ----------------------------------------------------------------
-- STEP 3: Column additions to existing tables
-- ----------------------------------------------------------------

-- staff_members: automatic lockout support
ALTER TABLE staff_members
  ADD COLUMN IF NOT EXISTS failed_login_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS account_locked_until timestamptz;

-- trips: coordinates + polyline for MapKit/Mapbox routing
ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS origin_latitude double precision,
  ADD COLUMN IF NOT EXISTS origin_longitude double precision,
  ADD COLUMN IF NOT EXISTS destination_latitude double precision,
  ADD COLUMN IF NOT EXISTS destination_longitude double precision,
  ADD COLUMN IF NOT EXISTS route_polyline text,
  ADD COLUMN IF NOT EXISTS driver_rating smallint CHECK (driver_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS driver_rating_note text,
  ADD COLUMN IF NOT EXISTS rated_by_id uuid REFERENCES staff_members(id),
  ADD COLUMN IF NOT EXISTS rated_at timestamptz;

-- vehicle_inspections: photo uploads + defect tracking
ALTER TABLE vehicle_inspections
  ADD COLUMN IF NOT EXISTS photo_urls text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS is_defect_raised boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS raised_task_id uuid;
-- FK added after maintenance_tasks column addition below

-- proof_of_deliveries: OTP validation + notes
ALTER TABLE proof_of_deliveries
  ADD COLUMN IF NOT EXISTS delivery_otp_hash text,
  ADD COLUMN IF NOT EXISTS delivery_otp_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS notes text;

-- work_orders: repair photos + ETA
ALTER TABLE work_orders
  ADD COLUMN IF NOT EXISTS repair_image_urls text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS estimated_completion_at timestamptz;

-- maintenance_tasks: approval audit trail
ALTER TABLE maintenance_tasks
  ADD COLUMN IF NOT EXISTS approved_by_id uuid REFERENCES staff_members(id),
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS rejection_reason text;

-- geofences: zone classification
ALTER TABLE geofences
  ADD COLUMN IF NOT EXISTS geofence_type geofence_type NOT NULL DEFAULT 'Custom';

-- Now add the deferred FK from vehicle_inspections → maintenance_tasks
ALTER TABLE vehicle_inspections
  ADD CONSTRAINT fk_vehicle_inspections_raised_task
  FOREIGN KEY (raised_task_id) REFERENCES maintenance_tasks(id);

-- ----------------------------------------------------------------
-- STEP 4: New table — vehicle_location_history
-- ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS vehicle_location_history (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  trip_id uuid REFERENCES trips(id),
  driver_id uuid REFERENCES staff_members(id),
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  speed_kmh double precision,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vlh_vehicle_trip_time
  ON vehicle_location_history (vehicle_id, trip_id, recorded_at DESC);

ALTER TABLE vehicle_location_history ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------
-- STEP 5: New table — route_deviation_events
-- ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS route_deviation_events (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  trip_id uuid NOT NULL REFERENCES trips(id),
  driver_id uuid NOT NULL REFERENCES staff_members(id),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  deviation_distance_m double precision NOT NULL,
  is_acknowledged boolean NOT NULL DEFAULT false,
  acknowledged_by uuid REFERENCES staff_members(id),
  acknowledged_at timestamptz,
  detected_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rde_trip_ack
  ON route_deviation_events (trip_id, is_acknowledged);

ALTER TABLE route_deviation_events ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------
-- STEP 6: New table — notifications
-- ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  recipient_id uuid NOT NULL REFERENCES staff_members(id),
  type notification_type NOT NULL DEFAULT 'General',
  title text NOT NULL,
  body text NOT NULL,
  entity_type text,
  entity_id uuid,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamptz,
  sent_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_read
  ON notifications (recipient_id, is_read, sent_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------
-- STEP 7: New table — trip_expenses
-- ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS trip_expenses (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  trip_id uuid NOT NULL REFERENCES trips(id),
  driver_id uuid NOT NULL REFERENCES staff_members(id),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  expense_type trip_expense_type NOT NULL,
  amount double precision NOT NULL,
  receipt_url text,
  notes text,
  logged_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE trip_expenses ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------
-- STEP 8: New table — spare_parts_requests
-- ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS spare_parts_requests (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  maintenance_task_id uuid NOT NULL REFERENCES maintenance_tasks(id),
  work_order_id uuid REFERENCES work_orders(id),
  requested_by_id uuid NOT NULL REFERENCES staff_members(id),
  part_name text NOT NULL,
  part_number text,
  quantity integer NOT NULL DEFAULT 1,
  estimated_unit_cost double precision,
  supplier text,
  reason text NOT NULL,
  status spare_parts_request_status NOT NULL DEFAULT 'Pending',
  reviewed_by uuid REFERENCES staff_members(id),
  reviewed_at timestamptz,
  rejection_reason text,
  fulfilled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE spare_parts_requests ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------
-- STEP 9: Triggers — trip status state machine
-- ----------------------------------------------------------------

-- Trigger function: on trip started (Scheduled → Active)
CREATE OR REPLACE FUNCTION handle_trip_started()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'Active' AND OLD.status = 'Scheduled' THEN
    -- Set vehicle to Busy
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles
        SET status = 'Busy', updated_at = now()
        WHERE id = NEW.vehicle_id;
    END IF;
    -- Set driver to On Trip
    IF NEW.driver_id IS NOT NULL THEN
      UPDATE staff_members
        SET availability = 'On Trip', updated_at = now()
        WHERE id = NEW.driver_id;
    END IF;
    -- Record actual start time
    NEW.actual_start_date = COALESCE(NEW.actual_start_date, now());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trip_started ON trips;
CREATE TRIGGER trg_trip_started
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION handle_trip_started();

-- Trigger function: on trip completed (Active → Completed)
CREATE OR REPLACE FUNCTION handle_trip_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_distance double precision;
BEGIN
  IF NEW.status = 'Completed' AND OLD.status = 'Active' THEN
    -- Calculate distance driven (guard against bad odometer data)
    v_distance := GREATEST(COALESCE(NEW.end_mileage, 0) - COALESCE(NEW.start_mileage, 0), 0);

    -- Record actual end time
    NEW.actual_end_date = COALESCE(NEW.actual_end_date, now());

    -- Update vehicle stats
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles SET
        status = 'Idle',
        odometer = odometer + v_distance,
        total_trips = total_trips + 1,
        total_distance_km = total_distance_km + v_distance,
        updated_at = now()
      WHERE id = NEW.vehicle_id;
    END IF;

    -- Update driver availability
    IF NEW.driver_id IS NOT NULL THEN
      UPDATE staff_members SET
        availability = 'Available',
        updated_at = now()
      WHERE id = NEW.driver_id;

      -- Update driver profile stats
      UPDATE driver_profiles SET
        total_trips_completed = total_trips_completed + 1,
        total_distance_km = total_distance_km + v_distance,
        updated_at = now()
      WHERE staff_member_id = NEW.driver_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trip_completed ON trips;
CREATE TRIGGER trg_trip_completed
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION handle_trip_completed();

-- Trigger function: on trip cancelled (Scheduled/Active → Cancelled)
CREATE OR REPLACE FUNCTION handle_trip_cancelled()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'Cancelled' AND OLD.status IN ('Scheduled', 'Active') THEN
    -- Free up vehicle
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles SET
        status = 'Idle',
        updated_at = now()
      WHERE id = NEW.vehicle_id;
    END IF;
    -- Free up driver
    IF NEW.driver_id IS NOT NULL THEN
      UPDATE staff_members SET
        availability = 'Available',
        updated_at = now()
      WHERE id = NEW.driver_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trip_cancelled ON trips;
CREATE TRIGGER trg_trip_cancelled
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION handle_trip_cancelled();

-- ----------------------------------------------------------------
-- STEP 10: Performance indexes
-- ----------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_trips_driver_status
  ON trips (driver_id, status);

CREATE INDEX IF NOT EXISTS idx_trips_vehicle_status
  ON trips (vehicle_id, status);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient
  ON notifications (recipient_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_emergency_alerts_status
  ON emergency_alerts (status, alert_type);
;

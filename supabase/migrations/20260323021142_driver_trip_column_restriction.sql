
-- ================================================================
-- Migration: driver_trip_column_restriction
-- ================================================================
-- Problem: The trips_update RLS policy lets a driver (driver_id =
-- auth.uid()) update ANY column — including route_stops, origin,
-- destination, vehicle_id, scheduled_date, etc. There is no
-- with_check restricting which columns a driver can change.
--
-- Fix: BEFORE UPDATE trigger that raises if a driver is trying to
-- change any admin-only column. Fleet managers bypass this check.
-- ================================================================

CREATE OR REPLACE FUNCTION public.trg_fn_restrict_driver_trip_writes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
BEGIN
  -- Fleet managers can change anything
  SELECT get_my_role() INTO v_role;
  IF v_role = 'fleetManager' THEN
    RETURN NEW;
  END IF;

  -- For drivers: block modification of admin-only columns.
  -- These are columns that define the trip itself (not the driver's
  -- lifecycle actions on it).
  IF NEW.route_stops         IS DISTINCT FROM OLD.route_stops         THEN
    RAISE EXCEPTION 'Drivers cannot modify route stops. Contact your fleet manager.';
  END IF;
  IF NEW.origin              IS DISTINCT FROM OLD.origin              THEN
    RAISE EXCEPTION 'Drivers cannot modify trip origin.';
  END IF;
  IF NEW.destination         IS DISTINCT FROM OLD.destination         THEN
    RAISE EXCEPTION 'Drivers cannot modify trip destination.';
  END IF;
  IF NEW.origin_latitude     IS DISTINCT FROM OLD.origin_latitude     OR
     NEW.origin_longitude    IS DISTINCT FROM OLD.origin_longitude    OR
     NEW.destination_latitude  IS DISTINCT FROM OLD.destination_latitude OR
     NEW.destination_longitude IS DISTINCT FROM OLD.destination_longitude THEN
    RAISE EXCEPTION 'Drivers cannot modify trip coordinates.';
  END IF;
  IF NEW.vehicle_id          IS DISTINCT FROM OLD.vehicle_id          THEN
    RAISE EXCEPTION 'Drivers cannot change the assigned vehicle.';
  END IF;
  IF NEW.driver_id           IS DISTINCT FROM OLD.driver_id           THEN
    RAISE EXCEPTION 'Drivers cannot reassign trips.';
  END IF;
  IF NEW.scheduled_date      IS DISTINCT FROM OLD.scheduled_date      THEN
    RAISE EXCEPTION 'Drivers cannot change the trip schedule.';
  END IF;
  IF NEW.scheduled_end_date  IS DISTINCT FROM OLD.scheduled_end_date  THEN
    RAISE EXCEPTION 'Drivers cannot change the trip schedule.';
  END IF;
  IF NEW.delivery_instructions IS DISTINCT FROM OLD.delivery_instructions THEN
    RAISE EXCEPTION 'Drivers cannot modify delivery instructions.';
  END IF;
  IF NEW.priority            IS DISTINCT FROM OLD.priority            THEN
    RAISE EXCEPTION 'Drivers cannot change trip priority.';
  END IF;
  IF NEW.created_by_admin_id IS DISTINCT FROM OLD.created_by_admin_id THEN
    RAISE EXCEPTION 'Drivers cannot change trip ownership.';
  END IF;
  IF NEW.route_polyline      IS DISTINCT FROM OLD.route_polyline      THEN
    RAISE EXCEPTION 'Drivers cannot modify the route polyline.';
  END IF;

  RETURN NEW;
END;
$$;

-- Drop and recreate to avoid duplicate
DROP TRIGGER IF EXISTS trg_restrict_driver_trip_writes ON public.trips;

CREATE TRIGGER trg_restrict_driver_trip_writes
  BEFORE UPDATE ON public.trips
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_restrict_driver_trip_writes();

COMMENT ON FUNCTION public.trg_fn_restrict_driver_trip_writes() IS
  'Prevents drivers from modifying admin-owned trip columns. Fleet managers bypass all checks.';
;

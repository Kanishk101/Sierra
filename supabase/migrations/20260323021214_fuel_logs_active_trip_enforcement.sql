
-- ================================================================
-- Migration: fuel_logs_active_trip_enforcement
-- ================================================================
-- Problem: Drivers can insert fuel_logs with any trip_id (or none),
-- even when the trip is Scheduled, Cancelled, etc.
--
-- Rule:
--   If trip_id is provided → the referenced trip MUST be Active or
--   Completed (fuel logs for a Completed trip = after-the-fact
--   receipts are allowed for admin reconciliation only, so we
--   restrict strict driver inserts to Active only).
--
--   If trip_id is NULL → it is a standalone fuel log (admin can
--   create these; drivers cannot create trip-unlinked fuel logs).
--
-- Implementation: BEFORE INSERT trigger (avoids re-querying on
-- every select/update, unlike a check constraint referencing
-- another table).
-- ================================================================

CREATE OR REPLACE FUNCTION public.trg_fn_enforce_fuel_log_trip_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role       TEXT;
  v_trip_status TEXT;
BEGIN
  SELECT get_my_role() INTO v_role;

  -- Fleet managers can log fuel freely (admin reconciliation)
  IF v_role = 'fleetManager' THEN
    RETURN NEW;
  END IF;

  -- Drivers MUST provide a trip_id (no standalone fuel logs)
  IF NEW.trip_id IS NULL THEN
    RAISE EXCEPTION 'Drivers must link a fuel log to an active trip.';
  END IF;

  -- The linked trip must be Active
  SELECT status INTO v_trip_status
  FROM public.trips
  WHERE id = NEW.trip_id;

  IF v_trip_status IS NULL THEN
    RAISE EXCEPTION 'Referenced trip does not exist.';
  END IF;

  IF v_trip_status != 'Active' THEN
    RAISE EXCEPTION 'Fuel can only be logged for an active trip (current status: %).', v_trip_status;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_fuel_log_trip_status ON public.fuel_logs;

CREATE TRIGGER trg_enforce_fuel_log_trip_status
  BEFORE INSERT ON public.fuel_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_enforce_fuel_log_trip_status();

COMMENT ON FUNCTION public.trg_fn_enforce_fuel_log_trip_status() IS
  'Ensures drivers can only log fuel during an active trip. Fleet managers are unrestricted.';
;

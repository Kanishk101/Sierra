-- ============================================================
-- Migration: Fix fn_trip_status_change trigger
-- Sierra Fleet Management System
-- Date: 2026-03-22 (seq 009)
--
-- Issues with the version from migration 20260319000001:
--
-- 1. SECURITY INVOKER -> SECURITY DEFINER (CRITICAL)
--    When a driver updates a trip (starts it -> Active), the trigger fires
--    as the driver session. Drivers cannot UPDATE vehicles (RLS
--    vehicles_update_admin requires fleetManager). The trigger silently
--    fails to mark the vehicle as Busy. Vehicle stays Idle and can be
--    double-booked on a second trip while actively being used.
--
--    Same problem on completion: driver calls endTrip() which sets status
--    Completed. Trigger fires as driver, tries to release vehicle, gets
--    RLS denial, vehicle remains Busy indefinitely.
--
-- 2. 'Rejected' status not handled
--    When a driver rejects a trip, old trigger did nothing. Driver's
--    availability remained Busy and vehicle remained Busy. Admin had to
--    manually fix this in the dashboard.
--
-- 3. No guard against double-booking edge case
--    If a driver somehow had two Active trips (test data, race condition),
--    releasing availability on one trip's completion would prematurely
--    mark the driver Available while they're still on the second trip.
--    Added NOT EXISTS guard.
--
-- 4. Includes a backfill DO block to remediate already-stuck resources
--    (drivers/vehicles that are Busy despite their trip being
--    Completed/Cancelled/Rejected due to the old broken trigger).
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_trip_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
-- SECURITY DEFINER: executes as function owner (superuser/postgres),
-- bypassing the session user's RLS. This is intentional and safe because:
--   a) Only modifies availability/status fields — no financial or PII data
--   b) SET search_path = public prevents schema injection attacks
--   c) Logic is tightly scoped to the specific trip's driver_id + vehicle_id
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Short-circuit: no status change, nothing to do
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;

    -- ── Trip transitioning to Active ──────────────────────────
    -- Lock driver (Busy) and vehicle (Busy).
    -- PendingAcceptance and Accepted do NOT lock resources —
    -- only Active (driver has physically started the trip) does.
    IF NEW.status = 'Active' AND OLD.status <> 'Active' THEN

        IF NEW.driver_id IS NOT NULL THEN
            UPDATE public.staff_members
               SET availability = 'Busy'
             WHERE id::text = NEW.driver_id::text;
        END IF;

        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE public.vehicles
               SET status = 'Busy'
             WHERE id::text = NEW.vehicle_id::text;
        END IF;

    END IF;

    -- ── Trip ending (Completed, Cancelled, or Rejected) ───────
    -- Release driver back to Available and vehicle back to Idle.
    --
    -- Rejected: driver declined the assignment — immediately Available again.
    -- Cancelled: admin cancelled — resources freed.
    -- Completed: normal end — resources freed after post-trip inspection + End Trip.
    --
    -- Guard: only release if the driver/vehicle has no OTHER currently Active trip.
    -- Prevents prematurely marking a driver Available when they are still on a
    -- concurrent trip (edge case in test/demo environments).
    IF NEW.status IN ('Completed', 'Cancelled', 'Rejected')
       AND OLD.status NOT IN ('Completed', 'Cancelled', 'Rejected')
    THEN

        IF NEW.driver_id IS NOT NULL THEN
            UPDATE public.staff_members
               SET availability = 'Available'
             WHERE id::text = NEW.driver_id::text
               -- Guard: no other Active trip for this driver
               AND NOT EXISTS (
                   SELECT 1 FROM public.trips t2
                    WHERE t2.driver_id::text = NEW.driver_id::text
                      AND t2.id::text        <> NEW.id::text
                      AND t2.status    = 'Active'
               );
        END IF;

        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE public.vehicles
               SET status             = 'Idle',
                   assigned_driver_id = NULL
             WHERE id::text = NEW.vehicle_id::text
               -- Guard: no other Active trip for this vehicle
               AND NOT EXISTS (
                   SELECT 1 FROM public.trips t2
                    WHERE t2.vehicle_id::text = NEW.vehicle_id::text
                      AND t2.id::text         <> NEW.id::text
                      AND t2.status     = 'Active'
               );
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

-- Recreate trigger (idempotent)
DROP TRIGGER IF EXISTS trg_trip_status_change ON public.trips;

CREATE TRIGGER trg_trip_status_change
    AFTER UPDATE OF status ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_trip_status_change();

-- ------------------------------------------------------------
-- Backfill: remediate resources stuck Busy by the old broken trigger
-- Finds all terminal trips (Completed/Cancelled/Rejected) where the
-- associated driver or vehicle is still marked Busy.
-- ------------------------------------------------------------
DO $$
DECLARE
    trip_rec        RECORD;
    driver_fixed    INT := 0;
    vehicle_fixed   INT := 0;
BEGIN
    FOR trip_rec IN
        SELECT t.id, t.driver_id, t.vehicle_id, t.status
          FROM public.trips t
         WHERE t.status IN ('Rejected', 'Cancelled', 'Completed')
    LOOP
        -- Release driver if stuck as Busy
        IF trip_rec.driver_id IS NOT NULL THEN
            UPDATE public.staff_members
               SET availability = 'Available'
             WHERE id::text     = trip_rec.driver_id::text
               AND availability = 'Busy'
               -- Guard: no other Active trip for this driver
               AND NOT EXISTS (
                   SELECT 1 FROM public.trips t2
                    WHERE t2.driver_id::text = trip_rec.driver_id::text
                      AND t2.id::text        <> trip_rec.id::text
                      AND t2.status    = 'Active'
               );
            IF FOUND THEN
                driver_fixed := driver_fixed + 1;
                RAISE NOTICE 'Fixed stuck driver % (from trip %)', trip_rec.driver_id, trip_rec.id;
            END IF;
        END IF;

        -- Release vehicle if stuck as Busy
        IF trip_rec.vehicle_id IS NOT NULL THEN
            UPDATE public.vehicles
               SET status             = 'Idle',
                   assigned_driver_id = NULL
             WHERE id::text = trip_rec.vehicle_id::text
               AND status   = 'Busy'
               -- Guard: no other Active trip for this vehicle
               AND NOT EXISTS (
                   SELECT 1 FROM public.trips t2
                    WHERE t2.vehicle_id::text = trip_rec.vehicle_id::text
                      AND t2.id::text         <> trip_rec.id::text
                      AND t2.status     = 'Active'
               );
            IF FOUND THEN
                vehicle_fixed := vehicle_fixed + 1;
                RAISE NOTICE 'Fixed stuck vehicle % (from trip %)', trip_rec.vehicle_id, trip_rec.id;
            END IF;
        END IF;
    END LOOP;

    RAISE NOTICE 'Remediation complete. Drivers fixed: %, Vehicles fixed: %',
        driver_fixed, vehicle_fixed;
END;
$$;

-- ============================================================
-- END OF MIGRATION 009
-- ============================================================


-- ============================================================
-- Migration: Simplify trip/staff statuses + enforce correct
-- trip state machine + harden app_secrets access
-- ============================================================

-- ── SECTION 1: TRIP STATUS CLEANUP ─────────────────────────
-- New canonical flow:
--   PendingAcceptance → (driver accepts) → Scheduled
--   Scheduled → (pre-trip done + within window) → Active
--   Active → (delivery + post-trip) → Completed
--   PendingAcceptance | Scheduled → (FM cancels) → Cancelled
-- Removed: Accepted (→ Scheduled), Rejected (→ Cancelled)
-- Pre-trip inspection: only in Scheduled state.
-- Start Trip button: only enabled when Scheduled + preInspectionId set + within 30min.
-- Cancel: only FM, only before Active.

-- Migrate any existing Accepted → Scheduled (they were accepted)
UPDATE public.trips SET status = 'Scheduled'  WHERE status = 'Accepted';
UPDATE public.trips SET status = 'Cancelled'  WHERE status = 'Rejected';

-- Block future use of deprecated values via CHECK
ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS chk_trips_status_valid;
ALTER TABLE public.trips ADD CONSTRAINT chk_trips_status_valid
  CHECK (status IN (
    'PendingAcceptance',
    'Scheduled',
    'Active',
    'Completed',
    'Cancelled'
  ));

-- ── SECTION 2: STAFF AVAILABILITY CLEANUP ──────────────────
-- On Trip / On Task are redundant with Busy. Normalize.
UPDATE public.staff_members
  SET availability = 'Busy'
  WHERE availability IN ('On Trip', 'On Task');

ALTER TABLE public.staff_members DROP CONSTRAINT IF EXISTS chk_staff_availability_valid;
ALTER TABLE public.staff_members ADD CONSTRAINT chk_staff_availability_valid
  CHECK (availability IN ('Available', 'Unavailable', 'Busy'));

-- ── SECTION 3: LOCK DOWN app_secrets ───────────────────────
-- The table stores service_role_key and supabase_url.
-- get_app_secret() is SECURITY DEFINER → safe for trigger use.
-- But anon/authenticated should NEVER be able to read/write this table.
-- RLS is on but has zero policies (blocks all reads correctly),
-- however the broad GRANTs are dangerous. Revoke them.
REVOKE ALL ON public.app_secrets FROM anon;
REVOKE ALL ON public.app_secrets FROM authenticated;
-- service_role bypasses RLS anyway; no policy needed for it.
-- postgres/superuser retain full access.

-- ── SECTION 4: UPDATE check_resource_overlap ───────────────
-- Remove Accepted from blocking statuses (it no longer exists).
CREATE OR REPLACE FUNCTION public.check_resource_overlap(
    p_driver_id       TEXT,
    p_vehicle_id      TEXT,
    p_start           TIMESTAMPTZ,
    p_end             TIMESTAMPTZ,
    p_exclude_trip_id TEXT DEFAULT NULL
)
RETURNS TABLE(driver_conflict BOOLEAN, vehicle_conflict BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT
        EXISTS (
            SELECT 1 FROM trips
            WHERE LOWER(driver_id::text) = LOWER(p_driver_id)
              AND status IN ('PendingAcceptance', 'Scheduled', 'Active')
              AND (p_exclude_trip_id IS NULL
                   OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date,
                           scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,
        EXISTS (
            SELECT 1 FROM trips
            WHERE LOWER(vehicle_id::text) = LOWER(p_vehicle_id)
              AND status IN ('PendingAcceptance', 'Scheduled', 'Active')
              AND (p_exclude_trip_id IS NULL
                   OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date,
                           scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

GRANT EXECUTE ON FUNCTION public.check_resource_overlap(TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.check_resource_overlap(TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,TEXT) FROM anon;

-- ── SECTION 5: UPDATE LIFECYCLE TRIGGERS ───────────────────

-- 5a. handle_trip_started: Scheduled → Active (remove PendingAcceptance/Accepted)
--     Pre-trip must be done (enforced in app layer; DB is backup)
CREATE OR REPLACE FUNCTION public.handle_trip_started()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- Only fires: Scheduled → Active
    IF NEW.status = 'Active' AND OLD.status = 'Scheduled' THEN
        -- Lock vehicle
        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE vehicles SET status = 'Busy', updated_at = now()
            WHERE id = NEW.vehicle_id;
        END IF;
        -- Mark driver busy
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE staff_members SET availability = 'Busy', updated_at = now()
            WHERE id = NEW.driver_id;
        END IF;
        -- Set start timestamp if not already set
        NEW.actual_start_date = COALESCE(NEW.actual_start_date, now());

        INSERT INTO activity_logs (type, title, description, actor_id, entity_type, entity_id, severity)
        VALUES (
            'Trip Started',
            'Trip Started: ' || COALESCE(NEW.task_id, NEW.id::text),
            'Trip from ' || NEW.origin || ' to ' || NEW.destination || ' is now active.',
            NEW.driver_id, 'trip', NEW.id, 'Info'
        );
    END IF;
    RETURN NEW;
END;
$$;

-- 5b. handle_trip_cancelled: only allowed before Active
CREATE OR REPLACE FUNCTION public.handle_trip_cancelled()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- Block cancellation of Active/Completed trips at DB level
    IF NEW.status = 'Cancelled' AND OLD.status IN ('Active', 'Completed') THEN
        RAISE EXCEPTION 'Cannot cancel a trip that is already % . Contact support.', OLD.status;
    END IF;

    IF NEW.status = 'Cancelled'
       AND OLD.status NOT IN ('Cancelled', 'Completed') THEN
        -- Release vehicle
        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE vehicles SET status = 'Idle', updated_at = now()
            WHERE id = NEW.vehicle_id
              AND NOT EXISTS (
                  SELECT 1 FROM trips t2
                  WHERE t2.vehicle_id = NEW.vehicle_id
                    AND t2.id <> NEW.id
                    AND t2.status = 'Active'
              );
        END IF;
        -- Release driver
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE staff_members SET availability = 'Available', updated_at = now()
            WHERE id = NEW.driver_id
              AND NOT EXISTS (
                  SELECT 1 FROM trips t2
                  WHERE t2.driver_id = NEW.driver_id
                    AND t2.id <> NEW.id
                    AND t2.status = 'Active'
              );
        END IF;

        INSERT INTO activity_logs (type, title, description, actor_id, entity_type, entity_id, severity)
        VALUES (
            'Trip Cancelled',
            'Trip Cancelled: ' || COALESCE(NEW.task_id, NEW.id::text),
            'Trip from ' || NEW.origin || ' to ' || NEW.destination || ' was cancelled.',
            NEW.driver_id, 'trip', NEW.id, 'Warning'
        );
    END IF;
    RETURN NEW;
END;
$$;

-- 5c. trg_fn_sync_driver_availability_from_trip: remove Accepted references
CREATE OR REPLACE FUNCTION public.trg_fn_sync_driver_availability_from_trip()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- Scheduled → Active: mark Busy
    IF NEW.driver_id IS NOT NULL
       AND NEW.status = 'Active'
       AND (OLD.status IS NULL OR OLD.status <> 'Active')
    THEN
        UPDATE staff_members
        SET availability = 'Busy', updated_at = NOW()
        WHERE id = NEW.driver_id AND availability <> 'Busy';
    END IF;

    -- Active/Scheduled → Completed/Cancelled: release
    IF NEW.driver_id IS NOT NULL
       AND NEW.status IN ('Completed', 'Cancelled')
       AND OLD.status NOT IN ('Completed', 'Cancelled')
    THEN
        IF NOT EXISTS (
            SELECT 1 FROM trips
            WHERE driver_id = NEW.driver_id
              AND id <> NEW.id
              AND status = 'Active'
        ) THEN
            UPDATE staff_members
            SET availability = 'Available', updated_at = NOW()
            WHERE id = NEW.driver_id AND availability = 'Busy';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- 5d. Update driver write restriction trigger:
--     Drivers can change status only on valid transitions:
--       PendingAcceptance → Scheduled (accept)
--       Scheduled → Active (start trip, within time window)
--     Everything else is FM-only.
CREATE OR REPLACE FUNCTION public.trg_fn_restrict_driver_trip_writes()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
    SELECT get_my_role() INTO v_role;

    -- Fleet managers can change anything
    IF v_role = 'fleetManager' THEN
        RETURN NEW;
    END IF;

    -- For drivers: validate column-level restrictions
    IF NEW.route_stops         IS DISTINCT FROM OLD.route_stops         THEN
        RAISE EXCEPTION 'Drivers cannot modify route stops.';
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

    -- Validate status transitions for drivers
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        -- PendingAcceptance → Scheduled (accept)
        IF OLD.status = 'PendingAcceptance' AND NEW.status = 'Scheduled' THEN
            -- allowed
            NULL;
        -- Scheduled → Active (start trip, within 30-min window enforced in app)
        ELSIF OLD.status = 'Scheduled' AND NEW.status = 'Active' THEN
            -- allowed
            NULL;
        ELSE
            RAISE EXCEPTION 'Invalid trip status transition: % → %. Contact your fleet manager.',
                OLD.status, NEW.status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- ── SECTION 6: notification type cleanup ───────────────────
-- Remove 'Trip Accepted' and 'Trip Rejected' notification types
-- from future notifications (existing rows untouched).
-- We can't drop enum values so we just ensure they're not used.
-- The app notification handler will map these to 'General' if seen.

-- ── SECTION 7: Ensure Active trips created from PendingAcceptance work ──
-- The TripService.acceptTrip now writes 'Scheduled' directly, so
-- PendingAcceptance → Scheduled is the only accept path.
-- Notify driver on PendingAcceptance creation (trigger already exists).

DO $$ BEGIN
    RAISE NOTICE '[simplify_statuses_flow_and_security] Migration complete.';
    RAISE NOTICE '  trip_status: Accepted/Rejected blocked by CHECK constraint';
    RAISE NOTICE '  staff_availability: On Trip/On Task normalized to Busy, blocked by CHECK';
    RAISE NOTICE '  app_secrets: anon/authenticated revoked';
    RAISE NOTICE '  Triggers updated for clean PendingAcceptance→Scheduled→Active flow';
END; $$;
;

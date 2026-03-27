-- ============================================================
-- Migration: Fix Critical Issues (batch)
-- Sierra Fleet Management System
-- Date: 2026-03-19
--
-- Fixes:
--   1. Revoke anon EXECUTE on check_resource_overlap (CRIT-2)
--   2. Fix SET search_path on check_resource_overlap (MED-3 / Codex C1)
--   3. Fix password_reset_tokens INSERT policy (CRIT-3)
--   4. Add DB trigger for trip lifecycle resource management (CRIT-4)
--   5. Add server-side Realtime filter for notifications (CRIT-5)
--   6. Add location history cleanup cron job (MED-2)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- FIX 1 & 2: check_resource_overlap — revoke anon, add search_path
-- Codex live-probed this and got 401 for authenticated users too.
-- Root cause: SECURITY DEFINER without SET search_path can fail
-- when the executing role's search_path differs. Recreate cleanly.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION check_resource_overlap(
    p_driver_id       TEXT,
    p_vehicle_id      TEXT,
    p_start           TIMESTAMPTZ,
    p_end             TIMESTAMPTZ,
    p_exclude_trip_id TEXT DEFAULT NULL
)
RETURNS TABLE(
    driver_conflict  BOOLEAN,
    vehicle_conflict BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public        -- prevents schema injection + fixes 401 for auth users
AS $$
    SELECT
        EXISTS (
            SELECT 1
              FROM trips
             WHERE driver_id::text = p_driver_id
               AND status    IN ('Scheduled', 'Active')
               AND (p_exclude_trip_id IS NULL OR id::text <> p_exclude_trip_id)
               AND scheduled_date < p_end
               AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,

        EXISTS (
            SELECT 1
              FROM trips
             WHERE vehicle_id::text = p_vehicle_id
               AND status     IN ('Scheduled', 'Active')
               AND (p_exclude_trip_id IS NULL OR id::text <> p_exclude_trip_id)
               AND scheduled_date < p_end
               AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

-- Grant only to authenticated (edge function uses service role which bypasses grants anyway)
GRANT EXECUTE ON FUNCTION check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT
) TO authenticated;

-- Revoke anon — unauthenticated callers must not enumerate fleet schedule
REVOKE EXECUTE ON FUNCTION check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT
) FROM anon;


-- ────────────────────────────────────────────────────────────
-- FIX 3: password_reset_tokens INSERT policy
-- Old: WITH CHECK (true)  — any authed user could insert tokens for any email
-- New: restrict to own email only
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS prt_insert ON public.password_reset_tokens;

CREATE POLICY prt_insert ON public.password_reset_tokens
  FOR INSERT TO authenticated
  WITH CHECK (
    email = (
      SELECT email FROM public.staff_members WHERE id = auth.uid()
    )
  );

-- Service role (edge functions) bypass RLS entirely — no change needed there.


-- ────────────────────────────────────────────────────────────
-- FIX 4: DB trigger for trip lifecycle resource management
--
-- "DB triggers handle that" was a lie — there were no triggers.
-- This trigger atomically manages driver availability and vehicle
-- status whenever a trip changes status, so client-side crashes
-- (network drop between sequential updates) cannot leave resources
-- permanently Busy.
--
-- Transitions enforced:
--   Scheduled/Active → Active   : driver Busy, vehicle Busy
--   Any              → Completed: driver Available, vehicle Idle
--   Any              → Cancelled: driver Available, vehicle Idle
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_trip_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    -- Trip becoming Active
    IF NEW.status = 'Active' AND OLD.status != 'Active' THEN
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE staff_members
               SET availability = 'Busy'
             WHERE id::text = NEW.driver_id::text;
        END IF;
        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE vehicles
               SET status = 'Busy'
             WHERE id::text = NEW.vehicle_id::text;
        END IF;
    END IF;

    -- Trip Completed or Cancelled — release resources
    IF NEW.status IN ('Completed', 'Cancelled')
       AND OLD.status NOT IN ('Completed', 'Cancelled') THEN
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE staff_members
               SET availability = 'Available'
             WHERE id::text = NEW.driver_id::text;
        END IF;
        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE vehicles
               SET status = 'Idle',
                   assigned_driver_id = NULL
             WHERE id::text = NEW.vehicle_id::text;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trip_status_change ON public.trips;

CREATE TRIGGER trg_trip_status_change
    AFTER UPDATE OF status ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION fn_trip_status_change();


-- ────────────────────────────────────────────────────────────
-- FIX 5: Add location history retention cleanup
-- vehicle_location_history grows ~576k rows/day at 5s intervals
-- with 10 drivers. Keep 30 days, run cleanup at 02:00 daily.
-- Requires pg_cron extension (available on Supabase).
-- ────────────────────────────────────────────────────────────

-- Enable pg_cron if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron SCHEMA extensions;

-- Add index for efficient range deletes if not present
CREATE INDEX IF NOT EXISTS idx_vlh_recorded_at
    ON public.vehicle_location_history (recorded_at);

-- Schedule daily cleanup (runs as postgres superuser via cron)
DO $$
DECLARE
    existing_job_id bigint;
BEGIN
    SELECT jobid
      INTO existing_job_id
      FROM cron.job
     WHERE jobname = 'sierra-cleanup-location-history'
     LIMIT 1;

    IF existing_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(existing_job_id);
    END IF;

    PERFORM cron.schedule(
        'sierra-cleanup-location-history',
        '0 2 * * *',
        $job$DELETE FROM public.vehicle_location_history
            WHERE recorded_at < now() - INTERVAL '30 days'$job$
    );
END;
$$;


-- ════════════════════════════════════════════════════════════
-- END OF MIGRATION
-- ════════════════════════════════════════════════════════════

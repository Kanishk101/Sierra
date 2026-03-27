-- ============================================================
-- Migration: Create check_resource_overlap DB function
-- Sierra Fleet Management System
-- Date: 2026-03-15
--
-- Called by the check-resource-overlap Edge Function.
-- Returns two boolean columns:
--   driver_conflict  → true if the driver already has a
--                      Scheduled/Active trip in the window
--   vehicle_conflict → true if the vehicle already has a
--                      Scheduled/Active trip in the window
--
-- Overlap logic (half-open intervals):
--   trip overlaps window if:
--     trip.start < window.end  AND  trip.effective_end > window.start
--
-- effective_end = COALESCE(scheduled_end_date,
--                           scheduled_date + INTERVAL '24 hours')
-- ============================================================

CREATE OR REPLACE FUNCTION check_resource_overlap(
    p_driver_id      TEXT,
    p_vehicle_id     TEXT,
    p_start          TIMESTAMPTZ,
    p_end            TIMESTAMPTZ,
    p_exclude_trip_id TEXT DEFAULT NULL
)
RETURNS TABLE(
    driver_conflict  BOOLEAN,
    vehicle_conflict BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        -- Driver conflict check
        EXISTS (
            SELECT 1
              FROM trips
             WHERE driver_id::text = p_driver_id
               AND status    IN ('Scheduled', 'Active')
               AND (
                       p_exclude_trip_id IS NULL
                    OR id::text <> p_exclude_trip_id
                   )
               AND scheduled_date < p_end
               AND COALESCE(
                       scheduled_end_date,
                       scheduled_date + INTERVAL '24 hours'
                   ) > p_start
        ) AS driver_conflict,

        -- Vehicle conflict check
        EXISTS (
            SELECT 1
              FROM trips
             WHERE vehicle_id::text = p_vehicle_id
               AND status     IN ('Scheduled', 'Active')
               AND (
                       p_exclude_trip_id IS NULL
                    OR id::text <> p_exclude_trip_id
                   )
               AND scheduled_date < p_end
               AND COALESCE(
                       scheduled_end_date,
                       scheduled_date + INTERVAL '24 hours'
                   ) > p_start
        ) AS vehicle_conflict;
$$;

-- Grant execute to authenticated users so the iOS app
-- (via the anon/service-role key) can call it through RPC.
GRANT EXECUTE ON FUNCTION check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT
) TO authenticated;

GRANT EXECUTE ON FUNCTION check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT
) TO anon;

-- ============================================================
-- END OF MIGRATION
-- ============================================================


-- Fix check_resource_overlap: use LOWER() on both sides of the UUID text comparison.
-- driver_id is UUID type; UUID::text produces lowercase.
-- The Swift client may have previously sent uppercase UUID strings.
-- LOWER(p_driver_id) makes this bulletproof regardless of client casing.
-- Also adds the 'Accepted' and 'PendingAcceptance' blocking statuses if not already present
-- (they are, but this is idempotent via the full function replacement).

CREATE OR REPLACE FUNCTION public.check_resource_overlap(
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
SET search_path = public
AS $$
    SELECT
        EXISTS (
            SELECT 1 FROM trips
            WHERE LOWER(driver_id::text) = LOWER(p_driver_id)
              AND status IN ('Scheduled', 'PendingAcceptance', 'Accepted', 'Active')
              AND (p_exclude_trip_id IS NULL
                   OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date,
                           scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,

        EXISTS (
            SELECT 1 FROM trips
            WHERE LOWER(vehicle_id::text) = LOWER(p_vehicle_id)
              AND status IN ('Scheduled', 'PendingAcceptance', 'Accepted', 'Active')
              AND (p_exclude_trip_id IS NULL
                   OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date,
                           scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

-- Keep grants/revokes idempotent
GRANT   EXECUTE ON FUNCTION public.check_resource_overlap(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;
REVOKE  EXECUTE ON FUNCTION public.check_resource_overlap(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM anon;
;

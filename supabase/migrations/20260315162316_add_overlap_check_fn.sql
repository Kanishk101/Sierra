
CREATE OR REPLACE FUNCTION check_resource_overlap(
    p_driver_id       UUID,
    p_vehicle_id      UUID,
    p_start           TIMESTAMPTZ,
    p_end             TIMESTAMPTZ,
    p_exclude_trip_id UUID DEFAULT NULL
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
        -- Driver conflict: does this driver already have a Scheduled/Active trip overlapping the window?
        EXISTS (
            SELECT 1
              FROM trips
             WHERE driver_id = p_driver_id
               AND status    IN ('Scheduled', 'Active')
               AND (p_exclude_trip_id IS NULL OR id <> p_exclude_trip_id)
               AND scheduled_date < p_end
               AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,

        -- Vehicle conflict: does this vehicle already have a Scheduled/Active trip overlapping the window?
        EXISTS (
            SELECT 1
              FROM trips
             WHERE vehicle_id = p_vehicle_id
               AND status     IN ('Scheduled', 'Active')
               AND (p_exclude_trip_id IS NULL OR id <> p_exclude_trip_id)
               AND scheduled_date < p_end
               AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

-- Grant execute to authenticated and anon roles
GRANT EXECUTE ON FUNCTION check_resource_overlap(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID)
    TO authenticated;

GRANT EXECUTE ON FUNCTION check_resource_overlap(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID)
    TO anon;
;

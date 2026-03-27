
-- ============================================================
-- Fix 1: Drop the UUID overload of check_resource_overlap.
--        Both text + uuid overloads exist, which causes PostgREST
--        to return "function is not unique" (HTTP 500) every time
--        the edge function calls supabaseAdmin.rpc("check_resource_overlap").
--        The text overload is what the edge function passes (JSON strings),
--        so drop the uuid one.
-- ============================================================
DROP FUNCTION IF EXISTS public.check_resource_overlap(
    p_driver_id  uuid,
    p_vehicle_id uuid,
    p_start      timestamp with time zone,
    p_end        timestamp with time zone,
    p_exclude_trip_id uuid
);

-- ============================================================
-- Fix 2: Update the text overload to include ALL blocking trip
--        statuses. The original only had ('Scheduled', 'Active').
--        New acceptance lifecycle added: PendingAcceptance, Accepted.
--        A trip in PendingAcceptance/Accepted should also block
--        the driver and vehicle from being double-booked.
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_resource_overlap(
    p_driver_id       text,
    p_vehicle_id      text,
    p_start           timestamp with time zone,
    p_end             timestamp with time zone,
    p_exclude_trip_id text DEFAULT NULL::text
)
RETURNS TABLE(driver_conflict boolean, vehicle_conflict boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
    SELECT
        EXISTS (
            SELECT 1 FROM trips
            WHERE driver_id::text = p_driver_id
              AND status IN ('Scheduled', 'PendingAcceptance', 'Accepted', 'Active')
              AND (p_exclude_trip_id IS NULL OR id::text <> p_exclude_trip_id)
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,
        EXISTS (
            SELECT 1 FROM trips
            WHERE vehicle_id::text = p_vehicle_id
              AND status IN ('Scheduled', 'PendingAcceptance', 'Accepted', 'Active')
              AND (p_exclude_trip_id IS NULL OR id::text <> p_exclude_trip_id)
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

-- Grant execute to authenticated and service_role
GRANT EXECUTE ON FUNCTION public.check_resource_overlap(text, text, timestamptz, timestamptz, text)
    TO authenticated, service_role;
;

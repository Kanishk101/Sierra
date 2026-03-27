-- ============================================================
-- Fix 1: check_resource_overlap with SET search_path + UUID cast
-- driver_id/vehicle_id are UUID in this DB (not TEXT), so cast
-- the text parameters before comparing.
-- ============================================================
CREATE OR REPLACE FUNCTION check_resource_overlap(
    p_driver_id       TEXT,
    p_vehicle_id      TEXT,
    p_start           TIMESTAMPTZ,
    p_end             TIMESTAMPTZ,
    p_exclude_trip_id TEXT DEFAULT NULL
)
RETURNS TABLE(driver_conflict BOOLEAN, vehicle_conflict BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        EXISTS (
            SELECT 1 FROM trips
            WHERE driver_id::text = p_driver_id
              AND status IN ('Scheduled', 'Active')
              AND (p_exclude_trip_id IS NULL OR id::text <> p_exclude_trip_id)
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,
        EXISTS (
            SELECT 1 FROM trips
            WHERE vehicle_id::text = p_vehicle_id
              AND status IN ('Scheduled', 'Active')
              AND (p_exclude_trip_id IS NULL OR id::text <> p_exclude_trip_id)
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

GRANT EXECUTE ON FUNCTION check_resource_overlap(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION check_resource_overlap(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM anon;


-- ============================================================
-- Fix 2: Allow anon SELECT on staff_members for password reset.
-- requestPasswordReset() runs before login (anon session) and
-- queries staff_members by email to verify the account exists.
-- Without this policy, RLS returns zero rows → "no user found".
-- ============================================================
DROP POLICY IF EXISTS staff_members_select_anon_reset ON public.staff_members;

CREATE POLICY staff_members_select_anon_reset ON public.staff_members
    FOR SELECT TO anon
    USING (true);


-- ============================================================
-- Fix 3: Allow anon INSERT into password_reset_tokens.
-- The token insert also runs in anon context (pre-login).
-- WITH CHECK ensures the email exists in staff_members first
-- so random emails cannot be flooded with tokens.
-- ============================================================
DROP POLICY IF EXISTS prt_insert_anon ON public.password_reset_tokens;

CREATE POLICY prt_insert_anon ON public.password_reset_tokens
    FOR INSERT TO anon
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE email = password_reset_tokens.email
        )
    );
;

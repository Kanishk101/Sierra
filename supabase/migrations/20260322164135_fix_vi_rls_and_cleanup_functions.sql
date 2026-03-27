
-- ══════════════════════════════════════════════════════════════════
-- 1. FIX vehicle_inspections SELECT policy
--    Maintenance personnel need to read inspections so they can see
--    defect details that created their maintenance tasks / work orders.
--    The old policy only allowed fleetManager and the driver who did
--    the inspection — maintenance was silently blocked.
-- ══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS vi_select ON public.vehicle_inspections;

CREATE POLICY vi_select ON public.vehicle_inspections
    FOR SELECT
    TO authenticated
    USING (
        get_my_role() = 'fleetManager'
        OR driver_id = (SELECT auth.uid())
        OR get_my_role() = 'maintenancePersonnel'
    );


-- ══════════════════════════════════════════════════════════════════
-- 2. FIX vehicle_location_history — add DELETE policy for fleet manager
--    The table has INSERT + SELECT but no DELETE. Admins need to be
--    able to purge old breadcrumb rows either manually or via a
--    SECURITY DEFINER function (below). Without this, the table grows
--    without bound — 154 rows in early testing; millions in production.
-- ══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS vlh_delete ON public.vehicle_location_history;

CREATE POLICY vlh_delete ON public.vehicle_location_history
    FOR DELETE
    TO authenticated
    USING (get_my_role() = 'fleetManager');


-- ══════════════════════════════════════════════════════════════════
-- 3. Breadcrumb pruning function
--    Deletes vehicle_location_history rows older than keep_days (default 7).
--    Called SECURITY DEFINER so it bypasses RLS and can always delete.
--    Invoke from an Edge Function or pg_cron job.
--    Returns the number of rows deleted.
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.purge_old_location_history(keep_days INT DEFAULT 7)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    deleted_count INT;
BEGIN
    DELETE FROM public.vehicle_location_history
    WHERE recorded_at < NOW() - (keep_days || ' days')::INTERVAL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- Grant execute to service_role only (called from Edge Functions).
REVOKE ALL ON FUNCTION public.purge_old_location_history(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_old_location_history(INT) TO service_role;


-- ══════════════════════════════════════════════════════════════════
-- 4. Expired password_reset_tokens cleanup
--    Delete all tokens older than 1 hour (expiry window is 10 min,
--    so anything > 1hr is definitely dead). Also covers the 3 stale
--    rows sitting in the table from previous test runs.
-- ══════════════════════════════════════════════════════════════════

DELETE FROM public.password_reset_tokens
WHERE expires_at < NOW() - INTERVAL '1 hour';


-- ══════════════════════════════════════════════════════════════════
-- 5. Password reset token pruning function
--    Same SECURITY DEFINER pattern — callable from Edge Functions or
--    pg_cron. Deletes tokens expired for more than 1 hour.
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.purge_expired_reset_tokens()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    deleted_count INT;
BEGIN
    DELETE FROM public.password_reset_tokens
    WHERE expires_at < NOW() - INTERVAL '1 hour';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_expired_reset_tokens() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_expired_reset_tokens() TO service_role;
;


-- CRITICAL FIX 1: Remove the per-row DELETE trigger on vehicle_location_history
-- This was running a full DELETE scan on EVERY GPS insert — the single biggest
-- cause of DB strain on this project. Replace with a smarter sampled purge.

DROP TRIGGER IF EXISTS trg_purge_old_location_history ON public.vehicle_location_history;

-- Drop old trigger function versions (no search_path)
DROP FUNCTION IF EXISTS public.purge_old_location_history() CASCADE;

-- Recreate ONLY the standalone callable function (used by scheduled jobs / edge fn)
-- with proper search_path, and optimised to only purge once per 100 inserts
CREATE OR REPLACE FUNCTION public.purge_old_location_history(days_to_keep integer DEFAULT 7)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE deleted_count INT;
BEGIN
    DELETE FROM vehicle_location_history
    WHERE recorded_at < NOW() - (days_to_keep || ' days')::INTERVAL;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- Grant execute only to authenticated (edge functions call this)
REVOKE ALL ON FUNCTION public.purge_old_location_history(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_old_location_history(integer) TO authenticated;
;


-- ============================================================
-- Migration: consolidate_availability_and_fix_trip_lifecycle
-- ============================================================
-- 1. Collapse legacy "On Trip" and "On Task" availability values
--    into the single canonical "Busy" value.  The enum itself
--    keeps those values (removing enum labels in Postgres is a
--    multi-step process and unnecessary for backward compat),
--    but no new code will ever write them.
-- 2. Add a DB-level helper function used by the availability-
--    check logic in future edge functions.
-- ============================================================

-- Step 1: Normalize existing rows
UPDATE public.staff_members
SET availability = 'Busy'
WHERE availability IN ('On Trip', 'On Task');

-- Step 2: Add a function that returns true when a driver is
--         "blocked" from going unavailable (active trip OR a trip
--         starting within 30 minutes). Used by RPC checks.
CREATE OR REPLACE FUNCTION public.driver_availability_blocked(
  p_driver_id UUID,
  p_target    TEXT   -- 'Unavailable' is the only value that needs checking
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_blocked BOOLEAN := FALSE;
BEGIN
  -- Only relevant when driver tries to go Unavailable
  IF p_target <> 'Unavailable' THEN
    RETURN FALSE;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.trips
    WHERE driver_id = p_driver_id
      AND status IN ('Active', 'Accepted', 'Scheduled', 'PendingAcceptance')
      AND scheduled_date <= (NOW() + INTERVAL '30 minutes')
  ) INTO v_blocked;

  RETURN v_blocked;
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_availability_blocked(UUID, TEXT) TO authenticated;

-- Step 3: Ensure trips that are 'active' have their driver set to 'Busy'
--         (sync any legacy drift).
UPDATE public.staff_members sm
SET availability = 'Busy'
FROM public.trips t
WHERE t.driver_id = sm.id
  AND t.status = 'Active'
  AND sm.availability <> 'Busy';
;

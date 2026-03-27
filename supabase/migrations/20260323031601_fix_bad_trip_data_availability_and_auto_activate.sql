
-- ─── 1. Fix the April-17 trip (Active but should be Scheduled) ─
UPDATE public.trips
SET   status = 'Scheduled',
      actual_start_date = NULL,
      updated_at = NOW()
WHERE id = 'df0fffcb-20bf-44c2-a3c6-50e5c1d53469'
  AND status = 'Active';

-- ─── 2. Cancel the March-22 stale trip ────────────────────────
UPDATE public.trips
SET   status = 'Cancelled',
      updated_at = NOW()
WHERE id = 'e71ad8a4-ba69-4230-b46b-581cc90d82c4'
  AND status = 'Scheduled'
  AND scheduled_date < NOW();

-- ─── 3. Fix stuck-Busy drivers (no active trip) ───────────────
UPDATE public.staff_members sm
SET   availability = 'Available',
      updated_at   = NOW()
WHERE sm.availability = 'Busy'
  AND sm.role = 'driver'
  AND sm.status = 'Active'
  AND NOT EXISTS (
    SELECT 1 FROM public.trips t
    WHERE t.driver_id = sm.id AND t.status = 'Active'
  );

-- ─── 4. auto_activate_trips() function ───────────────────────
CREATE OR REPLACE FUNCTION public.auto_activate_trips()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count1 INTEGER;
  v_count2 INTEGER;
BEGIN
  -- Activate Accepted trips whose scheduled_date has passed
  UPDATE public.trips
  SET   status = 'Active',
        actual_start_date = COALESCE(actual_start_date, NOW()),
        updated_at = NOW()
  WHERE status = 'Accepted'
    AND scheduled_date <= NOW();
  GET DIAGNOSTICS v_count1 = ROW_COUNT;

  -- Activate Scheduled trips whose scheduled_date passed AND have a pre-inspection
  UPDATE public.trips
  SET   status = 'Active',
        actual_start_date = COALESCE(actual_start_date, NOW()),
        updated_at = NOW()
  WHERE status = 'Scheduled'
    AND scheduled_date <= NOW()
    AND pre_inspection_id IS NOT NULL;
  GET DIAGNOSTICS v_count2 = ROW_COUNT;

  RETURN v_count1 + v_count2;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_activate_trips() TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_activate_trips() TO service_role;

-- ─── 5. cancel_stale_trips() function ────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_stale_trips()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE public.trips
  SET   status = 'Cancelled',
        updated_at = NOW()
  WHERE status IN ('Scheduled', 'PendingAcceptance')
    AND scheduled_date < (NOW() - INTERVAL '24 hours')
    AND pre_inspection_id IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_stale_trips() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_stale_trips() TO service_role;
;

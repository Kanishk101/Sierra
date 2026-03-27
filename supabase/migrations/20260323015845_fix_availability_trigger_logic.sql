
-- ============================================================
-- Migration: fix_availability_trigger_logic
-- ============================================================
-- BUG 1: can_driver_become_unavailable blocked going Unavailable
--   whenever ANY PendingAcceptance/Accepted trip existed, even weeks away.
--   Fix: Only 'Active' trips block unconditionally. 
--   Scheduled/Accepted/PendingAcceptance only block within 30-min window.
--
-- BUG 2: trg_fn_sync_driver_availability_from_trip set driver to Busy
--   when trip became 'Accepted'. Accepted = trip confirmed, not started.
--   Fix: Only set Busy when status becomes 'Active'.
-- ============================================================

-- Fix 1: can_driver_become_unavailable
CREATE OR REPLACE FUNCTION public.can_driver_become_unavailable(p_driver_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_active_count   INTEGER;
  v_upcoming_count INTEGER;
BEGIN
  -- Block if the driver is actively ON a trip right now
  SELECT COUNT(*) INTO v_active_count
  FROM trips
  WHERE driver_id = p_driver_id
    AND status = 'Active';

  IF v_active_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', FALSE,
      'reason',  'You are currently on an active trip'
    );
  END IF;

  -- Block if any trip (in any pre-active state) starts within 30 minutes
  SELECT COUNT(*) INTO v_upcoming_count
  FROM trips
  WHERE driver_id = p_driver_id
    AND status IN ('Scheduled', 'Accepted', 'PendingAcceptance')
    AND scheduled_date BETWEEN NOW() AND (NOW() + INTERVAL '30 minutes');

  IF v_upcoming_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', FALSE,
      'reason',  'A trip starts within 30 minutes — you cannot go unavailable now'
    );
  END IF;

  RETURN jsonb_build_object('allowed', TRUE, 'reason', NULL);
END;
$$;

-- Fix 2: trg_fn_sync_driver_availability_from_trip
-- Remove 'Accepted' from the Busy-setting arm.
-- The handle_trip_started trigger already handles Active → Busy correctly.
-- Accepted = driver confirmed intent; they are NOT yet busy/on-trip.
CREATE OR REPLACE FUNCTION public.trg_fn_sync_driver_availability_from_trip()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Trip became Active → mark driver Busy (only Active, not Accepted)
  IF NEW.driver_id IS NOT NULL
     AND NEW.status = 'Active'
     AND (OLD.status IS NULL OR OLD.status != 'Active')
  THEN
    UPDATE staff_members
    SET availability = 'Busy',
        updated_at   = NOW()
    WHERE id           = NEW.driver_id
      AND availability != 'Busy';
  END IF;

  -- Trip ended (Completed / Cancelled / Rejected) → return driver to Available
  -- only if no other trip is currently Active
  IF NEW.driver_id IS NOT NULL
     AND NEW.status IN ('Completed', 'Cancelled', 'Rejected')
     AND OLD.status IN ('Active', 'Accepted', 'PendingAcceptance', 'Scheduled')
  THEN
    IF NOT EXISTS (
      SELECT 1 FROM trips
      WHERE driver_id = NEW.driver_id
        AND id        != NEW.id
        AND status    = 'Active'
    ) THEN
      UPDATE staff_members
      SET availability = 'Available',
          updated_at   = NOW()
      WHERE id           = NEW.driver_id
        AND availability = 'Busy';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Also fix the enforce trigger's enforce function to use the corrected helper
-- (no changes needed — it already calls can_driver_become_unavailable which is now fixed)

-- Verify the enforce trigger exists and still fires
-- (it references trg_fn_enforce_availability which calls can_driver_become_unavailable)
-- No trigger DDL change needed.
;

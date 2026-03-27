
-- ============================================================
-- MIGRATION: trip_notification_scheduling
-- Date: 2026-03-23
-- Fixes:
--   1. Add scheduled_for + delivery_status to notifications
--      so we can queue future-dated notifications.
--   2. Trigger on trips INSERT: auto-queue accept reminder
--      (scheduled_date - 1 hour) and pre-inspection prompt
--      (scheduled_date - 30 minutes).
--   3. process_scheduled_notifications() — callable by iOS
--      background fetch or a cron edge function to deliver
--      notifications whose scheduled_for has passed.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1.  Extend notifications table
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS is_delivered  BOOLEAN     NOT NULL DEFAULT TRUE;

-- Mark existing rows as already delivered (they were sent immediately)
UPDATE public.notifications
SET is_delivered = TRUE
WHERE is_delivered IS FALSE OR is_delivered IS NULL;

-- Index for the scheduler query
CREATE INDEX IF NOT EXISTS idx_notifications_scheduled
  ON public.notifications (scheduled_for, is_delivered)
  WHERE scheduled_for IS NOT NULL AND is_delivered = FALSE;

-- ─────────────────────────────────────────────────────────────
-- 2.  notification_type enum: add pre_inspection_reminder
--     and trip_acceptance_reminder if they don't exist yet
-- ─────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'notification_type')
      AND enumlabel = 'Pre-Inspection Reminder'
  ) THEN
    ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Pre-Inspection Reminder';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'notification_type')
      AND enumlabel = 'Trip Acceptance Reminder'
  ) THEN
    ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Trip Acceptance Reminder';
  END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3.  Trigger: queue scheduled notifications on trip INSERT
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_fn_queue_trip_notifications()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_accept_at     TIMESTAMPTZ;
  v_inspect_at    TIMESTAMPTZ;
  v_driver_name   TEXT;
BEGIN
  -- Only for newly-created trips with a driver assigned
  IF NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Timing:
  --   Accept reminder  = scheduled_date - 1 hour
  --   Pre-inspection   = scheduled_date - 30 minutes
  v_accept_at  := NEW.scheduled_date - INTERVAL '1 hour';
  v_inspect_at := NEW.scheduled_date - INTERVAL '30 minutes';

  SELECT COALESCE(name, email) INTO v_driver_name
  FROM staff_members WHERE id = NEW.driver_id;

  -- Queue acceptance reminder (only if in the future)
  IF v_accept_at > NOW() THEN
    INSERT INTO notifications (
      recipient_id,
      type,
      title,
      body,
      entity_type,
      entity_id,
      is_read,
      scheduled_for,
      is_delivered,
      sent_at
    ) VALUES (
      NEW.driver_id,
      'Trip Acceptance Reminder',
      'Trip requires your acceptance',
      'Trip ' || NEW.task_id || ' from ' || NEW.origin || ' to ' || NEW.destination
        || ' starts in 1 hour. Please accept or it may be reassigned.',
      'trip',
      NEW.id,
      FALSE,
      v_accept_at,
      FALSE,
      NOW()
    );
  END IF;

  -- Queue pre-inspection reminder (only if in the future)
  IF v_inspect_at > NOW() THEN
    INSERT INTO notifications (
      recipient_id,
      type,
      title,
      body,
      entity_type,
      entity_id,
      is_read,
      scheduled_for,
      is_delivered,
      sent_at
    ) VALUES (
      NEW.driver_id,
      'Pre-Inspection Reminder',
      'Pre-trip inspection due',
      'Your trip ' || NEW.task_id || ' starts in 30 minutes. Complete the pre-trip inspection now.',
      'trip',
      NEW.id,
      FALSE,
      v_inspect_at,
      FALSE,
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_queue_trip_notifications ON trips;
CREATE TRIGGER trg_queue_trip_notifications
  AFTER INSERT ON trips
  FOR EACH ROW
  EXECUTE FUNCTION trg_fn_queue_trip_notifications();

-- Also re-queue when driver is assigned AFTER trip creation (UPDATE)
CREATE OR REPLACE FUNCTION public.trg_fn_requeue_trip_notifications_on_driver_assign()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_accept_at  TIMESTAMPTZ;
  v_inspect_at TIMESTAMPTZ;
BEGIN
  -- Only when driver_id changes from NULL to a value
  IF OLD.driver_id IS NOT NULL OR NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_accept_at  := NEW.scheduled_date - INTERVAL '1 hour';
  v_inspect_at := NEW.scheduled_date - INTERVAL '30 minutes';

  IF v_accept_at > NOW() THEN
    INSERT INTO notifications (
      recipient_id, type, title, body, entity_type, entity_id,
      is_read, scheduled_for, is_delivered, sent_at
    ) VALUES (
      NEW.driver_id, 'Trip Acceptance Reminder',
      'Trip requires your acceptance',
      'Trip ' || NEW.task_id || ' from ' || NEW.origin || ' to ' || NEW.destination
        || ' starts in 1 hour. Please accept or it may be reassigned.',
      'trip', NEW.id, FALSE, v_accept_at, FALSE, NOW()
    );
  END IF;

  IF v_inspect_at > NOW() THEN
    INSERT INTO notifications (
      recipient_id, type, title, body, entity_type, entity_id,
      is_read, scheduled_for, is_delivered, sent_at
    ) VALUES (
      NEW.driver_id, 'Pre-Inspection Reminder',
      'Pre-trip inspection due',
      'Your trip ' || NEW.task_id || ' starts in 30 minutes. Complete the pre-trip inspection now.',
      'trip', NEW.id, FALSE, v_inspect_at, FALSE, NOW()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_requeue_trip_notifications_on_driver_assign ON trips;
CREATE TRIGGER trg_requeue_trip_notifications_on_driver_assign
  AFTER UPDATE OF driver_id ON trips
  FOR EACH ROW
  EXECUTE FUNCTION trg_fn_requeue_trip_notifications_on_driver_assign();

-- ─────────────────────────────────────────────────────────────
-- 4.  process_scheduled_notifications()
--     Call this from a cron edge function every minute to
--     mark due notifications as delivered (making them visible
--     in the app's notification feed).
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_scheduled_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE notifications
  SET is_delivered = TRUE
  WHERE scheduled_for <= NOW()
    AND is_delivered   = FALSE;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_scheduled_notifications() TO service_role;

-- ─────────────────────────────────────────────────────────────
-- 5.  RLS: notifications should only be visible when delivered
--     (or unscheduled). Update the select policy.
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS notifications_select ON public.notifications;
CREATE POLICY notifications_select ON public.notifications
  FOR SELECT TO authenticated
  USING (
    recipient_id = (SELECT auth.uid())
    AND (scheduled_for IS NULL OR is_delivered = TRUE)
  );
;

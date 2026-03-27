
-- ============================================================
-- Migration: fix_notification_rls_and_push_delivery
-- ============================================================
-- BUG 3: Duplicate + conflicting RLS policies on notifications.
--   - notifications_insert  = duplicate of notif_insert (both allow all authenticated)
--   - notifications_select  = had delivery gate (scheduled_for IS NULL OR is_delivered=true)
--                             but was bypassed by the PERMISSIVE notif_select
-- Fix: Drop duplicates. Keep notif_* policies which are correct and clean.
-- The delivery gate on SELECT is intentional — notifications with scheduled_for 
-- that haven't been delivered yet should not appear in the driver's inbox until delivered.
-- So we recreate notifications_select as a proper replacement of notif_select that 
-- includes the delivery gate.
-- ============================================================

-- Step 1: Drop all 4 conflicting policies, then recreate just 2 clean ones
DROP POLICY IF EXISTS "notifications_insert"   ON public.notifications;
DROP POLICY IF EXISTS "notifications_select"   ON public.notifications;
DROP POLICY IF EXISTS "notif_insert"           ON public.notifications;
DROP POLICY IF EXISTS "notif_select"           ON public.notifications;
DROP POLICY IF EXISTS "notif_update"           ON public.notifications;
DROP POLICY IF EXISTS "notif_delete"           ON public.notifications;

-- Step 2: Recreate clean, correct policies
CREATE POLICY "notifications_select" ON public.notifications
  FOR SELECT TO authenticated
  USING (
    recipient_id = (SELECT auth.uid())
    AND (scheduled_for IS NULL OR is_delivered = TRUE)
  );

CREATE POLICY "notifications_insert" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

CREATE POLICY "notifications_update" ON public.notifications
  FOR UPDATE TO authenticated
  USING (recipient_id = (SELECT auth.uid()));

CREATE POLICY "notifications_delete" ON public.notifications
  FOR DELETE TO authenticated
  USING (recipient_id = (SELECT auth.uid()));

-- ============================================================
-- BUG 4: fn_send_push_on_notification_insert fires for ALL
-- inserts including scheduled (is_delivered=false) ones.
-- This means the T-30min pre-inspection push fires at trip
-- creation, not 30 minutes before the trip.
--
-- Fix: Skip push for scheduled notifications (is_delivered=false).
-- They'll get their push via the UPDATE trigger below when
-- deliver_scheduled_notifications() marks them delivered.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Skip scheduled (future-delivery) notifications — they will be pushed
  -- by the UPDATE trigger when is_delivered flips to TRUE.
  IF NEW.scheduled_for IS NOT NULL AND NEW.is_delivered = FALSE THEN
    RETURN NEW;
  END IF;

  PERFORM extensions.http_post(
    url     := current_setting('app.supabase_url', true) || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body    := jsonb_build_object(
      'recipientId', NEW.recipient_id::text,
      'title',       NEW.title,
      'body',        NEW.body,
      'data',        jsonb_build_object(
        'type',     NEW.type,
        'entityId', COALESCE(NEW.entity_id::text, '')
      )
    )
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

-- ============================================================
-- BUG 5: No mechanism to send push when scheduled notification
-- is marked as delivered.
--
-- Fix: Add UPDATE trigger that fires when is_delivered flips to
-- TRUE and sends the push at that point.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_delivered()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Only fire when is_delivered changes FALSE → TRUE
  IF OLD.is_delivered = FALSE AND NEW.is_delivered = TRUE THEN
    PERFORM extensions.http_post(
      url     := current_setting('app.supabase_url', true) || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
      ),
      body    := jsonb_build_object(
        'recipientId', NEW.recipient_id::text,
        'title',       NEW.title,
        'body',        NEW.body,
        'data',        jsonb_build_object(
          'type',     NEW.type,
          'entityId', COALESCE(NEW.entity_id::text, '')
        )
      )
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_on_notification_delivered ON public.notifications;
CREATE TRIGGER trg_push_on_notification_delivered
  AFTER UPDATE OF is_delivered ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_send_push_on_notification_delivered();

-- ============================================================
-- BUG 5 (continued): Create deliver_scheduled_notifications()
-- This function is called by the deliver-due-notifications edge
-- function (invoked by the iOS app on load/foreground).
-- It marks all past-due undelivered notifications as delivered,
-- which triggers fn_send_push_on_notification_delivered for each.
-- ============================================================
CREATE OR REPLACE FUNCTION public.deliver_scheduled_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE notifications
  SET    is_delivered = TRUE,
         sent_at      = NOW()
  WHERE  is_delivered  = FALSE
    AND  scheduled_for IS NOT NULL
    AND  scheduled_for <= NOW();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deliver_scheduled_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.deliver_scheduled_notifications() TO service_role;
;

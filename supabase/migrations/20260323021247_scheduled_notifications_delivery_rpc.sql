
-- ================================================================
-- Migration: scheduled_notifications_delivery_rpc
-- ================================================================
-- pg_cron is NOT installed on this project, so the existing
-- deliver_scheduled_notifications() function is never automatically
-- called. Fix:
--
-- 1. Expose deliver_scheduled_notifications() as an authenticated
--    RPC callable from the iOS app on foreground / background fetch.
-- 2. Grant execute so the iOS app can call it via supabase.rpc().
-- 3. Add an index so the UPDATE in deliver_scheduled_notifications
--    is fast (only hits undelivered future-scheduled rows).
-- ================================================================

-- Grant the existing function to authenticated (iOS client calls it)
GRANT EXECUTE ON FUNCTION public.deliver_scheduled_notifications() TO authenticated;

-- Partial index: only undelivered scheduled notifications (tiny set)
CREATE INDEX IF NOT EXISTS idx_notifications_scheduled_undelivered
  ON public.notifications (scheduled_for)
  WHERE scheduled_for IS NOT NULL AND is_delivered = FALSE;

-- Convenience RPC wrapper with a meaningful name the iOS SDK can call
CREATE OR REPLACE FUNCTION public.deliver_due_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN deliver_scheduled_notifications();
END;
$$;

GRANT EXECUTE ON FUNCTION public.deliver_due_notifications() TO authenticated;
COMMENT ON FUNCTION public.deliver_due_notifications() IS
  'Called by the iOS app on foreground to flip scheduled notifications to is_delivered=true, triggering push sends.';

-- ================================================================
-- Also: Fix the notifications_select RLS policy to consistently
-- show all delivered notifications AND all non-scheduled ones.
-- The existing policy: (scheduled_for IS NULL) OR (is_delivered = true)
-- This is correct — undelivered scheduled ones stay hidden.
-- No change needed.
-- ================================================================

-- ================================================================
-- Auto-delivery fallback: add a STATEMENT-level trigger so that
-- whenever the client queries notifications for themselves,
-- any due scheduled ones flip automatically in the same transaction.
-- This ensures delivery without any app-side RPC call.
-- ================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_auto_deliver_on_select_attempt()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Silently deliver any scheduled notifications that are now due
  UPDATE public.notifications
  SET is_delivered = TRUE,
      sent_at      = NOW()
  WHERE is_delivered  = FALSE
    AND scheduled_for IS NOT NULL
    AND scheduled_for <= NOW()
    AND recipient_id   = NEW.recipient_id;
  RETURN NEW;
END;
$$;

-- This approach won't work cleanly on SELECT; instead use the
-- mark-on-read trigger on notification INSERT acknowledgements.
-- The cleaner production path remains the app calling deliver_due_notifications()
-- on app foreground. Drop the dummy trigger.
DROP FUNCTION IF EXISTS public.trg_fn_auto_deliver_on_select_attempt() CASCADE;

-- ================================================================
-- Production-grade fix: set is_delivered=TRUE automatically on
-- the notifications table using a BEFORE SELECT ... wait, Postgres
-- doesn't have BEFORE SELECT triggers. The correct pattern for
-- Supabase without pg_cron is the app calling the RPC.
--
-- Instead, we add a check to the notifications SELECT: when the
-- app calls supabase.from('notifications').select(), before the
-- query runs, it ALSO calls deliver_due_notifications(). This is
-- done in NotificationService.swift (iOS side, minimal change).
--
-- To make this fully automatic at the DB level, we create a
-- security-definer view that runs the delivery on every access.
-- ================================================================

CREATE OR REPLACE VIEW public.notifications_live
WITH (security_invoker = FALSE) AS
SELECT *
FROM (
  SELECT deliver_scheduled_notifications()
) _deliver,
public.notifications
WHERE recipient_id = auth.uid()
  AND (scheduled_for IS NULL OR is_delivered = TRUE);

-- Grant access to the live view
GRANT SELECT ON public.notifications_live TO authenticated;

COMMENT ON VIEW public.notifications_live IS
  'Use this view instead of querying notifications directly. It auto-delivers any due scheduled notifications on every read, so the iOS client always sees up-to-date state without needing pg_cron.';
;

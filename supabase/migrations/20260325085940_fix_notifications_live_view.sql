
-- ================================================================
-- FIX 3: Replace side-effectful notifications_live view
-- Must drop and recreate since column list changed
-- ================================================================
DROP VIEW IF EXISTS public.notifications_live;

CREATE VIEW public.notifications_live
  WITH (security_invoker = true)
AS
SELECT
  n.id,
  n.recipient_id,
  n.type,
  n.title,
  n.body,
  n.entity_type,
  n.entity_id,
  n.is_read,
  n.read_at,
  n.sent_at,
  n.created_at,
  n.scheduled_for,
  n.is_delivered
FROM public.notifications n
WHERE
  n.recipient_id = auth.uid()
  AND (
    n.scheduled_for IS NULL
    OR n.is_delivered = true
    OR (n.scheduled_for IS NOT NULL AND n.is_delivered = false AND n.scheduled_for <= now() + interval '2 hours')
  );
;


-- ─── 1. RLS: driver_profiles DELETE ─────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'driver_profiles' AND policyname = 'dp_delete'
  ) THEN
    EXECUTE 'CREATE POLICY dp_delete ON public.driver_profiles FOR DELETE TO authenticated USING (get_my_role() = ''fleetManager'')';
  END IF;
END;
$$;

-- ─── 2. RLS: maintenance_profiles DELETE ────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'maintenance_profiles' AND policyname = 'mp_delete'
  ) THEN
    EXECUTE 'CREATE POLICY mp_delete ON public.maintenance_profiles FOR DELETE TO authenticated USING (get_my_role() = ''fleetManager'')';
  END IF;
END;
$$;

-- ─── 3. Tighten notifications INSERT ────────────────────────
-- Fleet managers: any recipient
-- Drivers/maintenance: own recipient OR fleet managers (for SOS → admin path)
DROP POLICY IF EXISTS notifications_insert ON public.notifications;
CREATE POLICY notifications_insert ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (
    get_my_role() = 'fleetManager'
    OR recipient_id = ( SELECT auth.uid() )
    OR EXISTS (
      SELECT 1 FROM public.staff_members sm
      WHERE sm.id = notifications.recipient_id AND sm.role = 'fleetManager'
    )
  );

-- ─── 4. Fix notifications SELECT ─────────────────────────────
-- Show upcoming scheduled notifications within 2 hours so the in-app
-- bell can preview "pre-inspection in 25 min" before the push fires.
DROP POLICY IF EXISTS notifications_select ON public.notifications;
CREATE POLICY notifications_select ON public.notifications
  FOR SELECT TO authenticated
  USING (
    recipient_id = ( SELECT auth.uid() )
    AND (
      scheduled_for IS NULL
      OR is_delivered = TRUE
      OR (
        scheduled_for IS NOT NULL
        AND is_delivered = FALSE
        AND scheduled_for <= (NOW() + INTERVAL '2 hours')
      )
    )
  );

-- ─── 5. Update notifications_live view ───────────────────────
-- Existing view: delivers past-due notifications, shows is_delivered rows.
-- New view: also surfaces upcoming undelivered ones within 2 hours
-- so the in-app bell shows them. The deliver_scheduled_notifications()
-- call inside the view handles actual push delivery automatically.
CREATE OR REPLACE VIEW public.notifications_live
WITH (security_invoker = true)
AS
SELECT
  _deliver.deliver_scheduled_notifications,
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
FROM
  (SELECT deliver_scheduled_notifications() AS deliver_scheduled_notifications) _deliver,
  notifications n
WHERE
  n.recipient_id = auth.uid()
  AND (
    n.scheduled_for IS NULL
    OR n.is_delivered = TRUE
    OR (
      n.scheduled_for IS NOT NULL
      AND n.is_delivered = FALSE
      AND n.scheduled_for <= (NOW() + INTERVAL '2 hours')
    )
  );

-- Grant SELECT on the view to authenticated users
GRANT SELECT ON public.notifications_live TO authenticated;

-- ─── 6. Re-grant key functions ───────────────────────────────
GRANT EXECUTE ON FUNCTION public.deliver_scheduled_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.deliver_scheduled_notifications() TO service_role;
GRANT EXECUTE ON FUNCTION public.can_driver_become_unavailable(UUID)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_availability_blocked(UUID,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role()                          TO authenticated;
;


-- =============================================================================
-- Migration: fix_push_triggers_notification_types_and_scheduling
-- =============================================================================

-- =============================================================================
-- 1. Fix push notification INSERT trigger: extensions.http_post → net.http_post
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url      TEXT;
  v_svc_key  TEXT;
BEGIN
  -- Skip scheduled (future-delivery) notifications; they push on delivery flip.
  IF NEW.scheduled_for IS NOT NULL AND NEW.is_delivered = FALSE THEN
    RETURN NEW;
  END IF;

  v_url     := current_setting('app.supabase_url', TRUE);
  v_svc_key := current_setting('app.service_role_key', TRUE);

  -- Silently skip if app settings have not been configured.
  IF v_url IS NULL OR v_url = '' OR v_svc_key IS NULL OR v_svc_key = '' THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
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

-- =============================================================================
-- 2. Fix push notification UPDATE (delivery) trigger
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_delivered()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url      TEXT;
  v_svc_key  TEXT;
BEGIN
  IF OLD.is_delivered = TRUE OR NEW.is_delivered = FALSE THEN
    RETURN NEW;
  END IF;

  v_url     := current_setting('app.supabase_url', TRUE);
  v_svc_key := current_setting('app.service_role_key', TRUE);

  IF v_url IS NULL OR v_url = '' OR v_svc_key IS NULL OR v_svc_key = '' THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_svc_key
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

-- =============================================================================
-- 3. Fix maintenance task completion: wrong notification type 'General'
--    → correct to 'Maintenance Complete'
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_maintenance_task_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status IN ('Assigned', 'In Progress')
     AND OLD.status NOT IN ('Assigned', 'In Progress') THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles SET status = 'In Maintenance', updated_at = now()
      WHERE id = NEW.vehicle_id;
    END IF;

  ELSIF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles SET status = 'Idle', updated_at = now()
      WHERE id = NEW.vehicle_id;
    END IF;
    NEW.completed_at := COALESCE(NEW.completed_at, now());
    IF NEW.created_by_admin_id IS NOT NULL THEN
      INSERT INTO notifications (
        id, recipient_id, type, title, body,
        entity_type, entity_id, is_read, sent_at, created_at
      ) VALUES (
        gen_random_uuid(),
        NEW.created_by_admin_id,
        'Maintenance Complete',   -- FIX: was 'General'
        'Maintenance Completed',
        'Task "' || NEW.title || '" has been completed. Vehicle is now available.',
        'maintenance_task', NEW.id, false, now(), now()
      );
    END IF;

  ELSIF NEW.status = 'Cancelled'
        AND OLD.status NOT IN ('Cancelled', 'Completed') THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM maintenance_tasks
        WHERE vehicle_id = NEW.vehicle_id AND id != NEW.id
          AND status IN ('Assigned', 'In Progress')
      ) THEN
        UPDATE vehicles SET status = 'Idle', updated_at = now()
        WHERE id = NEW.vehicle_id AND status = 'In Maintenance';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- =============================================================================
-- 4. Grant deliver_scheduled_notifications to authenticated
--    (workaround for no pg_cron — iOS app calls this on each loadDriverData)
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.deliver_scheduled_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_scheduled_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.deliver_due_notifications() TO authenticated;

-- =============================================================================
-- 5. Expose can_driver_become_unavailable as callable RPC for iOS pre-flight
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.can_driver_become_unavailable(UUID) TO authenticated;

-- =============================================================================
-- 6. Expose approve_staff_application_atomic as callable RPC for fleet manager
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.approve_staff_application_atomic(UUID, UUID) TO authenticated;

-- =============================================================================
-- 7. Drop duplicate trip-assignment notification DB trigger.
--    AppDataStore.addTrip() is the canonical source for this notification.
--    The DB trigger created a duplicate with less context.
-- =============================================================================
DROP TRIGGER IF EXISTS trg_notify_driver_trip_assigned ON public.trips;

-- =============================================================================
-- 8. Performance indexes
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_notifications_deliver_due
  ON public.notifications (scheduled_for ASC)
  WHERE scheduled_for IS NOT NULL AND is_delivered = FALSE;

CREATE INDEX IF NOT EXISTS idx_trips_driver_scheduled_status
  ON public.trips (driver_id, scheduled_date, status)
  WHERE status IN ('Active', 'Accepted', 'Scheduled', 'PendingAcceptance')
    AND driver_id IS NOT NULL;
;

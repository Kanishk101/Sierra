
-- SECURITY FIX: Add SET search_path TO 'public' to all functions missing it

-- 1. set_updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  SET search_path TO 'public'
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 2. purge_expired_reset_tokens (trigger version)
CREATE OR REPLACE FUNCTION public.purge_expired_reset_tokens()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
BEGIN
    DELETE FROM password_reset_tokens
    WHERE email = NEW.email
      AND (expires_at < NOW() OR used = TRUE)
      AND id <> NEW.id;
    RETURN NEW;
END;
$$;

-- 3. purge_expired_password_reset_tokens (standalone callable)
CREATE OR REPLACE FUNCTION public.purge_expired_password_reset_tokens()
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE deleted_count INT;
BEGIN
    DELETE FROM password_reset_tokens
    WHERE expires_at < NOW() OR used = TRUE;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- 4. fn_send_push_on_notification_insert
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_insert()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_url     TEXT;
  v_svc_key TEXT;
BEGIN
  -- Skip scheduled (future-delivery) notifications; they push on delivery flip.
  IF NEW.scheduled_for IS NOT NULL AND NEW.is_delivered = FALSE THEN
    RETURN NEW;
  END IF;

  v_url     := get_app_secret('supabase_url');
  v_svc_key := get_app_secret('service_role_key');

  IF v_url = '' OR v_svc_key = '' THEN
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
        'type',     NEW.type::text,
        'entityId', COALESCE(NEW.entity_id::text, '')
      )
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

-- 5. fn_send_push_on_notification_delivered
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_delivered()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_url     TEXT;
  v_svc_key TEXT;
BEGIN
  IF OLD.is_delivered = TRUE OR NEW.is_delivered = FALSE THEN
    RETURN NEW;
  END IF;

  v_url     := get_app_secret('supabase_url');
  v_svc_key := get_app_secret('service_role_key');

  IF v_url = '' OR v_svc_key = '' THEN
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
        'type',     NEW.type::text,
        'entityId', COALESCE(NEW.entity_id::text, '')
      )
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

-- 6. deliver_due_notifications (wrapper — add search_path)
CREATE OR REPLACE FUNCTION public.deliver_due_notifications()
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
BEGIN
  RETURN deliver_scheduled_notifications();
END;
$$;

-- 7. handle_maintenance_task_status_change
CREATE OR REPLACE FUNCTION public.handle_maintenance_task_status_change()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
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
        'Maintenance Complete',
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

-- 8. driver_availability_blocked
CREATE OR REPLACE FUNCTION public.driver_availability_blocked(p_driver_id uuid, p_target text)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_blocked BOOLEAN := FALSE;
BEGIN
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

-- 9. trg_fn_enforce_fuel_log_trip_status
CREATE OR REPLACE FUNCTION public.trg_fn_enforce_fuel_log_trip_status()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_role        TEXT;
  v_trip_status TEXT;
BEGIN
  SELECT get_my_role() INTO v_role;

  IF v_role = 'fleetManager' THEN
    RETURN NEW;
  END IF;

  IF NEW.trip_id IS NULL THEN
    RAISE EXCEPTION 'Drivers must link a fuel log to an active trip.';
  END IF;

  SELECT status INTO v_trip_status
  FROM public.trips
  WHERE id = NEW.trip_id;

  IF v_trip_status IS NULL THEN
    RAISE EXCEPTION 'Referenced trip does not exist.';
  END IF;

  IF v_trip_status != 'Active' THEN
    RAISE EXCEPTION 'Fuel can only be logged for an active trip (current status: %).', v_trip_status;
  END IF;

  RETURN NEW;
END;
$$;
;

-- Phase 5: DB trigger to fire send-push-notification on each notification INSERT.
-- Requires pg_net extension for async HTTP calls from Postgres.

CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;

-- Ensure Realtime captures full row data for the notifications table
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Function: call send-push-notification edge function for every new notification
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
                'entityId', NEW.entity_id
            )
        )
    );
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Never let push notification failure roll back the notification INSERT
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;
CREATE TRIGGER trg_push_on_notification
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_send_push_on_notification_insert();

-- Geofence notification trigger (Phase 1 requirement that was deferred)
CREATE OR REPLACE FUNCTION public.fn_notify_on_geofence_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    admin_row RECORD;
    event_label TEXT;
BEGIN
    event_label := CASE WHEN NEW.event_type = 'entry' THEN 'entered' ELSE 'exited' END;

    FOR admin_row IN
        SELECT id FROM public.staff_members WHERE role = 'fleetManager'
    LOOP
        INSERT INTO public.notifications (
            recipient_id, type, title, body,
            entity_type, entity_id, is_read, sent_at, created_at
        ) VALUES (
            admin_row.id,
            'Geofence Alert',
            'Geofence Alert: Vehicle ' || event_label,
            'Vehicle ' || COALESCE(NEW.vehicle_id::text, 'unknown') ||
                ' ' || event_label || ' a geofence zone at ' || NOW()::text,
            'geofence_event',
            NEW.id,
            false,
            NOW(),
            NOW()
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_geofence_notification ON public.geofence_events;
CREATE TRIGGER trg_geofence_notification
    AFTER INSERT ON public.geofence_events
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_on_geofence_event();

-- Trip assignment notification trigger (server-side safety net)
-- The iOS app also calls NotificationService.insertNotification in addTrip,
-- but this trigger fires even if the admin creates a trip via another client.
CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.driver_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            recipient_id, type, title, body,
            entity_type, entity_id, is_read, sent_at, created_at
        ) VALUES (
            NEW.driver_id::uuid,
            'Trip Assigned',
            'New Trip Assigned: ' || COALESCE(NEW.task_id, NEW.id::text),
            'Trip from ' || NEW.origin || ' to ' || NEW.destination ||
                ' scheduled for ' || NEW.scheduled_date::text,
            'trip',
            NEW.id,
            false,
            NOW(),
            NOW()
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_driver_trip_assigned ON public.trips;
CREATE TRIGGER trg_notify_driver_trip_assigned
    AFTER INSERT ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_driver_trip_assigned();;

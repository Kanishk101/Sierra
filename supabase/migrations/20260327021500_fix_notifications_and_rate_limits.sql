-- Fix recipient_id UUID usage in notifications and repair edge_rate_limits schema/function.
-- Addresses runtime errors:
--   - column "recipient_id" is of type uuid but expression is of type text
--   - column "action" of relation "edge_rate_limits" does not exist

-- ========================================
-- 1) notifications policies (recipient_id is UUID)
-- ========================================
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;

CREATE POLICY notifications_select_own
ON public.notifications
FOR SELECT
TO authenticated
USING (recipient_id = auth.uid());

CREATE POLICY notifications_update_own
ON public.notifications
FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid())
WITH CHECK (recipient_id = auth.uid());

-- ========================================
-- 2) Trip notification trigger functions (use UUID, no text casts)
-- ========================================
CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_assigned()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_scheduled text;
BEGIN
  IF NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_scheduled := to_char(
    NEW.scheduled_date AT TIME ZONE 'UTC',
    'Mon DD, YYYY at HH24:MI UTC'
  );

  INSERT INTO public.notifications
    (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
  VALUES
    (
      gen_random_uuid(),
      NEW.driver_id,
      'Trip Assigned',
      'New Trip Assigned: ' || NEW.task_id,
      'You have been assigned a trip from '
        || NEW.origin || ' to ' || NEW.destination
        || ' scheduled for ' || v_scheduled,
      'trip',
      NEW.id,
      false,
      now()
    );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_reassigned()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_scheduled text;
BEGIN
  IF OLD.driver_id IS NOT NULL OR NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_scheduled := to_char(
    NEW.scheduled_date AT TIME ZONE 'UTC',
    'Mon DD, YYYY at HH24:MI UTC'
  );

  INSERT INTO public.notifications
    (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
  VALUES
    (
      gen_random_uuid(),
      NEW.driver_id,
      'Trip Assigned',
      'New Trip Assigned: ' || NEW.task_id,
      'You have been assigned a trip from '
        || NEW.origin || ' to ' || NEW.destination
        || ' scheduled for ' || v_scheduled,
      'trip',
      NEW.id,
      false,
      now()
    );

  RETURN NEW;
END;
$$;

-- ========================================
-- 3) edge_rate_limits: restore correct schema and function
-- ========================================
DROP TABLE IF EXISTS public.edge_rate_limits CASCADE;

CREATE TABLE public.edge_rate_limits (
  action        text        NOT NULL,
  identifier    text        NOT NULL,
  bucket_start  timestamptz NOT NULL,
  request_count integer     NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT edge_rate_limits_pk PRIMARY KEY (action, identifier, bucket_start)
);

CREATE INDEX idx_edge_rate_limits_updated_at
  ON public.edge_rate_limits (updated_at);

ALTER TABLE public.edge_rate_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS erl_service_role_all ON public.edge_rate_limits;
CREATE POLICY erl_service_role_all
  ON public.edge_rate_limits
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- Recreate RPC to match schema
DROP FUNCTION IF EXISTS public.enforce_edge_rate_limit(TEXT, TEXT, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.enforce_edge_rate_limit(
  p_action text,
  p_identifier text,
  p_window_seconds integer,
  p_max_requests integer
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_bucket_start timestamptz;
    v_count integer;
BEGIN
    IF p_action IS NULL OR p_action = '' THEN
        RAISE EXCEPTION 'p_action is required';
    END IF;
    IF p_identifier IS NULL OR p_identifier = '' THEN
        RAISE EXCEPTION 'p_identifier is required';
    END IF;
    IF p_window_seconds <= 0 THEN
        RAISE EXCEPTION 'p_window_seconds must be > 0';
    END IF;
    IF p_max_requests <= 0 THEN
        RAISE EXCEPTION 'p_max_requests must be > 0';
    END IF;

    v_bucket_start := to_timestamp(
        floor(extract(epoch FROM now()) / p_window_seconds) * p_window_seconds
    );

    INSERT INTO public.edge_rate_limits (action, identifier, bucket_start, request_count)
    VALUES (p_action, p_identifier, v_bucket_start, 1)
    ON CONFLICT (action, identifier, bucket_start)
    DO UPDATE SET
        request_count = public.edge_rate_limits.request_count + 1,
        updated_at = now()
    RETURNING request_count INTO v_count;

    RETURN v_count <= p_max_requests;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_edge_rate_limit(TEXT, TEXT, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enforce_edge_rate_limit(TEXT, TEXT, INTEGER, INTEGER) TO service_role;

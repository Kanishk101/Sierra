
-- FIX: Consolidate duplicate notification delivery functions

CREATE OR REPLACE FUNCTION public.deliver_scheduled_notifications()
  RETURNS integer
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

-- Keep process_scheduled_notifications as alias
CREATE OR REPLACE FUNCTION public.process_scheduled_notifications()
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
BEGIN
  RETURN deliver_scheduled_notifications();
END;
$$;

-- Add unique constraint on app_secrets.key to make seed idempotent
ALTER TABLE public.app_secrets
  ADD CONSTRAINT app_secrets_key_unique UNIQUE (key);

-- Lock down get_app_secret so anon cannot call it
REVOKE EXECUTE ON FUNCTION public.get_app_secret(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_app_secret(text) TO authenticated;
;

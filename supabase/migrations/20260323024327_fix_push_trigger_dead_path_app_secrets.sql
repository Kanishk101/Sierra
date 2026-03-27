
-- ================================================================
-- Migration: fix_push_trigger_dead_path_app_secrets
-- ================================================================
-- ROOT CAUSE: fn_send_push_on_notification_insert and
-- fn_send_push_on_notification_delivered both call
-- current_setting('app.supabase_url', TRUE) which returns NULL
-- because ALTER DATABASE requires superuser (not available via
-- Supabase migrations). Every push notification is silently skipped.
--
-- FIX: Create app_secrets table (RLS on, zero public policies →
-- no direct reads). Create SECURITY DEFINER get_app_secret()
-- accessor. Rewrite both trigger functions to use it.
-- Project URL is inserted here. Service role key must be inserted
-- manually by the project owner via SQL editor:
--   INSERT INTO public.app_secrets (key, value)
--   VALUES ('service_role_key', '<your_service_role_key>')
--   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
-- ================================================================

-- ─── 1. app_secrets table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_secrets (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

ALTER TABLE public.app_secrets ENABLE ROW LEVEL SECURITY;
-- Intentionally NO policies: no authenticated/anon user can read/write directly.
-- Only SECURITY DEFINER functions bypass this.

-- ─── 2. Seed the non-sensitive project URL ───────────────────────
INSERT INTO public.app_secrets (key, value)
VALUES ('supabase_url', 'https://ldqcdngdlbbiojlnbnjg.supabase.co')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- ─── 3. SECURITY DEFINER accessor ────────────────────────────────
-- Only callable by authenticated users, but the read bypasses RLS.
-- Returns empty string if key not found so callers can null-check.
CREATE OR REPLACE FUNCTION public.get_app_secret(p_key TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_val TEXT;
BEGIN
  SELECT value INTO v_val FROM public.app_secrets WHERE key = p_key;
  RETURN COALESCE(v_val, '');
END;
$$;

-- Restrict to internal callers only (trigger functions + service role)
REVOKE ALL ON FUNCTION public.get_app_secret(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_app_secret(TEXT) TO service_role;
-- Triggers run as the function owner (SECURITY DEFINER), not as a role,
-- so no GRANT TO authenticated is needed for trigger-internal calls.

-- ─── 4. Rewrite fn_send_push_on_notification_insert ─────────────
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url     TEXT;
  v_svc_key TEXT;
BEGIN
  -- Skip scheduled (future-delivery) notifications; they push on delivery flip.
  IF NEW.scheduled_for IS NOT NULL AND NEW.is_delivered = FALSE THEN
    RETURN NEW;
  END IF;

  -- Read config from app_secrets (bypasses RLS via SECURITY DEFINER)
  v_url     := get_app_secret('supabase_url');
  v_svc_key := get_app_secret('service_role_key');

  -- Skip if service_role_key not yet configured
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
  -- Never let push failure block the notification INSERT
  RETURN NEW;
END;
$$;

-- ─── 5. Rewrite fn_send_push_on_notification_delivered ───────────
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_delivered()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url     TEXT;
  v_svc_key TEXT;
BEGIN
  -- Only fire when is_delivered flips FALSE → TRUE
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

-- ─── 6. Ensure triggers are still attached (idempotent) ─────────
DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;
DROP TRIGGER IF EXISTS trg_push_on_notification_delivered ON public.notifications;

CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.fn_send_push_on_notification_insert();

CREATE TRIGGER trg_push_on_notification_delivered
  AFTER UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.fn_send_push_on_notification_delivered();
;

-- ============================================================
-- Migration: Fix push_tokens schema + rewrite push trigger
-- Sierra Fleet Management System
-- Date: 2026-03-22 (seq 005)
--
-- Issues found in migration 20260322000002:
--
-- 1. Column name mismatch
--    Migration created:        token TEXT
--    Swift PushTokenService uses: device_token (INSERT + onConflict)
--    -> Every token registration fails: "column device_token does not exist"
--
-- 2. Wrong pg_setting key
--    Trigger reads: current_setting('app.settings.supabase_url', true)
--    Manual step sets: app.supabase_url
--    -> Setting always NULL -> push silently skipped for every notification
--
-- 3. No Authorization header
--    Edge function send-push-notification validates auth internally.
--    Trigger sends no Authorization header -> 401 -> zero pushes delivered.
--
-- 4. Payload shape mismatch
--    Trigger sends: { notificationId, recipientId }
--    Edge function expects: { recipientId, title, body, data? }
--    -> Edge function returns 400 missing fields -> no push sent
-- ============================================================

-- ------------------------------------------------------------
-- 1. Rename column token -> device_token (idempotent)
-- ------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name   = 'push_tokens'
           AND column_name  = 'token'
    ) THEN
        ALTER TABLE public.push_tokens RENAME COLUMN token TO device_token;
        RAISE NOTICE 'push_tokens: renamed column token -> device_token';
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name   = 'push_tokens'
           AND column_name  = 'device_token'
    ) THEN
        RAISE NOTICE 'push_tokens.device_token already exists — skipping rename';
    ELSE
        RAISE EXCEPTION 'push_tokens table not found; ensure migration 002 ran first';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 2. Fix unique constraint (column name changed)
-- ------------------------------------------------------------
DO $$
DECLARE cname TEXT;
BEGIN
    SELECT con.conname INTO cname
      FROM pg_constraint con
      JOIN pg_class      rel ON rel.oid = con.conrelid
      JOIN pg_namespace  nsp ON nsp.oid = rel.relnamespace
     WHERE nsp.nspname = 'public'
       AND rel.relname = 'push_tokens'
       AND con.contype = 'u'
     LIMIT 1;

    IF cname IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.push_tokens DROP CONSTRAINT %I', cname);
        RAISE NOTICE 'Dropped old unique constraint: %', cname;
    END IF;
END;
$$;

ALTER TABLE public.push_tokens
    ADD CONSTRAINT push_tokens_staff_id_device_token_key
    UNIQUE (staff_id, device_token);

-- Rebuild index with canonical name
DROP INDEX IF EXISTS push_tokens_staff_id_idx;
CREATE INDEX IF NOT EXISTS idx_push_tokens_staff_id ON public.push_tokens (staff_id);

-- ------------------------------------------------------------
-- 3. Rewrite fn_send_push_on_notification_insert
--    Fixes: setting key, Authorization header, payload shape
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_send_push_on_notification_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    _supabase_url     TEXT;
    _service_role_key TEXT;
BEGIN
    -- Read project settings. Set these once via:
    --   ALTER DATABASE postgres SET app.supabase_url = 'https://<ref>.supabase.co';
    --   ALTER DATABASE postgres SET app.service_role_key = '<your-service-role-key>';
    _supabase_url     := current_setting('app.supabase_url',     true);
    _service_role_key := current_setting('app.service_role_key', true);

    IF _supabase_url IS NULL OR _supabase_url = '' THEN
        RAISE NOTICE 'fn_send_push_on_notification_insert: app.supabase_url not configured — push skipped';
        RETURN NEW;
    END IF;

    -- pg_net fire-and-forget HTTP POST
    -- The edge function reads push_tokens WHERE staff_id = recipientId
    -- and sends one APNs request per registered device token.
    PERFORM net.http_post(
        url     := _supabase_url || '/functions/v1/send-push-notification',
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || COALESCE(_service_role_key, '')
        ),
        body := jsonb_build_object(
            'recipientId', NEW.recipient_id,
            'title',       NEW.title,
            'body',        NEW.body,
            'data',        jsonb_build_object(
                'type',       NEW.type,
                'entityType', COALESCE(NEW.entity_type, ''),
                'entityId',   COALESCE(NEW.entity_id::text, '')
            )
        )::text
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Non-fatal: the in-app notification row was already inserted.
    -- APNs delivery is best-effort.
    RAISE NOTICE 'fn_send_push_on_notification_insert: pg_net error — %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Re-attach trigger (idempotent)
DROP TRIGGER IF EXISTS trg_send_push_on_notification_insert ON public.notifications;

CREATE TRIGGER trg_send_push_on_notification_insert
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_send_push_on_notification_insert();

-- ============================================================
-- END OF MIGRATION 005
--
-- REQUIRED MANUAL STEPS (run once in Supabase SQL editor — NOT in migration,
-- because they contain production secrets):
--
--   ALTER DATABASE postgres SET app.supabase_url = 'https://ldqcdngdlbbiojlnbnjg.supabase.co';
--   ALTER DATABASE postgres SET app.service_role_key = '<your-service-role-key>';
--
-- After setting these, push notifications will flow for all new
-- notification row inserts.
-- ============================================================

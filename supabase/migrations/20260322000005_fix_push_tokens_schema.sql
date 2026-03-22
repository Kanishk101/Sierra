-- ============================================================
-- Migration: Fix push_tokens schema (column rename + constraint)
-- Sierra Fleet Management System
-- Date: 2026-03-22 (seq 005) — REVISED
--
-- WHAT THIS MIGRATION DOES:
--   1. Renames push_tokens.token -> push_tokens.device_token
--      (matches Swift PushTokenService INSERT + onConflict field name)
--   2. Fixes the unique constraint to reference the renamed column
--   3. REMOVES the broken pg_net push trigger entirely
--
-- WHY THE TRIGGER WAS REMOVED:
--   The previous version tried to call the send-push-notification edge
--   function from inside a Postgres trigger using pg_net + a service role
--   key stored via ALTER DATABASE SET. This was wrong for two reasons:
--
--   a) Supabase does not grant ALTER DATABASE SET to project users.
--      Running it throws: "permission denied to set parameter app.supabase_url"
--
--   b) Storing secrets as database GUC settings is bad practice regardless.
--
-- CORRECT ARCHITECTURE FOR PUSH DELIVERY:
--   Push notifications are already delivered correctly without any DB trigger.
--   The flow is:
--
--     iOS admin taps action
--       -> AppDataStore inserts notification row via NotificationService
--       -> Supabase Realtime broadcasts INSERT to all subscribed clients
--       -> Each recipient client's NotificationService subscription fires
--       -> In-app banner shown immediately
--
--   For background push (when app is closed), use Supabase Dashboard Webhooks:
--     Dashboard -> Database -> Webhooks -> Create webhook
--       Table:   notifications
--       Event:   INSERT
--       URL:     https://<ref>.supabase.co/functions/v1/send-push-notification
--       Method:  POST
--       Headers: Authorization: Bearer <service-role-key>
--
--   Database Webhooks are configured in the Dashboard (not in SQL migrations)
--   and Supabase manages the auth automatically. No secrets in DB code.
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
-- 2. Fix unique constraint (references old column name)
-- ------------------------------------------------------------
DO $$
DECLARE cname TEXT;
BEGIN
    -- Find and drop whatever unique constraint exists on this table
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
-- 3. Remove the broken pg_net push trigger from migration 002
--    (it required ALTER DATABASE SET which Supabase doesn't permit)
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_send_push_on_notification_insert ON public.notifications;
DROP FUNCTION IF EXISTS public.fn_send_push_on_notification_insert();

RAISE NOTICE '=== push_tokens schema fixed ===';
RAISE NOTICE 'Column: token -> device_token';
RAISE NOTICE 'Unique constraint: staff_id + device_token';
RAISE NOTICE 'Broken pg_net trigger: removed';
RAISE NOTICE '';
RAISE NOTICE 'For background push delivery, configure a Supabase Database Webhook:';
RAISE NOTICE '  Dashboard -> Database -> Webhooks -> Create new webhook';
RAISE NOTICE '  Table: notifications | Event: INSERT';
RAISE NOTICE '  URL: https://<ref>.supabase.co/functions/v1/send-push-notification';
RAISE NOTICE '================================';

-- ============================================================
-- END OF MIGRATION 005
-- ============================================================


-- app_secrets.key is already the PRIMARY KEY, so the UNIQUE constraint is redundant — drop it
ALTER TABLE public.app_secrets DROP CONSTRAINT IF EXISTS app_secrets_key_unique;
;

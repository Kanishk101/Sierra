-- ================================================================
-- Migration : drop_plaintext_password_columns
-- Applied   : 2026-03-18 to Sierra-FMS-v2 (ldqcdngdlbbiojlnbnjg)
--
-- All 13 auth.users rows were bcrypt-synced from staff_members.password
-- before this ran. This file is for migration history only.
-- The ALTER has already been executed on the live project.
-- ================================================================

ALTER TABLE public.staff_members
  DROP COLUMN IF EXISTS password,
  DROP COLUMN IF EXISTS failed_login_attempts,
  DROP COLUMN IF EXISTS account_locked_until;

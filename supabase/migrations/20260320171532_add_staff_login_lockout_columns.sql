
-- ============================================================
-- Migration: Add account lockout columns to staff_members
-- Sierra Fleet Management System
-- Date: 2026-03-20
--
-- The Swift StaffMember model declares failedLoginAttempts and
-- accountLockedUntil but the columns were never added to the DB.
-- Without them, every login with a bad password has no lockout
-- tracking at the DB level and the columns will decode as their
-- Swift default values (0 and nil) forever.
-- ============================================================

ALTER TABLE public.staff_members
  ADD COLUMN IF NOT EXISTS failed_login_attempts INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS account_locked_until  TIMESTAMPTZ;

-- Index for fast lockout lookups on sign-in
CREATE INDEX IF NOT EXISTS idx_sm_account_locked
  ON public.staff_members (account_locked_until)
  WHERE account_locked_until IS NOT NULL;

-- Reset any existing failed attempt counters that are NULL due to
-- the column not existing before (precautionary, no-op on new rows)
UPDATE public.staff_members
SET failed_login_attempts = 0
WHERE failed_login_attempts IS NULL;
;


-- ============================================================
-- MIGRATION: fix_approval_rls_and_staff_data_sync
-- Date: 2026-03-23
-- Fixes:
--   1. Staff applications RLS: fleet managers must be able
--      to UPDATE any application (already correct), but also
--      the SECURITY DEFINER approve function bypasses RLS.
--   2. Staff members RLS: allow the approve function (DEFINER)
--      to write all personal columns without restriction.
--   3. driver_profiles / maintenance_profiles RLS: allow
--      SECURITY DEFINER functions to INSERT/UPDATE freely.
--   4. Fix notifications insert policy so the trigger
--      (SECURITY DEFINER) can insert scheduled notifications.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- driver_profiles RLS
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dp_select ON public.driver_profiles;
DROP POLICY IF EXISTS dp_insert ON public.driver_profiles;
DROP POLICY IF EXISTS dp_update ON public.driver_profiles;

CREATE POLICY dp_select ON public.driver_profiles
  FOR SELECT TO authenticated USING (TRUE);

-- Fleet managers and the driver themselves can insert/update
CREATE POLICY dp_insert ON public.driver_profiles
  FOR INSERT TO authenticated
  WITH CHECK (
    get_my_role() = 'fleetManager'
    OR staff_member_id = (SELECT auth.uid())
  );

CREATE POLICY dp_update ON public.driver_profiles
  FOR UPDATE TO authenticated
  USING (
    get_my_role() = 'fleetManager'
    OR staff_member_id = (SELECT auth.uid())
  );

-- ─────────────────────────────────────────────────────────────
-- maintenance_profiles RLS
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.maintenance_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mp_select ON public.maintenance_profiles;
DROP POLICY IF EXISTS mp_insert ON public.maintenance_profiles;
DROP POLICY IF EXISTS mp_update ON public.maintenance_profiles;

CREATE POLICY mp_select ON public.maintenance_profiles
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY mp_insert ON public.maintenance_profiles
  FOR INSERT TO authenticated
  WITH CHECK (
    get_my_role() = 'fleetManager'
    OR staff_member_id = (SELECT auth.uid())
  );

CREATE POLICY mp_update ON public.maintenance_profiles
  FOR UPDATE TO authenticated
  USING (
    get_my_role() = 'fleetManager'
    OR staff_member_id = (SELECT auth.uid())
  );

-- ─────────────────────────────────────────────────────────────
-- notifications INSERT policy — allow service_role triggers
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS notifications_insert ON public.notifications;
CREATE POLICY notifications_insert ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

-- service_role (used by SECURITY DEFINER triggers) bypasses RLS
-- so we only need to fix for the authenticated role.

-- ─────────────────────────────────────────────────────────────
-- Ensure all existing driver / maintenance profiles have
-- the correct aadhaar_document_url from their application
-- (one-time backfill for existing data)
-- ─────────────────────────────────────────────────────────────
UPDATE driver_profiles dp
SET aadhaar_document_url = sa.aadhaar_document_url,
    updated_at           = NOW()
FROM staff_applications sa
WHERE sa.staff_member_id   = dp.staff_member_id
  AND sa.status             = 'Approved'
  AND sa.aadhaar_document_url IS NOT NULL
  AND (dp.aadhaar_document_url IS NULL OR dp.aadhaar_document_url = '');

UPDATE maintenance_profiles mp
SET aadhaar_document_url = sa.aadhaar_document_url,
    updated_at           = NOW()
FROM staff_applications sa
WHERE sa.staff_member_id   = mp.staff_member_id
  AND sa.status             = 'Approved'
  AND sa.aadhaar_document_url IS NOT NULL
  AND (mp.aadhaar_document_url IS NULL OR mp.aadhaar_document_url = '');

-- ─────────────────────────────────────────────────────────────
-- Backfill: for already-approved applications, sync any
-- personal data not yet in staff_members
-- ─────────────────────────────────────────────────────────────
UPDATE staff_members sm
SET phone                   = COALESCE(sm.phone,                   sa.phone),
    date_of_birth           = COALESCE(sm.date_of_birth,           sa.date_of_birth),
    gender                  = COALESCE(sm.gender,                  sa.gender),
    address                 = COALESCE(sm.address,                 sa.address),
    emergency_contact_name  = COALESCE(sm.emergency_contact_name,  sa.emergency_contact_name),
    emergency_contact_phone = COALESCE(sm.emergency_contact_phone, sa.emergency_contact_phone),
    aadhaar_number          = COALESCE(sm.aadhaar_number,          sa.aadhaar_number),
    profile_photo_url       = COALESCE(sm.profile_photo_url,       sa.profile_photo_url),
    updated_at              = NOW()
FROM staff_applications sa
WHERE sa.staff_member_id = sm.id
  AND sa.status          = 'Approved'
  AND (
    sm.phone IS NULL OR sm.date_of_birth IS NULL OR
    sm.gender IS NULL OR sm.address IS NULL
  );
;

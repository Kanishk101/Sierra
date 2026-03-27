
-- SECURITY FIX: Tighten the two INSERT policies that use WITH CHECK (true)

-- ── activity_logs ─────────────────────────────────────────────────────────────
-- Only SECURITY DEFINER trigger functions should write to activity_logs.
-- No direct inserts from client should be allowed.
DROP POLICY IF EXISTS al_insert ON public.activity_logs;

-- Restrict inserts to fleet managers only (triggers run as SECURITY DEFINER 
-- so they bypass RLS entirely — client-side inserts shouldn't happen at all)
CREATE POLICY al_insert ON public.activity_logs
  FOR INSERT
  WITH CHECK (
    (SELECT role FROM public.staff_members WHERE id = (SELECT auth.uid())) = 'fleetManager'
  );

-- ── staff_applications ────────────────────────────────────────────────────────
-- An applicant must only be able to insert their own application (their staff_member_id)
DROP POLICY IF EXISTS sa_insert ON public.staff_applications;

CREATE POLICY sa_insert ON public.staff_applications
  FOR INSERT
  WITH CHECK (
    staff_member_id = (SELECT auth.uid())
  );
;

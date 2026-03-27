
-- ══════════════════════════════════════════════════════════════
-- RLS POLICIES — STAFF LAYER
-- Tables: staff_members, driver_profiles, maintenance_profiles,
--         staff_applications, two_factor_sessions
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- staff_members
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to staff_members" ON public.staff_members;
DROP POLICY IF EXISTS "Staff: read own record" ON public.staff_members;
DROP POLICY IF EXISTS "Staff: update own non-sensitive fields" ON public.staff_members;

-- Admins can do everything
CREATE POLICY "Admin: full access to staff_members"
ON public.staff_members
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Any staff member can read their own record
CREATE POLICY "Staff: read own record"
ON public.staff_members
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- Staff can update their own non-sensitive fields (name, phone, address, etc.)
-- Role, status, isApproved are admin-only — enforced at app layer
CREATE POLICY "Staff: update own non-sensitive fields"
ON public.staff_members
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ─────────────────────────────────────────────
-- driver_profiles
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to driver_profiles" ON public.driver_profiles;
DROP POLICY IF EXISTS "Driver: read own profile" ON public.driver_profiles;

CREATE POLICY "Admin: full access to driver_profiles"
ON public.driver_profiles
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

CREATE POLICY "Driver: read own profile"
ON public.driver_profiles
FOR SELECT
TO authenticated
USING (staff_member_id = auth.uid());

-- ─────────────────────────────────────────────
-- maintenance_profiles
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to maintenance_profiles" ON public.maintenance_profiles;
DROP POLICY IF EXISTS "Maintenance: read own profile" ON public.maintenance_profiles;

CREATE POLICY "Admin: full access to maintenance_profiles"
ON public.maintenance_profiles
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

CREATE POLICY "Maintenance: read own profile"
ON public.maintenance_profiles
FOR SELECT
TO authenticated
USING (staff_member_id = auth.uid());

-- ─────────────────────────────────────────────
-- staff_applications
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to staff_applications" ON public.staff_applications;
DROP POLICY IF EXISTS "Staff: read and insert own application" ON public.staff_applications;

CREATE POLICY "Admin: full access to staff_applications"
ON public.staff_applications
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Staff can read their own application and submit new ones
CREATE POLICY "Staff: read and insert own application"
ON public.staff_applications
FOR SELECT
TO authenticated
USING (staff_member_id = auth.uid());

CREATE POLICY "Staff: insert own application"
ON public.staff_applications
FOR INSERT
TO authenticated
WITH CHECK (staff_member_id = auth.uid());

-- ─────────────────────────────────────────────
-- two_factor_sessions
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "User: read own 2FA session" ON public.two_factor_sessions;

-- Users can only read their own 2FA session
-- Writes are handled by Edge Functions (service_role bypasses RLS)
CREATE POLICY "User: read own 2FA session"
ON public.two_factor_sessions
FOR SELECT
TO authenticated
USING (user_id = auth.uid());
;

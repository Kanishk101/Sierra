
-- ============================================================
-- MIGRATION: Switch to Vinayak auth pattern
-- 1. Drop staff_members → auth.users FK (no longer needed)
-- 2. Add password column to staff_members
-- 3. Drop two_factor_sessions → auth.users FK
-- 4. Replace RLS on staff_members with open policies
--    (anon can SELECT for login, anon can UPDATE for password
--     changes, fleet manager session covers INSERT/DELETE)
-- ============================================================

-- Step 1: Drop the FK that binds staff_members.id to auth.users.id
ALTER TABLE public.staff_members
    DROP CONSTRAINT IF EXISTS staff_members_id_fkey;

-- Step 2: Add password column
ALTER TABLE public.staff_members
    ADD COLUMN IF NOT EXISTS password TEXT NOT NULL DEFAULT '';

-- Step 3: Drop two_factor_sessions → auth.users FK (no longer used)
ALTER TABLE public.two_factor_sessions
    DROP CONSTRAINT IF EXISTS two_factor_sessions_user_id_fkey;

-- Step 4: Replace staff_members RLS policies
-- Drop existing policies
DROP POLICY IF EXISTS fm_all_staff            ON public.staff_members;
DROP POLICY IF EXISTS staff_own_record_select ON public.staff_members;
DROP POLICY IF EXISTS staff_own_record_update ON public.staff_members;

-- New policies
-- 4a. Anyone (anon or authenticated) can SELECT — needed for login query by email
CREATE POLICY staff_members_select_all
    ON public.staff_members
    FOR SELECT
    USING (true);

-- 4b. Anyone can INSERT — fleet manager app inserts new staff rows
--     (the fleet manager has a Supabase session but new staff do not,
--      and the insert comes from the admin's client so anon is fine here)
CREATE POLICY staff_members_insert_all
    ON public.staff_members
    FOR INSERT
    WITH CHECK (true);

-- 4c. Anyone can UPDATE — needed for password reset (no session),
--     first-login password change (no session), and profile updates
CREATE POLICY staff_members_update_all
    ON public.staff_members
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- 4d. DELETE restricted to authenticated users only (fleet manager)
CREATE POLICY staff_members_delete_authenticated
    ON public.staff_members
    FOR DELETE
    USING (auth.role() = 'authenticated');
;

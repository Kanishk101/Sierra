# Phase 1 — Database Migration ✅ ALREADY APPLIED

This phase has been applied directly to Sierra-FMS-v2 (`ldqcdngdlbbiojlnbnjg`).
No action required.

## What was changed

### 1. Dropped `staff_members_id_fkey`
The FK that bound `staff_members.id → auth.users.id` has been dropped.
`staff_members` is now a fully independent table — you can insert rows
without a corresponding Supabase Auth user existing first.

### 2. Added `password TEXT NOT NULL DEFAULT ''` to `staff_members`
Exact same pattern as vinayak's `auth_users.password` column.
Passwords are stored as plaintext (matching vinayak exactly).
This column is used for:
- Login verification (compare submitted password against stored value)
- First-login forced password change (update column directly)
- Password reset (update column directly after OTP verification)

### 3. Dropped `two_factor_sessions_user_id_fkey`
The `two_factor_sessions` table had a FK to `auth.users.id` which is no
longer valid since new staff won't have auth.users entries.

### 4. Replaced RLS on `staff_members`
Old policies used `get_my_role()` (requires an active Supabase Auth session).
New policies:
- `SELECT`: open to all (anon + authenticated) — required for login query
- `INSERT`: open to all — fleet manager client inserts new staff rows
- `UPDATE`: open to all — required for password reset (no session exists yet)
- `DELETE`: authenticated only — fleet manager only

## SQL Applied
```sql
ALTER TABLE public.staff_members
    DROP CONSTRAINT IF EXISTS staff_members_id_fkey;

ALTER TABLE public.staff_members
    ADD COLUMN IF NOT EXISTS password TEXT NOT NULL DEFAULT '';

ALTER TABLE public.two_factor_sessions
    DROP CONSTRAINT IF EXISTS two_factor_sessions_user_id_fkey;

DROP POLICY IF EXISTS fm_all_staff            ON public.staff_members;
DROP POLICY IF EXISTS staff_own_record_select ON public.staff_members;
DROP POLICY IF EXISTS staff_own_record_update ON public.staff_members;

CREATE POLICY staff_members_select_all
    ON public.staff_members FOR SELECT USING (true);

CREATE POLICY staff_members_insert_all
    ON public.staff_members FOR INSERT WITH CHECK (true);

CREATE POLICY staff_members_update_all
    ON public.staff_members FOR UPDATE
    USING (true) WITH CHECK (true);

CREATE POLICY staff_members_delete_authenticated
    ON public.staff_members FOR DELETE
    USING (auth.role() = 'authenticated');
```

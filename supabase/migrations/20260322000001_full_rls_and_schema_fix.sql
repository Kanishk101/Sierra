-- ============================================================
-- Migration: Full RLS Fix + Schema Additions + Notification Triggers
-- Sierra Fleet Management System
-- Date: 2026-03-22
--
-- Sections:
--   A) trips table schema additions (acceptance flow columns + enum values)
--   B) RLS — staff_members
--   C) RLS — vehicles
--   D) RLS — geofences
--   E) RLS — trips
--   F) RLS — notifications
--   G) fn_notify_on_geofence_event() + trigger
--   H) fn_notify_driver_trip_assigned() + trigger
--   I) Realtime — notifications REPLICA IDENTITY FULL
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- A) TRIPS TABLE — Add acceptance flow columns + new enum values
-- ────────────────────────────────────────────────────────────

-- Add new enum values to trip_status (idempotent via DO block)
DO $$
BEGIN
    ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'PendingAcceptance';
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
    ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'Accepted';
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
    ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'Rejected';
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

-- Add acceptance-related columns to trips
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS accepted_at          TIMESTAMPTZ DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS acceptance_deadline  TIMESTAMPTZ DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS rejected_reason      TEXT        DEFAULT NULL;


-- ────────────────────────────────────────────────────────────
-- B) RLS — staff_members
--
-- Policies:
--   1. Any authenticated user can SELECT their own row
--   2. Admins can SELECT all rows
--   3. Admins can INSERT / UPDATE / DELETE any row
--   4. Staff can UPDATE their own availability only
--      (column-level enforcement is handled in the app layer;
--       this policy restricts the row scope)
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;

-- Helper: reusable admin check expression
-- (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
-- NOTE: we cannot use a SQL function here because it would cause infinite
-- recursion (policy on staff_members calling a function that queries
-- staff_members). Instead we inline the sub-select everywhere.

-- Drop old policies to avoid conflicts before recreating
DROP POLICY IF EXISTS staff_members_select_own       ON public.staff_members;
DROP POLICY IF EXISTS staff_members_select_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_insert_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_update_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_delete_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_update_own_avail ON public.staff_members;

-- 1. Any staff member can read their own record
CREATE POLICY staff_members_select_own
    ON public.staff_members
    FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- 2. Admins can read all records
CREATE POLICY staff_members_select_admin
    ON public.staff_members
    FOR SELECT
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

-- 3. Admins can insert new staff records
CREATE POLICY staff_members_insert_admin
    ON public.staff_members
    FOR INSERT
    TO authenticated
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

-- 4. Admins can update any staff record
CREATE POLICY staff_members_update_admin
    ON public.staff_members
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    )
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

-- 5. Admins can delete staff records
CREATE POLICY staff_members_delete_admin
    ON public.staff_members
    FOR DELETE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

-- 6. Staff can update their own row (availability toggle, profile fields)
--    Scope: own row only. Column-level restriction (availability only vs full
--    profile fields) is handled by the app payload — the iOS update payloads
--    exclude role/email from StaffMemberUpdatePayload intentionally.
CREATE POLICY staff_members_update_own_avail
    ON public.staff_members
    FOR UPDATE
    TO authenticated
    USING  (id = auth.uid())
    WITH CHECK (id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- C) RLS — vehicles
--
-- Policies:
--   1. All authenticated users can SELECT vehicles
--   2. Only admins can INSERT / UPDATE / DELETE vehicles
--
-- The DB trigger fn_trip_status_change is SECURITY DEFINER so it
-- executes as the function owner (superuser/postgres), bypassing RLS
-- entirely. No special policy needed for the trigger.
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vehicles_select_authenticated ON public.vehicles;
DROP POLICY IF EXISTS vehicles_insert_admin         ON public.vehicles;
DROP POLICY IF EXISTS vehicles_update_admin         ON public.vehicles;
DROP POLICY IF EXISTS vehicles_delete_admin         ON public.vehicles;

-- 1. All authenticated users read vehicles (drivers, maintenance, admins)
CREATE POLICY vehicles_select_authenticated
    ON public.vehicles
    FOR SELECT
    TO authenticated
    USING (true);

-- 2. Admins can insert vehicles
CREATE POLICY vehicles_insert_admin
    ON public.vehicles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

-- 3. Admins can update vehicles
CREATE POLICY vehicles_update_admin
    ON public.vehicles
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    )
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

-- 4. Admins can delete vehicles
CREATE POLICY vehicles_delete_admin
    ON public.vehicles
    FOR DELETE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );


-- ────────────────────────────────────────────────────────────
-- D) RLS — geofences
--
-- Only fleet managers (role = 'Admin') can manage geofences.
-- This is the root cause of geofence CRUD failures reported by users.
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS geofences_select_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_insert_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_update_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_delete_admin ON public.geofences;

CREATE POLICY geofences_select_admin
    ON public.geofences
    FOR SELECT
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

CREATE POLICY geofences_insert_admin
    ON public.geofences
    FOR INSERT
    TO authenticated
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

CREATE POLICY geofences_update_admin
    ON public.geofences
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    )
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

CREATE POLICY geofences_delete_admin
    ON public.geofences
    FOR DELETE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );


-- ────────────────────────────────────────────────────────────
-- E) RLS — trips
--
-- Policies:
--   1. Admins: full CRUD
--   2. Drivers: SELECT their own trips (driver_id = auth.uid()::text)
--   3. Drivers: UPDATE their own trips for acceptance flow only
--      (status, accepted_at, rejected_reason)
--   4. Maintenance personnel: SELECT trips (read-only context)
--
-- NOTE: driver_id and vehicle_id are stored as TEXT (not UUID) in the
-- trips table. We cast auth.uid() to text for comparison.
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trips_all_admin          ON public.trips;
DROP POLICY IF EXISTS trips_select_driver      ON public.trips;
DROP POLICY IF EXISTS trips_update_driver      ON public.trips;
DROP POLICY IF EXISTS trips_select_maintenance ON public.trips;

-- 1. Admins: full access
CREATE POLICY trips_all_admin
    ON public.trips
    FOR ALL
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    )
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Admin'
    );

-- 2. Drivers: read their assigned trips
CREATE POLICY trips_select_driver
    ON public.trips
    FOR SELECT
    TO authenticated
    USING (
        driver_id = auth.uid()::text
        AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Driver'
    );

-- 3. Drivers: update acceptance fields on their own trips
--    (status, accepted_at, acceptance_deadline, rejected_reason,
--     pre_inspection_id, post_inspection_id, proof_of_delivery_id,
--     start_mileage, end_mileage, actual_start_date, actual_end_date)
--    Row-level scope: driver_id must match the caller.
--    Column-level restriction is enforced by the iOS app payload.
CREATE POLICY trips_update_driver
    ON public.trips
    FOR UPDATE
    TO authenticated
    USING (
        driver_id = auth.uid()::text
        AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Driver'
    )
    WITH CHECK (
        driver_id = auth.uid()::text
        AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Driver'
    );

-- 4. Maintenance personnel: read-only trip context
CREATE POLICY trips_select_maintenance
    ON public.trips
    FOR SELECT
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'Maintenance'
    );


-- ────────────────────────────────────────────────────────────
-- F) RLS — notifications
--
-- Policies:
--   1. Users SELECT only their own notifications
--      recipient_id is stored as TEXT (UUID string) in this table.
--      We cast both sides to text to avoid type mismatch.
--   2. INSERT is via service role (edge functions / DB triggers)
--      which bypass RLS entirely — no INSERT policy needed for
--      authenticated users.
--   3. Users can UPDATE is_read / read_at on their own rows.
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;

-- 1. Select own notifications
--    recipient_id stored as TEXT; auth.uid() returns UUID.
--    Cast both to text for safe comparison.
CREATE POLICY notifications_select_own
    ON public.notifications
    FOR SELECT
    TO authenticated
    USING (
        recipient_id = auth.uid()::text
    );

-- 2. Mark notifications as read (is_read, read_at)
CREATE POLICY notifications_update_own
    ON public.notifications
    FOR UPDATE
    TO authenticated
    USING  (recipient_id = auth.uid()::text)
    WITH CHECK (recipient_id = auth.uid()::text);

-- 3. Allow service_role to insert notifications (triggers + edge functions)
--    Service role bypasses RLS by default in Supabase.
--    The following explicit grant is belt-and-suspenders for custom roles.
GRANT INSERT ON public.notifications TO service_role;


-- ────────────────────────────────────────────────────────────
-- G) FUNCTION + TRIGGER — fn_notify_on_geofence_event
--
-- Fires AFTER INSERT on geofence_events.
-- Notifies all Admin staff members of the entry/exit event.
-- SECURITY DEFINER so it can INSERT into notifications even when
-- the calling context has restricted RLS.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_notify_on_geofence_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id   UUID;
    v_event_type TEXT;
    v_geo_name   TEXT;
    v_title      TEXT;
    v_body       TEXT;
BEGIN
    -- Resolve geofence name (graceful fallback if not found)
    SELECT COALESCE(name, 'Unknown Zone')
      INTO v_geo_name
      FROM public.geofences
     WHERE id = NEW.geofence_id;

    -- Normalise event type label
    v_event_type := CASE
        WHEN LOWER(NEW.event_type::text) = 'enter' THEN 'entered'
        ELSE 'exited'
    END;

    v_title := 'Geofence Alert: ' || v_event_type || ' ' || v_geo_name;
    v_body  := 'Vehicle ' || NEW.vehicle_id::text
               || ' ' || v_event_type
               || ' geofence zone "' || v_geo_name || '"'
               || ' at ' || TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS UTC');

    -- Insert one notification per admin
    FOR v_admin_id IN
        SELECT id FROM public.staff_members WHERE role = 'Admin'
    LOOP
        INSERT INTO public.notifications (
            id,
            recipient_id,
            type,
            title,
            body,
            entity_type,
            entity_id,
            is_read,
            sent_at
        ) VALUES (
            gen_random_uuid(),
            v_admin_id::text,
            'geofence_alert',
            v_title,
            v_body,
            'geofence_event',
            NEW.id::text,
            false,
            NOW()
        );
    END LOOP;

    RETURN NEW;
END;
$$;

-- Attach trigger
DROP TRIGGER IF EXISTS trg_geofence_notification ON public.geofence_events;

CREATE TRIGGER trg_geofence_notification
    AFTER INSERT ON public.geofence_events
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_on_geofence_event();


-- ────────────────────────────────────────────────────────────
-- H) FUNCTION + TRIGGER — fn_notify_driver_trip_assigned
--
-- Fires AFTER INSERT on trips WHERE driver_id IS NOT NULL.
-- Sends an in-app notification to the assigned driver.
-- SECURITY DEFINER so it can INSERT into notifications regardless
-- of the inserting session's RLS context.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_scheduled TEXT;
BEGIN
    -- Only fire when a driver is assigned at insert time
    IF NEW.driver_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Human-readable scheduled date (UTC)
    v_scheduled := TO_CHAR(
        NEW.scheduled_date AT TIME ZONE 'UTC',
        'Mon DD, YYYY at HH24:MI UTC'
    );

    INSERT INTO public.notifications (
        id,
        recipient_id,
        type,
        title,
        body,
        entity_type,
        entity_id,
        is_read,
        sent_at
    ) VALUES (
        gen_random_uuid(),
        NEW.driver_id,          -- already TEXT in trips table
        'trip_assigned',
        'New Trip Assigned: ' || NEW.task_id,
        'You have been assigned a trip from '
            || NEW.origin
            || ' to '
            || NEW.destination
            || ' scheduled for '
            || v_scheduled,
        'trip',
        NEW.id::text,
        false,
        NOW()
    );

    RETURN NEW;
END;
$$;

-- Attach trigger
DROP TRIGGER IF EXISTS trg_trip_assigned_notification ON public.trips;

CREATE TRIGGER trg_trip_assigned_notification
    AFTER INSERT ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_driver_trip_assigned();

-- Also notify when driver_id is SET on an existing trip (admin assigns later)
CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_reassigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_scheduled TEXT;
BEGIN
    -- Fire only when driver_id transitions from NULL → non-NULL
    IF OLD.driver_id IS NOT NULL OR NEW.driver_id IS NULL THEN
        RETURN NEW;
    END IF;

    v_scheduled := TO_CHAR(
        NEW.scheduled_date AT TIME ZONE 'UTC',
        'Mon DD, YYYY at HH24:MI UTC'
    );

    INSERT INTO public.notifications (
        id,
        recipient_id,
        type,
        title,
        body,
        entity_type,
        entity_id,
        is_read,
        sent_at
    ) VALUES (
        gen_random_uuid(),
        NEW.driver_id,
        'trip_assigned',
        'New Trip Assigned: ' || NEW.task_id,
        'You have been assigned a trip from '
            || NEW.origin
            || ' to '
            || NEW.destination
            || ' scheduled for '
            || v_scheduled,
        'trip',
        NEW.id::text,
        false,
        NOW()
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trip_reassigned_notification ON public.trips;

CREATE TRIGGER trg_trip_reassigned_notification
    AFTER UPDATE OF driver_id ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_driver_trip_reassigned();


-- ────────────────────────────────────────────────────────────
-- I) Realtime — enable REPLICA IDENTITY FULL on notifications
--
-- Required so Supabase Realtime can broadcast the full NEW row
-- on INSERT events to subscribed clients (drivers/admins).
-- Without FULL, only the primary key is included in the change
-- payload, breaking the iOS NotificationService decoder.
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Also enable realtime publication for notifications if not already included
DO $$
BEGIN
    -- supabase_realtime publication is managed by Supabase platform.
    -- This ALTER attempts to add notifications; safe to run multiple times.
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION
    WHEN duplicate_object  THEN NULL;  -- already in publication
    WHEN undefined_object  THEN NULL;  -- publication doesn't exist (local dev)
END;
$$;


-- ════════════════════════════════════════════════════════════
-- END OF MIGRATION 20260322000001_full_rls_and_schema_fix.sql
-- ════════════════════════════════════════════════════════════

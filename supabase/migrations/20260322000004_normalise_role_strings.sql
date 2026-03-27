-- ============================================================
-- Migration: Normalise role strings + rewrite all RLS policies
-- Sierra Fleet Management System
-- Date: 2026-03-22 (seq 004)
--
-- THE PROBLEM:
-- Migration 20260322000001 wrote RLS policies checking 'Admin', 'Driver',
-- 'Maintenance'. The create-staff-account edge function inserts
-- 'fleetManager' / 'maintenancePersonnel'. Swift UserRole enum rawValues
-- also use 'fleetManager' / 'driver' / 'maintenancePersonnel'.
-- Every admin RLS check therefore fails silently.
-- Geofence CRUD, vehicle CRUD, trip management, notification fan-out all broken.
--
-- CANONICAL ROLE STRINGS (match Swift UserRole enum rawValues):
--   'fleetManager'          (was: 'Admin', 'admin', 'Fleet Manager', ...)
--   'driver'                (was: 'Driver')
--   'maintenancePersonnel'  (was: 'Maintenance', 'maintenance', ...)
--
-- ALSO FIXES: Notification trigger functions were inserting type strings
-- in snake_case ('geofence_alert', 'trip_assigned') but Swift Codable
-- decodes using rawValues with spaces ('Geofence Alert', 'Trip Assigned').
-- Those trigger-generated notifications failed to decode on every device.
-- ============================================================

-- ------------------------------------------------------------
-- STEP 1: Audit current role values (visible in Supabase logs)
-- ------------------------------------------------------------
DO $$
DECLARE r RECORD;
BEGIN
    RAISE NOTICE '=== PRE-MIGRATION role audit ===';
    FOR r IN
        SELECT role, COUNT(*) AS cnt
        FROM public.staff_members GROUP BY role ORDER BY cnt DESC
    LOOP
        RAISE NOTICE '  role=% count=%', r.role, r.cnt;
    END LOOP;
    RAISE NOTICE '================================';
END;
$$;

-- ------------------------------------------------------------
-- STEP 2: Normalise. Covers every spelling that may exist in DB.
-- ------------------------------------------------------------
UPDATE public.staff_members
    SET role = 'fleetManager'
    WHERE LOWER(role::text) IN (
        'admin',
        'fleet manager',
        'fleet_manager',
        'fleetmanager',
        'administrator'
    );

UPDATE public.staff_members
    SET role = 'driver'
    WHERE LOWER(role::text) = 'driver';

UPDATE public.staff_members
    SET role = 'maintenancePersonnel'
    WHERE LOWER(role::text) IN (
        'maintenance',
        'maintenancepersonnel',
        'maintenance_personnel',
        'maintenance personnel'
    );

-- ------------------------------------------------------------
-- STEP 3: Verify
-- ------------------------------------------------------------
DO $$
DECLARE r RECORD; bad INT := 0;
BEGIN
    RAISE NOTICE '=== POST-MIGRATION role audit ===';
    FOR r IN
        SELECT role, COUNT(*) AS cnt
        FROM public.staff_members GROUP BY role
    LOOP
        RAISE NOTICE '  role=% count=%', r.role, r.cnt;
        IF LOWER(r.role::text) NOT IN ('fleetmanager', 'driver', 'maintenancepersonnel') THEN
            RAISE WARNING '  UNEXPECTED role still present: % (count: %)', r.role, r.cnt;
            bad := bad + 1;
        END IF;
    END LOOP;
    IF bad = 0 THEN
        RAISE NOTICE '  Normalisation complete — all values canonical.';
    END IF;
    RAISE NOTICE '=================================';
END;
$$;

-- ------------------------------------------------------------
-- STEP 4: Rewrite ALL RLS policies with canonical role strings
-- ------------------------------------------------------------

-- == staff_members ==
DROP POLICY IF EXISTS staff_members_select_own       ON public.staff_members;
DROP POLICY IF EXISTS staff_members_select_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_insert_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_update_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_delete_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_update_own_avail ON public.staff_members;

-- Any authenticated staff member can read their own row
CREATE POLICY staff_members_select_own
    ON public.staff_members FOR SELECT TO authenticated
    USING (id = auth.uid());

-- Fleet managers can read ALL rows
CREATE POLICY staff_members_select_admin
    ON public.staff_members FOR SELECT TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

-- Fleet managers can INSERT new staff rows
CREATE POLICY staff_members_insert_admin
    ON public.staff_members FOR INSERT TO authenticated
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

-- Fleet managers can UPDATE any staff row
CREATE POLICY staff_members_update_admin
    ON public.staff_members FOR UPDATE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    )
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

-- Fleet managers can DELETE any staff row
CREATE POLICY staff_members_delete_admin
    ON public.staff_members FOR DELETE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

-- Staff can update their own row (availability toggle + profile fields)
CREATE POLICY staff_members_update_own_avail
    ON public.staff_members FOR UPDATE TO authenticated
    USING  (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- == vehicles ==
DROP POLICY IF EXISTS vehicles_select_authenticated ON public.vehicles;
DROP POLICY IF EXISTS vehicles_insert_admin         ON public.vehicles;
DROP POLICY IF EXISTS vehicles_update_admin         ON public.vehicles;
DROP POLICY IF EXISTS vehicles_delete_admin         ON public.vehicles;

-- All authenticated users can read vehicles
CREATE POLICY vehicles_select_authenticated
    ON public.vehicles FOR SELECT TO authenticated
    USING (true);

CREATE POLICY vehicles_insert_admin
    ON public.vehicles FOR INSERT TO authenticated
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY vehicles_update_admin
    ON public.vehicles FOR UPDATE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    )
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY vehicles_delete_admin
    ON public.vehicles FOR DELETE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

-- == geofences ==
DROP POLICY IF EXISTS geofences_select_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_insert_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_update_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_delete_admin ON public.geofences;

CREATE POLICY geofences_select_admin
    ON public.geofences FOR SELECT TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY geofences_insert_admin
    ON public.geofences FOR INSERT TO authenticated
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY geofences_update_admin
    ON public.geofences FOR UPDATE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    )
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY geofences_delete_admin
    ON public.geofences FOR DELETE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

-- == trips ==
DROP POLICY IF EXISTS trips_all_admin          ON public.trips;
DROP POLICY IF EXISTS trips_select_driver      ON public.trips;
DROP POLICY IF EXISTS trips_update_driver      ON public.trips;
DROP POLICY IF EXISTS trips_select_maintenance ON public.trips;

-- Fleet managers: full CRUD
CREATE POLICY trips_all_admin
    ON public.trips FOR ALL TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    )
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

-- Drivers: read their own assigned trips (driver_id stored as TEXT)
CREATE POLICY trips_select_driver
    ON public.trips FOR SELECT TO authenticated
    USING (
        driver_id::text = auth.uid()::text
        AND LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'driver'
    );

-- Drivers: update acceptance fields + inspection IDs on their own trips
CREATE POLICY trips_update_driver
    ON public.trips FOR UPDATE TO authenticated
    USING (
        driver_id::text = auth.uid()::text
        AND LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'driver'
    )
    WITH CHECK (
        driver_id::text = auth.uid()::text
        AND LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'driver'
    );

-- Maintenance personnel: read-only
CREATE POLICY trips_select_maintenance
    ON public.trips FOR SELECT TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'maintenancepersonnel'
    );

-- == notifications ==
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;

CREATE POLICY notifications_select_own
    ON public.notifications FOR SELECT TO authenticated
    USING (recipient_id::text = auth.uid()::text);

CREATE POLICY notifications_update_own
    ON public.notifications FOR UPDATE TO authenticated
    USING  (recipient_id::text = auth.uid()::text)
    WITH CHECK (recipient_id::text = auth.uid()::text);

GRANT INSERT ON public.notifications TO service_role;

-- ------------------------------------------------------------
-- STEP 5: Update notification trigger functions
-- a) Use canonical 'fleetManager' role string
-- b) Fix type strings to match Swift NotificationType rawValues
--    OLD: 'geofence_alert', 'trip_assigned' (snake_case)
--    NEW: 'Geofence Alert', 'Trip Assigned' (Swift rawValues)
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_notify_on_geofence_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_admin_id   UUID;
    v_event_type TEXT;
    v_geo_name   TEXT;
    v_title      TEXT;
    v_body       TEXT;
BEGIN
    SELECT COALESCE(name, 'Unknown Zone') INTO v_geo_name
      FROM public.geofences WHERE id = NEW.geofence_id;

    v_event_type := CASE WHEN LOWER(NEW.event_type::text) = 'enter' THEN 'entered' ELSE 'exited' END;
    v_title := 'Geofence Alert: ' || v_event_type || ' ' || v_geo_name;
    v_body  := 'Vehicle ' || NEW.vehicle_id::text
               || ' ' || v_event_type
               || ' zone "' || v_geo_name || '"'
               || ' at ' || TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI UTC');

    -- Use canonical role string
    FOR v_admin_id IN
        SELECT id FROM public.staff_members WHERE LOWER(role::text) = 'fleetmanager'
    LOOP
        INSERT INTO public.notifications
            (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
        VALUES (
            gen_random_uuid(), v_admin_id::text,
            'Geofence Alert',  -- Swift NotificationType.geofenceAlert.rawValue
            v_title, v_body, 'geofence_event', NEW.id::text, false, NOW()
        );
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_assigned()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_scheduled TEXT;
BEGIN
    IF NEW.driver_id IS NULL THEN RETURN NEW; END IF;
    v_scheduled := TO_CHAR(NEW.scheduled_date AT TIME ZONE 'UTC', 'Mon DD, YYYY at HH24:MI UTC');
    INSERT INTO public.notifications
        (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
    VALUES (
        gen_random_uuid(), NEW.driver_id::text,
        'Trip Assigned',   -- Swift NotificationType.tripAssigned.rawValue
        'New Trip Assigned: ' || NEW.task_id,
        'You have been assigned a trip from ' || NEW.origin
            || ' to ' || NEW.destination || ' scheduled for ' || v_scheduled,
        'trip', NEW.id::text, false, NOW()
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_reassigned()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_scheduled TEXT;
BEGIN
    -- Only fires when driver_id transitions NULL -> non-NULL on UPDATE
    IF OLD.driver_id IS NOT NULL OR NEW.driver_id IS NULL THEN RETURN NEW; END IF;
    v_scheduled := TO_CHAR(NEW.scheduled_date AT TIME ZONE 'UTC', 'Mon DD, YYYY at HH24:MI UTC');
    INSERT INTO public.notifications
        (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
    VALUES (
        gen_random_uuid(), NEW.driver_id::text,
        'Trip Assigned',   -- Swift NotificationType.tripAssigned.rawValue
        'New Trip Assigned: ' || NEW.task_id,
        'You have been assigned a trip from ' || NEW.origin
            || ' to ' || NEW.destination || ' scheduled for ' || v_scheduled,
        'trip', NEW.id::text, false, NOW()
    );
    RETURN NEW;
END;
$$;

-- ============================================================
-- END OF MIGRATION 004
-- Triggers remain attached (OR REPLACE above updates function bodies).
-- ============================================================

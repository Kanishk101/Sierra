-- ============================================================
-- Migration: Fix Driver Flow Wiring
-- Sierra Fleet Management System
-- Date: 2026-03-23
--
-- ROOT CAUSE:
-- Swift UUID.uuidString always produces UPPERCASE ("A1B2C3...").
-- PostgreSQL auth.uid()::text always produces LOWERCASE ("a1b2c3...").
-- driver_id / vehicle_id / created_by_admin_id are TEXT columns.
-- Every RLS policy did: driver_id = auth.uid()::text
-- → Always FALSE for uppercase-stored values → driver SELECT/UPDATE silently denied.
-- Driver can't read their trips, can't accept, can't submit inspections.
--
-- FIXES:
--   1. Normalize existing rows: LOWER() all TEXT UUID FK columns in trips
--   2. Rewrite trips_select_driver / trips_update_driver with LOWER()
--   3. Fix check_resource_overlap(): add PendingAcceptance+Accepted + LOWER()
--   4. Add geofences_select_driver (C-06: drivers need geofences for GeofenceMonitor)
-- ============================================================

-- ── 1. Normalize existing trip rows ──────────────────────────
-- Only text columns need case-normalization. UUID columns are already
-- case-insensitive at the type level and must not be passed to LOWER().
DO $$
DECLARE
    col RECORD;
BEGIN
    FOR col IN
        SELECT column_name, data_type
          FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'trips'
           AND column_name IN ('driver_id', 'vehicle_id', 'created_by_admin_id')
    LOOP
        IF col.data_type = 'text' THEN
            EXECUTE format(
                'UPDATE public.trips
                    SET %1$I = LOWER(%1$I)
                  WHERE %1$I IS NOT NULL
                    AND %1$I <> LOWER(%1$I)',
                col.column_name
            );
        END IF;
    END LOOP;
END;
$$;

DO $$ BEGIN RAISE NOTICE '[20260323000001] UUID normalization complete.'; END; $$;

-- ── 2. Rewrite trips driver RLS with LOWER() ─────────────────
DROP POLICY IF EXISTS trips_select_driver ON public.trips;
DROP POLICY IF EXISTS trips_update_driver ON public.trips;

CREATE POLICY trips_select_driver
    ON public.trips FOR SELECT TO authenticated
    USING (
        LOWER(COALESCE(driver_id::text, '')) = LOWER(auth.uid()::text)
        AND LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'driver'
    );

CREATE POLICY trips_update_driver
    ON public.trips FOR UPDATE TO authenticated
    USING (
        LOWER(COALESCE(driver_id::text, '')) = LOWER(auth.uid()::text)
        AND LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'driver'
    )
    WITH CHECK (
        LOWER(COALESCE(driver_id::text, '')) = LOWER(auth.uid()::text)
        AND LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'driver'
    );

-- ── 3. Fix check_resource_overlap ────────────────────────────
-- Add PendingAcceptance + Accepted to blocking statuses.
-- Use LOWER() for all TEXT UUID comparisons.
CREATE OR REPLACE FUNCTION public.check_resource_overlap(
    p_driver_id       TEXT,
    p_vehicle_id      TEXT,
    p_start           TIMESTAMPTZ,
    p_end             TIMESTAMPTZ,
    p_exclude_trip_id TEXT DEFAULT NULL
)
RETURNS TABLE(driver_conflict BOOLEAN, vehicle_conflict BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT
        EXISTS (
            SELECT 1 FROM trips
            WHERE LOWER(driver_id::text) = LOWER(p_driver_id)
              AND status IN ('Scheduled','PendingAcceptance','Accepted','Active')
              AND (p_exclude_trip_id IS NULL OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,
        EXISTS (
            SELECT 1 FROM trips
            WHERE LOWER(vehicle_id::text) = LOWER(p_vehicle_id)
              AND status IN ('Scheduled','PendingAcceptance','Accepted','Active')
              AND (p_exclude_trip_id IS NULL OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
              AND scheduled_date < p_end
              AND COALESCE(scheduled_end_date, scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

GRANT EXECUTE ON FUNCTION public.check_resource_overlap(TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.check_resource_overlap(TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,TEXT) FROM anon;

-- ── 4. Geofence SELECT for drivers (C-06) ────────────────────
DROP POLICY IF EXISTS geofences_select_driver ON public.geofences;
CREATE POLICY geofences_select_driver
    ON public.geofences FOR SELECT TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) IN ('fleetmanager', 'driver')
    );

-- ── 5. Ensure trip_status enum has PendingAcceptance (idempotent) ─
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'trip_status')
          AND enumlabel = 'PendingAcceptance'
    ) THEN
        ALTER TYPE trip_status ADD VALUE 'PendingAcceptance' AFTER 'Scheduled';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'trip_status')
          AND enumlabel = 'Accepted'
    ) THEN
        ALTER TYPE trip_status ADD VALUE 'Accepted' AFTER 'PendingAcceptance';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'trip_status')
          AND enumlabel = 'Rejected'
    ) THEN
        ALTER TYPE trip_status ADD VALUE 'Rejected' AFTER 'Accepted';
    END IF;
END;
$$;

-- ============================================================
-- END 20260323000001_fix_driver_flow_wiring
-- ============================================================

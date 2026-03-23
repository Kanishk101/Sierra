-- ============================================================
-- Migration: Fix Driver Flow Wiring
-- Sierra Fleet Management System
-- Date: 2026-03-23 (seq 001)
--
-- ROOT CAUSE:
-- Swift UUID.uuidString always produces UPPERCASE (e.g. "A1B2C3...").
-- PostgreSQL auth.uid()::text always produces LOWERCASE (e.g. "a1b2c3...").
-- driver_id and vehicle_id in trips are TEXT columns.
-- Every trips RLS policy compared driver_id = auth.uid()::text
-- which is ALWAYS FALSE for uppercase-stored UUIDs.
-- Result: drivers silently denied all SELECT and UPDATE on trips.
--
-- FIXES IN THIS MIGRATION:
--   1. Normalize: LOWER() all existing driver_id / vehicle_id in trips
--   2. Rewrite trips_select_driver and trips_update_driver with LOWER()
--   3. Fix check_resource_overlap() to include PendingAcceptance + Accepted
--      and use LOWER() for UUID comparisons
--   4. Add geofences_select_driver (C-06 — drivers need geofences to
--      populate GeofenceMonitor.register())
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Normalize: lowercase all TEXT UUID FK columns in trips
-- One-time data fix. Swift code is also updated to always
-- store UUIDs as lowercase via .lowercased().
-- ────────────────────────────────────────────────────────────

UPDATE public.trips
SET
    driver_id           = LOWER(driver_id),
    vehicle_id          = LOWER(vehicle_id),
    created_by_admin_id = LOWER(created_by_admin_id)
WHERE
    (driver_id IS NOT NULL AND driver_id <> LOWER(driver_id))
    OR (vehicle_id IS NOT NULL AND vehicle_id <> LOWER(vehicle_id))
    OR (created_by_admin_id IS NOT NULL AND created_by_admin_id <> LOWER(created_by_admin_id));

DO $$
BEGIN
    RAISE NOTICE '[migration 20260323000001] UUID normalization complete.';
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 2. Rewrite trips RLS policies to use LOWER() comparison
-- LOWER(driver_id) = auth.uid()::text is always a
-- lowercase-to-lowercase comparison after the data fix above.
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS trips_select_driver ON public.trips;
DROP POLICY IF EXISTS trips_update_driver ON public.trips;

-- Drivers: read their assigned trips
CREATE POLICY trips_select_driver
    ON public.trips FOR SELECT TO authenticated
    USING (
        LOWER(COALESCE(driver_id, '')) = LOWER(auth.uid()::text)
        AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'driver'
    );

-- Drivers: update acceptance fields + inspection IDs + mileage on their own trips
CREATE POLICY trips_update_driver
    ON public.trips FOR UPDATE TO authenticated
    USING (
        LOWER(COALESCE(driver_id, '')) = LOWER(auth.uid()::text)
        AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'driver'
    )
    WITH CHECK (
        LOWER(COALESCE(driver_id, '')) = LOWER(auth.uid()::text)
        AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'driver'
    );

-- ────────────────────────────────────────────────────────────
-- 3. Fix check_resource_overlap:
--    a) Add PendingAcceptance and Accepted to blocking statuses
--       (a driver with an accepted trip cannot be double-booked)
--    b) Use LOWER() for all TEXT UUID comparisons
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.check_resource_overlap(
    p_driver_id       TEXT,
    p_vehicle_id      TEXT,
    p_start           TIMESTAMPTZ,
    p_end             TIMESTAMPTZ,
    p_exclude_trip_id TEXT DEFAULT NULL
)
RETURNS TABLE(
    driver_conflict  BOOLEAN,
    vehicle_conflict BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        EXISTS (
            SELECT 1
              FROM trips
             WHERE LOWER(driver_id) = LOWER(p_driver_id)
               AND status IN ('Scheduled', 'PendingAcceptance', 'Accepted', 'Active')
               AND (p_exclude_trip_id IS NULL
                    OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
               AND scheduled_date < p_end
               AND COALESCE(scheduled_end_date,
                            scheduled_date + INTERVAL '24 hours') > p_start
        ) AS driver_conflict,

        EXISTS (
            SELECT 1
              FROM trips
             WHERE LOWER(vehicle_id) = LOWER(p_vehicle_id)
               AND status IN ('Scheduled', 'PendingAcceptance', 'Accepted', 'Active')
               AND (p_exclude_trip_id IS NULL
                    OR LOWER(id::text) <> LOWER(p_exclude_trip_id))
               AND scheduled_date < p_end
               AND COALESCE(scheduled_end_date,
                            scheduled_date + INTERVAL '24 hours') > p_start
        ) AS vehicle_conflict;
$$;

GRANT EXECUTE ON FUNCTION public.check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT
) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.check_resource_overlap(
    TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT
) FROM anon;

-- ────────────────────────────────────────────────────────────
-- 4. Geofence SELECT policy for drivers (C-06)
-- Without this, AppDataStore.geofences is always empty for
-- driver sessions → GeofenceMonitor.register() gets [] →
-- no CLCircularRegions registered → zero geofence events.
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS geofences_select_driver ON public.geofences;

CREATE POLICY geofences_select_driver
    ON public.geofences FOR SELECT TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid())
        IN ('fleetManager', 'driver')
    );

-- ============================================================
-- END OF MIGRATION 20260323000001_fix_driver_flow_wiring
-- ============================================================

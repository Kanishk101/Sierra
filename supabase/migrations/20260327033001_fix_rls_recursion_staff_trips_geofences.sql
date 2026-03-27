-- Hotfix: restore non-recursive RLS role checks after rollback
-- Date: 2026-03-27
--
-- Symptom:
--   42P17 "infinite recursion detected in policy for relation staff_members"
--   when loading staff/trips/geofences (and dependent screens).
--
-- Approach:
--   Use SECURITY DEFINER helper current_staff_role() instead of inline
--   subqueries against public.staff_members inside policy expressions.

CREATE OR REPLACE FUNCTION public.current_staff_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT LOWER(sm.role::text)
      FROM public.staff_members sm
     WHERE sm.id = auth.uid()
     LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.current_staff_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_staff_role() TO authenticated;

-- ------------------------------------------------------------------
-- staff_members
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS staff_members_select_own ON public.staff_members;
DROP POLICY IF EXISTS staff_members_select_admin ON public.staff_members;
DROP POLICY IF EXISTS staff_members_insert_admin ON public.staff_members;
DROP POLICY IF EXISTS staff_members_update_admin ON public.staff_members;
DROP POLICY IF EXISTS staff_members_delete_admin ON public.staff_members;
DROP POLICY IF EXISTS staff_members_update_own_avail ON public.staff_members;

CREATE POLICY staff_members_select_own
    ON public.staff_members FOR SELECT TO authenticated
    USING (id = auth.uid());

CREATE POLICY staff_members_select_admin
    ON public.staff_members FOR SELECT TO authenticated
    USING (public.current_staff_role() = 'fleetmanager');

CREATE POLICY staff_members_insert_admin
    ON public.staff_members FOR INSERT TO authenticated
    WITH CHECK (public.current_staff_role() = 'fleetmanager');

CREATE POLICY staff_members_update_admin
    ON public.staff_members FOR UPDATE TO authenticated
    USING (public.current_staff_role() = 'fleetmanager')
    WITH CHECK (public.current_staff_role() = 'fleetmanager');

CREATE POLICY staff_members_delete_admin
    ON public.staff_members FOR DELETE TO authenticated
    USING (public.current_staff_role() = 'fleetmanager');

CREATE POLICY staff_members_update_own_avail
    ON public.staff_members FOR UPDATE TO authenticated
    USING  (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- ------------------------------------------------------------------
-- vehicles
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS vehicles_insert_admin ON public.vehicles;
DROP POLICY IF EXISTS vehicles_update_admin ON public.vehicles;
DROP POLICY IF EXISTS vehicles_delete_admin ON public.vehicles;

CREATE POLICY vehicles_insert_admin
    ON public.vehicles FOR INSERT TO authenticated
    WITH CHECK (public.current_staff_role() = 'fleetmanager');

CREATE POLICY vehicles_update_admin
    ON public.vehicles FOR UPDATE TO authenticated
    USING (public.current_staff_role() = 'fleetmanager')
    WITH CHECK (public.current_staff_role() = 'fleetmanager');

CREATE POLICY vehicles_delete_admin
    ON public.vehicles FOR DELETE TO authenticated
    USING (public.current_staff_role() = 'fleetmanager');

-- ------------------------------------------------------------------
-- geofences
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS geofences_select_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_insert_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_update_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_delete_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_select_driver ON public.geofences;

CREATE POLICY geofences_select_admin
    ON public.geofences FOR SELECT TO authenticated
    USING (public.current_staff_role() = 'fleetmanager');

CREATE POLICY geofences_insert_admin
    ON public.geofences FOR INSERT TO authenticated
    WITH CHECK (public.current_staff_role() = 'fleetmanager');

CREATE POLICY geofences_update_admin
    ON public.geofences FOR UPDATE TO authenticated
    USING (public.current_staff_role() = 'fleetmanager')
    WITH CHECK (public.current_staff_role() = 'fleetmanager');

CREATE POLICY geofences_delete_admin
    ON public.geofences FOR DELETE TO authenticated
    USING (public.current_staff_role() = 'fleetmanager');

CREATE POLICY geofences_select_driver
    ON public.geofences FOR SELECT TO authenticated
    USING (public.current_staff_role() IN ('fleetmanager', 'driver'));

-- ------------------------------------------------------------------
-- trips
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS trips_all_admin ON public.trips;
DROP POLICY IF EXISTS trips_select_driver ON public.trips;
DROP POLICY IF EXISTS trips_update_driver ON public.trips;
DROP POLICY IF EXISTS trips_select_maintenance ON public.trips;

CREATE POLICY trips_all_admin
    ON public.trips FOR ALL TO authenticated
    USING (public.current_staff_role() = 'fleetmanager')
    WITH CHECK (public.current_staff_role() = 'fleetmanager');

CREATE POLICY trips_select_driver
    ON public.trips FOR SELECT TO authenticated
    USING (
        driver_id::text = auth.uid()::text
        AND public.current_staff_role() = 'driver'
    );

CREATE POLICY trips_update_driver
    ON public.trips FOR UPDATE TO authenticated
    USING (
        driver_id::text = auth.uid()::text
        AND public.current_staff_role() = 'driver'
    )
    WITH CHECK (
        driver_id::text = auth.uid()::text
        AND public.current_staff_role() = 'driver'
    );

CREATE POLICY trips_select_maintenance
    ON public.trips FOR SELECT TO authenticated
    USING (public.current_staff_role() = 'maintenancepersonnel');

-- ------------------------------------------------------------------
-- vehicle_location_history
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS vehicle_location_history_select_fleet_or_driver
    ON public.vehicle_location_history;
DROP POLICY IF EXISTS vehicle_location_history_insert_driver_or_fleet
    ON public.vehicle_location_history;

CREATE POLICY vehicle_location_history_select_fleet_or_driver
    ON public.vehicle_location_history
    FOR SELECT
    TO authenticated
    USING (
        public.current_staff_role() = 'fleetmanager'
        OR driver_id = auth.uid()
    );

CREATE POLICY vehicle_location_history_insert_driver_or_fleet
    ON public.vehicle_location_history
    FOR INSERT
    TO authenticated
    WITH CHECK (
        driver_id = auth.uid()
        AND public.current_staff_role() IN ('driver', 'fleetmanager')
    );

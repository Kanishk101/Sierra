-- Revert migration: 20260327020001_fix_rls_infinite_recursion_staff_members
-- Note: This intentionally restores pre-hotfix policy expressions.
-- It may reintroduce 42P17 recursion if policy evaluation traverses staff_members.

-- ------------------------------------------------------------------
-- staff_members (restore pre-20260327020001 policy bodies)
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
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY staff_members_insert_admin
    ON public.staff_members FOR INSERT TO authenticated
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY staff_members_update_admin
    ON public.staff_members FOR UPDATE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    )
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY staff_members_delete_admin
    ON public.staff_members FOR DELETE TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY staff_members_update_own_avail
    ON public.staff_members FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- ------------------------------------------------------------------
-- vehicles (restore pre-20260327020001 policy bodies)
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS vehicles_insert_admin ON public.vehicles;
DROP POLICY IF EXISTS vehicles_update_admin ON public.vehicles;
DROP POLICY IF EXISTS vehicles_delete_admin ON public.vehicles;

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

-- ------------------------------------------------------------------
-- geofences (restore pre-20260327020001 policy bodies)
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS geofences_select_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_insert_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_update_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_delete_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_select_driver ON public.geofences;

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

CREATE POLICY geofences_select_driver
    ON public.geofences FOR SELECT TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) IN ('fleetmanager', 'driver')
    );

-- ------------------------------------------------------------------
-- trips (restore pre-20260327020001 policy bodies)
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS trips_all_admin ON public.trips;
DROP POLICY IF EXISTS trips_select_driver ON public.trips;
DROP POLICY IF EXISTS trips_update_driver ON public.trips;
DROP POLICY IF EXISTS trips_select_maintenance ON public.trips;

CREATE POLICY trips_all_admin
    ON public.trips FOR ALL TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    )
    WITH CHECK (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'fleetmanager'
    );

CREATE POLICY trips_select_driver
    ON public.trips FOR SELECT TO authenticated
    USING (
        driver_id::text = auth.uid()::text
        AND LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'driver'
    );

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

CREATE POLICY trips_select_maintenance
    ON public.trips FOR SELECT TO authenticated
    USING (
        LOWER((SELECT role::text FROM public.staff_members WHERE id = auth.uid())) = 'maintenancepersonnel'
    );

-- ------------------------------------------------------------------
-- vehicle_location_history (restore pre-20260327020001 policy bodies)
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
        (
            SELECT sm.role::text
              FROM public.staff_members sm
             WHERE sm.id = auth.uid()
        ) = 'fleetManager'
        OR driver_id = auth.uid()
    );

CREATE POLICY vehicle_location_history_insert_driver_or_fleet
    ON public.vehicle_location_history
    FOR INSERT
    TO authenticated
    WITH CHECK (
        driver_id = auth.uid()
        AND (
            SELECT sm.role::text
              FROM public.staff_members sm
             WHERE sm.id = auth.uid()
        ) IN ('driver', 'fleetManager')
    );

-- ------------------------------------------------------------------
-- Remove helper introduced by hotfix (after policy replacement)
-- ------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.current_staff_role() FROM PUBLIC;
DROP FUNCTION IF EXISTS public.current_staff_role();

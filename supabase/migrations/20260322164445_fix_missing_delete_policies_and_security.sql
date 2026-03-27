
-- 1. fuel_logs: Add DELETE policy
CREATE POLICY fl_delete ON public.fuel_logs
    FOR DELETE TO authenticated
    USING (
        (driver_id = ( SELECT auth.uid() AS uid))
        OR (get_my_role() = 'fleetManager')
    );

-- 2. parts_used: Add DELETE policy
CREATE POLICY parts_delete ON public.parts_used
    FOR DELETE TO authenticated
    USING (
        (get_my_role() = ANY (ARRAY['fleetManager'::text, 'maintenancePersonnel'::text]))
    );

-- 3. maintenance_tasks: Tighten INSERT to fleetManager only
DROP POLICY IF EXISTS mt_insert ON public.maintenance_tasks;
CREATE POLICY mt_insert ON public.maintenance_tasks
    FOR INSERT TO authenticated
    WITH CHECK (get_my_role() = 'fleetManager');
;

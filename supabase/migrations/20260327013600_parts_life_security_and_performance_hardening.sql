-- Hardening for parts-life automation:
-- 1) Fix mutable search_path warnings on trigger functions.
-- 2) Add explicit RLS policy for service_role on ledger table.
-- 3) Add missing FK indexes flagged by performance advisor.
-- 4) Optimize RLS policy auth call with initplan-friendly pattern.

-- 1) Secure function search_path.
CREATE OR REPLACE FUNCTION public.enforce_maintenance_task_creation_rules()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_inspection_type TEXT;
BEGIN
    IF NEW.task_type = 'Scheduled' THEN
        IF NEW.request_origin <> 'parts_life_auto' THEN
            RAISE EXCEPTION
                'Scheduled service requests can only be created by parts-life automation.';
        END IF;
    END IF;

    IF NEW.task_type = 'Inspection Defect' THEN
        IF btrim(COALESCE(NEW.task_description, '')) = '' THEN
            RAISE EXCEPTION
                'Inspection defect request requires a non-empty task_description.';
        END IF;

        IF NEW.source_inspection_id IS NOT NULL THEN
            SELECT i.type::TEXT
            INTO v_inspection_type
            FROM public.vehicle_inspections i
            WHERE i.id = NEW.source_inspection_id;

            IF v_inspection_type IS NULL THEN
                RAISE EXCEPTION 'Referenced inspection does not exist.';
            END IF;

            IF v_inspection_type NOT IN ('Pre-Trip', 'Post-Trip') THEN
                RAISE EXCEPTION 'Inspection defect requests are only allowed from pre/post trip inspections.';
            END IF;
        END IF;

        NEW.request_origin := 'inspection_report';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_vehicle_part_life_on_service_completion()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NEW.task_type = 'Scheduled'
       AND NEW.status = 'Completed'
       AND (OLD.status IS DISTINCT FROM NEW.status) THEN

        UPDATE public.vehicle_part_life_profiles p
        SET
            remaining_km = p.service_interval_km,
            service_cycle_count = p.service_cycle_count + 1,
            last_service_task_id = NEW.id,
            updated_at = now()
        WHERE p.vehicle_id = NEW.vehicle_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.touch_vehicle_part_life_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- 2) Explicit service-role-only policy for ledger (clears RLS-no-policy lint).
DROP POLICY IF EXISTS vehicle_trip_distance_ledger_service_role_all ON public.vehicle_trip_distance_ledger;
CREATE POLICY vehicle_trip_distance_ledger_service_role_all
ON public.vehicle_trip_distance_ledger
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 3) Missing FK indexes.
CREATE INDEX IF NOT EXISTS idx_mt_source_trip_id
    ON public.maintenance_tasks(source_trip_id);

CREATE INDEX IF NOT EXISTS idx_vpl_last_processed_trip_id
    ON public.vehicle_part_life_profiles(last_processed_trip_id);

CREATE INDEX IF NOT EXISTS idx_vpl_last_service_task_id
    ON public.vehicle_part_life_profiles(last_service_task_id);

-- 4) Initplan-friendly RLS policy shape.
DROP POLICY IF EXISTS vehicle_part_life_profiles_update_fleet_manager ON public.vehicle_part_life_profiles;
CREATE POLICY vehicle_part_life_profiles_update_fleet_manager
ON public.vehicle_part_life_profiles
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.staff_members sm
        WHERE sm.id = (SELECT auth.uid()) AND sm.role = 'fleetManager'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.staff_members sm
        WHERE sm.id = (SELECT auth.uid()) AND sm.role = 'fleetManager'
    )
);;

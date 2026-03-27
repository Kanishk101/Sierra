-- Vehicle parts life depletion + automatic service request creation
-- based on trip distance consumption.

-- 1) Vehicle parts life profile (one row per vehicle).
CREATE TABLE IF NOT EXISTS public.vehicle_part_life_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL UNIQUE REFERENCES public.vehicles(id) ON DELETE CASCADE,
    service_interval_km NUMERIC(12,2) NOT NULL DEFAULT 10000,
    remaining_km NUMERIC(12,2) NOT NULL DEFAULT 10000,
    total_consumed_km NUMERIC(12,2) NOT NULL DEFAULT 0,
    depletion_threshold_km NUMERIC(12,2) NOT NULL DEFAULT 0,
    service_cycle_count INTEGER NOT NULL DEFAULT 0,
    last_service_task_id UUID NULL REFERENCES public.maintenance_tasks(id) ON DELETE SET NULL,
    last_processed_trip_id UUID NULL REFERENCES public.trips(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT vehicle_part_life_profiles_service_interval_positive CHECK (service_interval_km > 0),
    CONSTRAINT vehicle_part_life_profiles_remaining_non_negative CHECK (remaining_km >= 0),
    CONSTRAINT vehicle_part_life_profiles_consumed_non_negative CHECK (total_consumed_km >= 0),
    CONSTRAINT vehicle_part_life_profiles_threshold_non_negative CHECK (depletion_threshold_km >= 0)
);

CREATE INDEX IF NOT EXISTS idx_vehicle_part_life_profiles_vehicle_id
    ON public.vehicle_part_life_profiles(vehicle_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_part_life_profiles_updated_at
    ON public.vehicle_part_life_profiles(updated_at DESC);

-- 2) Ledger for idempotent trip-distance processing (one row per trip).
CREATE TABLE IF NOT EXISTS public.vehicle_trip_distance_ledger (
    trip_id UUID PRIMARY KEY REFERENCES public.trips(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    distance_km NUMERIC(12,2) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT vehicle_trip_distance_ledger_distance_non_negative CHECK (distance_km >= 0)
);

CREATE INDEX IF NOT EXISTS idx_vehicle_trip_distance_ledger_vehicle_id
    ON public.vehicle_trip_distance_ledger(vehicle_id);

-- 3) Track origin for maintenance requests and source trip for auto-service.
ALTER TABLE public.maintenance_tasks
    ADD COLUMN IF NOT EXISTS request_origin TEXT NOT NULL DEFAULT 'unknown',
    ADD COLUMN IF NOT EXISTS source_trip_id UUID NULL REFERENCES public.trips(id) ON DELETE SET NULL;

UPDATE public.maintenance_tasks
SET request_origin = CASE
    WHEN task_type = 'Scheduled' THEN 'manual_service'
    WHEN task_type = 'Inspection Defect' THEN 'inspection_report'
    ELSE 'legacy'
END
WHERE request_origin = 'unknown' OR request_origin IS NULL;

-- 4) Enforce creation rules:
--    - Scheduled service tasks: only from parts-life automation.
--    - Inspection defect tasks: must include description.
CREATE OR REPLACE FUNCTION public.enforce_maintenance_task_creation_rules()
RETURNS trigger
LANGUAGE plpgsql
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

DROP TRIGGER IF EXISTS trg_enforce_maintenance_task_creation_rules ON public.maintenance_tasks;
CREATE TRIGGER trg_enforce_maintenance_task_creation_rules
BEFORE INSERT OR UPDATE ON public.maintenance_tasks
FOR EACH ROW
EXECUTE FUNCTION public.enforce_maintenance_task_creation_rules();

-- 5) Reset parts-life remaining km once scheduled service task is completed.
CREATE OR REPLACE FUNCTION public.reset_vehicle_part_life_on_service_completion()
RETURNS trigger
LANGUAGE plpgsql
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

DROP TRIGGER IF EXISTS trg_reset_vehicle_part_life_on_service_completion ON public.maintenance_tasks;
CREATE TRIGGER trg_reset_vehicle_part_life_on_service_completion
AFTER UPDATE ON public.maintenance_tasks
FOR EACH ROW
EXECUTE FUNCTION public.reset_vehicle_part_life_on_service_completion();

-- 6) Keep updated_at fresh.
CREATE OR REPLACE FUNCTION public.touch_vehicle_part_life_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_vehicle_part_life_updated_at ON public.vehicle_part_life_profiles;
CREATE TRIGGER trg_touch_vehicle_part_life_updated_at
BEFORE UPDATE ON public.vehicle_part_life_profiles
FOR EACH ROW
EXECUTE FUNCTION public.touch_vehicle_part_life_updated_at();

-- 7) Seed profiles for existing vehicles.
INSERT INTO public.vehicle_part_life_profiles (vehicle_id)
SELECT v.id
FROM public.vehicles v
LEFT JOIN public.vehicle_part_life_profiles p ON p.vehicle_id = v.id
WHERE p.vehicle_id IS NULL;

-- 8) RLS for profile reads in app.
ALTER TABLE public.vehicle_part_life_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vehicle_part_life_profiles_select_authenticated ON public.vehicle_part_life_profiles;
CREATE POLICY vehicle_part_life_profiles_select_authenticated
ON public.vehicle_part_life_profiles
FOR SELECT
TO authenticated
USING (true);

-- Only fleet managers can tune interval/threshold manually if needed.
DROP POLICY IF EXISTS vehicle_part_life_profiles_update_fleet_manager ON public.vehicle_part_life_profiles;
CREATE POLICY vehicle_part_life_profiles_update_fleet_manager
ON public.vehicle_part_life_profiles
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.staff_members sm
        WHERE sm.id = auth.uid() AND sm.role = 'fleetManager'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.staff_members sm
        WHERE sm.id = auth.uid() AND sm.role = 'fleetManager'
    )
);

-- Keep ledger private to service paths.
ALTER TABLE public.vehicle_trip_distance_ledger ENABLE ROW LEVEL SECURITY;;

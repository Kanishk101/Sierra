-- Authoritative inventory catalog for maintenance parts

CREATE TABLE IF NOT EXISTS public.inventory_parts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    part_name text NOT NULL,
    part_number text,
    supplier text,
    category text,
    unit text NOT NULL DEFAULT 'pcs',
    current_quantity integer NOT NULL DEFAULT 0 CHECK (current_quantity >= 0),
    reorder_level integer NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    on_order_quantity integer NOT NULL DEFAULT 0 CHECK (on_order_quantity >= 0),
    expected_arrival_at timestamptz,
    compatible_vehicle_ids uuid[] NOT NULL DEFAULT '{}',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_parts_name
    ON public.inventory_parts (lower(part_name));

CREATE INDEX IF NOT EXISTS idx_inventory_parts_number
    ON public.inventory_parts (lower(coalesce(part_number, '')));

CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_parts_unique_name_number
    ON public.inventory_parts (lower(part_name), lower(coalesce(part_number, '')));

-- Keep updated_at fresh
CREATE OR REPLACE FUNCTION public.fn_inventory_parts_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_parts_set_updated_at ON public.inventory_parts;
CREATE TRIGGER trg_inventory_parts_set_updated_at
    BEFORE UPDATE ON public.inventory_parts
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_inventory_parts_set_updated_at();

-- Seed catalog from historical requests (if missing)
INSERT INTO public.inventory_parts (part_name, part_number, supplier, category, current_quantity, on_order_quantity, compatible_vehicle_ids)
SELECT
    r.part_name,
    r.part_number,
    max(r.supplier),
    'General',
    max(coalesce(r.quantity_available, 0)),
    max(coalesce(r.quantity_on_order, 0)),
    COALESCE(array_agg(DISTINCT t.vehicle_id) FILTER (WHERE t.vehicle_id IS NOT NULL), '{}')
FROM public.spare_parts_requests r
LEFT JOIN public.maintenance_tasks t ON t.id = r.maintenance_task_id
WHERE NOT EXISTS (
    SELECT 1
    FROM public.inventory_parts p
    WHERE lower(p.part_name) = lower(r.part_name)
      AND lower(coalesce(p.part_number, '')) = lower(coalesce(r.part_number, ''))
)
GROUP BY r.part_name, r.part_number;

-- Seed from consumed parts too (if missing)
INSERT INTO public.inventory_parts (part_name, part_number, supplier, category, current_quantity, compatible_vehicle_ids)
SELECT
    pu.part_name,
    pu.part_number,
    max(pu.supplier),
    'General',
    0,
    COALESCE(array_agg(DISTINCT wo.vehicle_id) FILTER (WHERE wo.vehicle_id IS NOT NULL), '{}')
FROM public.parts_used pu
LEFT JOIN public.work_orders wo ON wo.id = pu.work_order_id
WHERE NOT EXISTS (
    SELECT 1
    FROM public.inventory_parts p
    WHERE lower(p.part_name) = lower(pu.part_name)
      AND lower(coalesce(p.part_number, '')) = lower(coalesce(pu.part_number, ''))
)
GROUP BY pu.part_name, pu.part_number;

-- RLS
ALTER TABLE public.inventory_parts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inventory_parts_select_authenticated ON public.inventory_parts;
DROP POLICY IF EXISTS inventory_parts_insert_admin ON public.inventory_parts;
DROP POLICY IF EXISTS inventory_parts_update_admin ON public.inventory_parts;
DROP POLICY IF EXISTS inventory_parts_delete_admin ON public.inventory_parts;

CREATE POLICY inventory_parts_select_authenticated
    ON public.inventory_parts
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY inventory_parts_insert_admin
    ON public.inventory_parts
    FOR INSERT
    TO authenticated
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager'
    );

CREATE POLICY inventory_parts_update_admin
    ON public.inventory_parts
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager'
    )
    WITH CHECK (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager'
    );

CREATE POLICY inventory_parts_delete_admin
    ON public.inventory_parts
    FOR DELETE
    TO authenticated
    USING (
        (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager'
    );

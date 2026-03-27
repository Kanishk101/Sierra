
-- ══════════════════════════════════════════════════════════════
-- RLS POLICIES — VEHICLE LAYER
-- Tables: vehicles, vehicle_documents
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- vehicles
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Driver: read own assigned vehicle" ON public.vehicles;
DROP POLICY IF EXISTS "Maintenance: read all vehicles" ON public.vehicles;

CREATE POLICY "Admin: full access to vehicles"
ON public.vehicles
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Drivers can only see the vehicle assigned to them
CREATE POLICY "Driver: read own assigned vehicle"
ON public.vehicles
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND assigned_driver_id = auth.uid()
);

-- Maintenance personnel can see all vehicles (needed for task context)
CREATE POLICY "Maintenance: read all vehicles"
ON public.vehicles
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'maintenancePersonnel');

-- ─────────────────────────────────────────────
-- vehicle_documents
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to vehicle_documents" ON public.vehicle_documents;
DROP POLICY IF EXISTS "Driver: read documents for assigned vehicle" ON public.vehicle_documents;
DROP POLICY IF EXISTS "Maintenance: read all vehicle documents" ON public.vehicle_documents;

CREATE POLICY "Admin: full access to vehicle_documents"
ON public.vehicle_documents
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Driver sees docs only for their currently assigned vehicle
CREATE POLICY "Driver: read documents for assigned vehicle"
ON public.vehicle_documents
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND vehicle_id IN (
    SELECT id FROM public.vehicles WHERE assigned_driver_id = auth.uid()
  )
);

-- Maintenance sees all vehicle docs (needed for repair context)
CREATE POLICY "Maintenance: read all vehicle documents"
ON public.vehicle_documents
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'maintenancePersonnel');
;

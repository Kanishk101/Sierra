
-- ══════════════════════════════════════════════════════════════
-- RLS POLICIES — OPERATIONS LAYER
-- Tables: trips, fuel_logs, vehicle_inspections,
--         proof_of_deliveries, emergency_alerts
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- trips
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to trips" ON public.trips;
DROP POLICY IF EXISTS "Driver: read and update own trips" ON public.trips;

CREATE POLICY "Admin: full access to trips"
ON public.trips
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Drivers can read trips assigned to them and update them (start/end trip, update status)
CREATE POLICY "Driver: read own trips"
ON public.trips
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

CREATE POLICY "Driver: update own trips"
ON public.trips
FOR UPDATE
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
)
WITH CHECK (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

-- ─────────────────────────────────────────────
-- fuel_logs
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all fuel_logs" ON public.fuel_logs;
DROP POLICY IF EXISTS "Driver: full access to own fuel_logs" ON public.fuel_logs;
DROP POLICY IF EXISTS "Maintenance: read all fuel_logs" ON public.fuel_logs;

CREATE POLICY "Admin: read all fuel_logs"
ON public.fuel_logs
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

-- Drivers can create and read their own fuel logs
CREATE POLICY "Driver: read own fuel_logs"
ON public.fuel_logs
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

CREATE POLICY "Driver: insert own fuel_logs"
ON public.fuel_logs
FOR INSERT
TO authenticated
WITH CHECK (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

-- Maintenance can read fuel logs for vehicle history context
CREATE POLICY "Maintenance: read all fuel_logs"
ON public.fuel_logs
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'maintenancePersonnel');

-- ─────────────────────────────────────────────
-- vehicle_inspections
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all vehicle_inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Driver: insert and read own inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Maintenance: read all vehicle_inspections" ON public.vehicle_inspections;

CREATE POLICY "Admin: read all vehicle_inspections"
ON public.vehicle_inspections
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

CREATE POLICY "Driver: read own vehicle_inspections"
ON public.vehicle_inspections
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

CREATE POLICY "Driver: insert own vehicle_inspections"
ON public.vehicle_inspections
FOR INSERT
TO authenticated
WITH CHECK (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

-- Maintenance reads inspections to understand defect history before repair
CREATE POLICY "Maintenance: read all vehicle_inspections"
ON public.vehicle_inspections
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'maintenancePersonnel');

-- ─────────────────────────────────────────────
-- proof_of_deliveries
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all proof_of_deliveries" ON public.proof_of_deliveries;
DROP POLICY IF EXISTS "Driver: insert and read own proof_of_deliveries" ON public.proof_of_deliveries;

CREATE POLICY "Admin: read all proof_of_deliveries"
ON public.proof_of_deliveries
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

CREATE POLICY "Driver: read own proof_of_deliveries"
ON public.proof_of_deliveries
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

CREATE POLICY "Driver: insert own proof_of_deliveries"
ON public.proof_of_deliveries
FOR INSERT
TO authenticated
WITH CHECK (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

-- ─────────────────────────────────────────────
-- emergency_alerts
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to emergency_alerts" ON public.emergency_alerts;
DROP POLICY IF EXISTS "Driver: insert and read own emergency_alerts" ON public.emergency_alerts;

-- Admin needs full access to acknowledge and resolve alerts
CREATE POLICY "Admin: full access to emergency_alerts"
ON public.emergency_alerts
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Drivers can trigger (insert) alerts and see their own
CREATE POLICY "Driver: read own emergency_alerts"
ON public.emergency_alerts
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

CREATE POLICY "Driver: insert emergency_alerts"
ON public.emergency_alerts
FOR INSERT
TO authenticated
WITH CHECK (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);
;

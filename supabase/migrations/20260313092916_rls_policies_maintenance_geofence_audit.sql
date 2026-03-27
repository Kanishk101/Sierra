
-- ══════════════════════════════════════════════════════════════
-- RLS POLICIES — MAINTENANCE, GEOFENCING & AUDIT LAYERS
-- Tables: maintenance_tasks, work_orders, parts_used,
--         maintenance_records, geofences, geofence_events,
--         activity_logs
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- maintenance_tasks
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to maintenance_tasks" ON public.maintenance_tasks;
DROP POLICY IF EXISTS "Maintenance: read own assigned tasks" ON public.maintenance_tasks;

CREATE POLICY "Admin: full access to maintenance_tasks"
ON public.maintenance_tasks
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Maintenance personnel see tasks assigned to them
CREATE POLICY "Maintenance: read own assigned tasks"
ON public.maintenance_tasks
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND assigned_to_id = auth.uid()
);

-- Maintenance can update status on their own tasks
CREATE POLICY "Maintenance: update own assigned tasks"
ON public.maintenance_tasks
FOR UPDATE
TO authenticated
USING (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND assigned_to_id = auth.uid()
)
WITH CHECK (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND assigned_to_id = auth.uid()
);

-- ─────────────────────────────────────────────
-- work_orders
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all work_orders" ON public.work_orders;
DROP POLICY IF EXISTS "Maintenance: full access to own work_orders" ON public.work_orders;

CREATE POLICY "Admin: read all work_orders"
ON public.work_orders
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

-- Maintenance can read and update work orders assigned to them
CREATE POLICY "Maintenance: read own work_orders"
ON public.work_orders
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND assigned_to_id = auth.uid()
);

CREATE POLICY "Maintenance: update own work_orders"
ON public.work_orders
FOR UPDATE
TO authenticated
USING (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND assigned_to_id = auth.uid()
)
WITH CHECK (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND assigned_to_id = auth.uid()
);

-- ─────────────────────────────────────────────
-- parts_used
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all parts_used" ON public.parts_used;
DROP POLICY IF EXISTS "Maintenance: full access to own parts_used" ON public.parts_used;

CREATE POLICY "Admin: read all parts_used"
ON public.parts_used
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

-- Maintenance can fully manage parts on their own work orders
CREATE POLICY "Maintenance: manage parts on own work_orders"
ON public.parts_used
FOR ALL
TO authenticated
USING (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND work_order_id IN (
    SELECT id FROM public.work_orders WHERE assigned_to_id = auth.uid()
  )
)
WITH CHECK (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND work_order_id IN (
    SELECT id FROM public.work_orders WHERE assigned_to_id = auth.uid()
  )
);

-- ─────────────────────────────────────────────
-- maintenance_records
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Maintenance: read and insert own records" ON public.maintenance_records;

CREATE POLICY "Admin: read all maintenance_records"
ON public.maintenance_records
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

CREATE POLICY "Maintenance: read own maintenance_records"
ON public.maintenance_records
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND performed_by_id = auth.uid()
);

CREATE POLICY "Maintenance: insert own maintenance_records"
ON public.maintenance_records
FOR INSERT
TO authenticated
WITH CHECK (
  public.sierra_user_role() = 'maintenancePersonnel'
  AND performed_by_id = auth.uid()
);

-- ─────────────────────────────────────────────
-- geofences
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: full access to geofences" ON public.geofences;
DROP POLICY IF EXISTS "Driver: read active geofences" ON public.geofences;
DROP POLICY IF EXISTS "Maintenance: read all geofences" ON public.geofences;

CREATE POLICY "Admin: full access to geofences"
ON public.geofences
FOR ALL
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- Drivers need active geofence boundaries for MapKit monitoring
CREATE POLICY "Driver: read active geofences"
ON public.geofences
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND is_active = true
);

CREATE POLICY "Maintenance: read all geofences"
ON public.geofences
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'maintenancePersonnel');

-- ─────────────────────────────────────────────
-- geofence_events
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all geofence_events" ON public.geofence_events;
DROP POLICY IF EXISTS "Driver: read own geofence_events" ON public.geofence_events;

CREATE POLICY "Admin: read all geofence_events"
ON public.geofence_events
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

CREATE POLICY "Driver: read own geofence_events"
ON public.geofence_events
FOR SELECT
TO authenticated
USING (
  public.sierra_user_role() = 'driver'
  AND driver_id = auth.uid()
);

-- Backend (service_role) inserts geofence events — no authenticated INSERT policy needed

-- ─────────────────────────────────────────────
-- activity_logs
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Admin: read all activity_logs" ON public.activity_logs;
DROP POLICY IF EXISTS "Admin: mark activity_logs as read" ON public.activity_logs;

-- Admin reads the full audit trail
CREATE POLICY "Admin: read all activity_logs"
ON public.activity_logs
FOR SELECT
TO authenticated
USING (public.sierra_user_role() = 'fleetManager');

-- Admin can mark logs as read (is_read flag)
CREATE POLICY "Admin: update activity_logs read status"
ON public.activity_logs
FOR UPDATE
TO authenticated
USING (public.sierra_user_role() = 'fleetManager')
WITH CHECK (public.sierra_user_role() = 'fleetManager');

-- No INSERT policy for authenticated users — activity_logs are written server-side only
-- (Edge Functions / DB triggers use service_role which bypasses RLS)
;

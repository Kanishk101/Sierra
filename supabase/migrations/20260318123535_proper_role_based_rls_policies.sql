
-- ============================================================
-- Replace all blanket "public ALL" policies with role-scoped ones.
-- Roles: 'fleetManager' | 'driver' | 'maintenancePersonnel'
-- get_my_role() is SECURITY DEFINER — safe to use in policies.
-- All policies require authenticated session (blocks anon).
-- ============================================================

-- ── vehicles ─────────────────────────────────────────────────
DROP POLICY IF EXISTS vehicles_all ON vehicles;
CREATE POLICY vehicles_select ON vehicles FOR SELECT TO authenticated USING (true);
CREATE POLICY vehicles_insert ON vehicles FOR INSERT TO authenticated WITH CHECK (get_my_role()::text = 'fleetManager');
CREATE POLICY vehicles_update ON vehicles FOR UPDATE TO authenticated USING (get_my_role()::text = 'fleetManager');
CREATE POLICY vehicles_delete ON vehicles FOR DELETE TO authenticated USING (get_my_role()::text = 'fleetManager');

-- ── trips ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS trips_all ON trips;
-- Fleet manager sees all; driver sees own trips
CREATE POLICY trips_select ON trips FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager'
  OR driver_id = auth.uid()
  OR get_my_role()::text = 'maintenancePersonnel'
);
CREATE POLICY trips_insert ON trips FOR INSERT TO authenticated WITH CHECK (get_my_role()::text = 'fleetManager');
-- Fleet manager full update; driver can update own (start/end/mileage)
CREATE POLICY trips_update ON trips FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);
CREATE POLICY trips_delete ON trips FOR DELETE TO authenticated USING (get_my_role()::text = 'fleetManager');

-- ── staff_members ─────────────────────────────────────────────
DROP POLICY IF EXISTS staff_members_select_all ON staff_members;
DROP POLICY IF EXISTS staff_members_insert_all ON staff_members;
DROP POLICY IF EXISTS staff_members_update_all ON staff_members;
DROP POLICY IF EXISTS staff_members_delete_all ON staff_members;
CREATE POLICY staff_members_select ON staff_members FOR SELECT TO authenticated USING (true);
-- Insert handled by create_staff_member() SECURITY DEFINER function
CREATE POLICY staff_members_insert ON staff_members FOR INSERT TO authenticated WITH CHECK (get_my_role()::text = 'fleetManager');
-- Own row or fleet manager
CREATE POLICY staff_members_update ON staff_members FOR UPDATE TO authenticated USING (
  id = auth.uid() OR get_my_role()::text = 'fleetManager'
);
CREATE POLICY staff_members_delete ON staff_members FOR DELETE TO authenticated USING (get_my_role()::text = 'fleetManager');

-- ── vehicle_location_history ──────────────────────────────────
DROP POLICY IF EXISTS vehicle_location_history_all ON vehicle_location_history;
CREATE POLICY vlh_select ON vehicle_location_history FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager'
  OR driver_id = auth.uid()
);
CREATE POLICY vlh_insert ON vehicle_location_history FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid() OR get_my_role()::text = 'fleetManager'
);

-- ── emergency_alerts ─────────────────────────────────────────
DROP POLICY IF EXISTS emergency_alerts_all ON emergency_alerts;
CREATE POLICY ea_select ON emergency_alerts FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);
CREATE POLICY ea_insert ON emergency_alerts FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid()
);
CREATE POLICY ea_update ON emergency_alerts FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);

-- ── route_deviation_events ────────────────────────────────────
DROP POLICY IF EXISTS route_deviation_events_all ON route_deviation_events;
CREATE POLICY rde_select ON route_deviation_events FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);
CREATE POLICY rde_insert ON route_deviation_events FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid()
);
CREATE POLICY rde_update ON route_deviation_events FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);

-- ── geofences ─────────────────────────────────────────────────
DROP POLICY IF EXISTS geofences_all ON geofences;
CREATE POLICY geofences_select ON geofences FOR SELECT TO authenticated USING (true);
CREATE POLICY geofences_insert ON geofences FOR INSERT TO authenticated WITH CHECK (get_my_role()::text = 'fleetManager');
CREATE POLICY geofences_update ON geofences FOR UPDATE TO authenticated USING (get_my_role()::text = 'fleetManager');
CREATE POLICY geofences_delete ON geofences FOR DELETE TO authenticated USING (get_my_role()::text = 'fleetManager');

-- ── geofence_events ───────────────────────────────────────────
DROP POLICY IF EXISTS geofence_events_all ON geofence_events;
CREATE POLICY geo_ev_select ON geofence_events FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);
CREATE POLICY geo_ev_insert ON geofence_events FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid()
);

-- ── maintenance_tasks ─────────────────────────────────────────
DROP POLICY IF EXISTS maintenance_tasks_all ON maintenance_tasks;
-- Fleet manager: all. Maintenance: own assigned. Driver: own requests.
CREATE POLICY mt_select ON maintenance_tasks FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager'
  OR assigned_to_id = auth.uid()
  OR get_my_role()::text = 'driver'
);
CREATE POLICY mt_insert ON maintenance_tasks FOR INSERT TO authenticated WITH CHECK (
  get_my_role()::text IN ('fleetManager', 'driver')
);
CREATE POLICY mt_update ON maintenance_tasks FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR assigned_to_id = auth.uid()
);
CREATE POLICY mt_delete ON maintenance_tasks FOR DELETE TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);

-- ── maintenance_records ───────────────────────────────────────
DROP POLICY IF EXISTS maintenance_records_all ON maintenance_records;
CREATE POLICY mr_select ON maintenance_records FOR SELECT TO authenticated USING (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel')
);
CREATE POLICY mr_insert ON maintenance_records FOR INSERT TO authenticated WITH CHECK (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel')
);
CREATE POLICY mr_update ON maintenance_records FOR UPDATE TO authenticated USING (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel')
);

-- ── work_orders ───────────────────────────────────────────────
DROP POLICY IF EXISTS work_orders_all ON work_orders;
CREATE POLICY wo_select ON work_orders FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR assigned_to_id = auth.uid()
);
CREATE POLICY wo_insert ON work_orders FOR INSERT TO authenticated WITH CHECK (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel')
);
CREATE POLICY wo_update ON work_orders FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR assigned_to_id = auth.uid()
);

-- ── parts_used ────────────────────────────────────────────────
DROP POLICY IF EXISTS parts_used_all ON parts_used;
CREATE POLICY parts_select ON parts_used FOR SELECT TO authenticated USING (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel')
);
CREATE POLICY parts_insert ON parts_used FOR INSERT TO authenticated WITH CHECK (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel')
);
CREATE POLICY parts_update ON parts_used FOR UPDATE TO authenticated USING (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel')
);

-- ── spare_parts_requests ──────────────────────────────────────
DROP POLICY IF EXISTS spare_parts_requests_all ON spare_parts_requests;
CREATE POLICY spr_select ON spare_parts_requests FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR requested_by_id = auth.uid()
);
CREATE POLICY spr_insert ON spare_parts_requests FOR INSERT TO authenticated WITH CHECK (
  get_my_role()::text = 'maintenancePersonnel'
);
CREATE POLICY spr_update ON spare_parts_requests FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);

-- ── notifications ─────────────────────────────────────────────
DROP POLICY IF EXISTS notifications_all ON notifications;
-- Each user only sees their own; inserts come from SECURITY DEFINER triggers
CREATE POLICY notif_select ON notifications FOR SELECT TO authenticated USING (
  recipient_id = auth.uid()
);
CREATE POLICY notif_insert ON notifications FOR INSERT TO authenticated WITH CHECK (
  get_my_role()::text = 'fleetManager' OR recipient_id = auth.uid()
);
CREATE POLICY notif_update ON notifications FOR UPDATE TO authenticated USING (
  recipient_id = auth.uid()
);

-- ── fuel_logs ─────────────────────────────────────────────────
DROP POLICY IF EXISTS fuel_logs_all ON fuel_logs;
CREATE POLICY fl_select ON fuel_logs FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);
CREATE POLICY fl_insert ON fuel_logs FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid()
);
CREATE POLICY fl_update ON fuel_logs FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);

-- ── vehicle_inspections ───────────────────────────────────────
DROP POLICY IF EXISTS vehicle_inspections_all ON vehicle_inspections;
CREATE POLICY vi_select ON vehicle_inspections FOR SELECT TO authenticated USING (
  get_my_role()::text IN ('fleetManager', 'maintenancePersonnel') OR driver_id = auth.uid()
);
CREATE POLICY vi_insert ON vehicle_inspections FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid()
);
CREATE POLICY vi_update ON vehicle_inspections FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);

-- ── proof_of_deliveries ───────────────────────────────────────
DROP POLICY IF EXISTS proof_of_deliveries_all ON proof_of_deliveries;
CREATE POLICY pod_select ON proof_of_deliveries FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);
CREATE POLICY pod_insert ON proof_of_deliveries FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid()
);

-- ── two_factor_sessions ───────────────────────────────────────
DROP POLICY IF EXISTS two_factor_sessions_all ON two_factor_sessions;
CREATE POLICY tfs_select ON two_factor_sessions FOR SELECT TO authenticated USING (
  user_id = auth.uid()
);
CREATE POLICY tfs_insert ON two_factor_sessions FOR INSERT TO authenticated WITH CHECK (
  user_id = auth.uid()
);
CREATE POLICY tfs_update ON two_factor_sessions FOR UPDATE TO authenticated USING (
  user_id = auth.uid()
);

-- ── driver_profiles ───────────────────────────────────────────
DROP POLICY IF EXISTS driver_profiles_all ON driver_profiles;
CREATE POLICY dp_select ON driver_profiles FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR staff_member_id = auth.uid()
);
CREATE POLICY dp_insert ON driver_profiles FOR INSERT TO authenticated WITH CHECK (
  staff_member_id = auth.uid() OR get_my_role()::text = 'fleetManager'
);
CREATE POLICY dp_update ON driver_profiles FOR UPDATE TO authenticated USING (
  staff_member_id = auth.uid() OR get_my_role()::text = 'fleetManager'
);

-- ── maintenance_profiles ──────────────────────────────────────
DROP POLICY IF EXISTS maintenance_profiles_all ON maintenance_profiles;
CREATE POLICY mp_select ON maintenance_profiles FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR staff_member_id = auth.uid()
);
CREATE POLICY mp_insert ON maintenance_profiles FOR INSERT TO authenticated WITH CHECK (
  staff_member_id = auth.uid() OR get_my_role()::text = 'fleetManager'
);
CREATE POLICY mp_update ON maintenance_profiles FOR UPDATE TO authenticated USING (
  staff_member_id = auth.uid() OR get_my_role()::text = 'fleetManager'
);

-- ── staff_applications ────────────────────────────────────────
DROP POLICY IF EXISTS staff_applications_all ON staff_applications;
CREATE POLICY sa_select ON staff_applications FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR staff_member_id = auth.uid()
);
CREATE POLICY sa_insert ON staff_applications FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY sa_update ON staff_applications FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);

-- ── vehicle_documents ─────────────────────────────────────────
DROP POLICY IF EXISTS vehicle_documents_all ON vehicle_documents;
CREATE POLICY vd_select ON vehicle_documents FOR SELECT TO authenticated USING (true);
CREATE POLICY vd_insert ON vehicle_documents FOR INSERT TO authenticated WITH CHECK (
  get_my_role()::text = 'fleetManager'
);
CREATE POLICY vd_update ON vehicle_documents FOR UPDATE TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);
CREATE POLICY vd_delete ON vehicle_documents FOR DELETE TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);

-- ── trip_expenses ─────────────────────────────────────────────
DROP POLICY IF EXISTS trip_expenses_all ON trip_expenses;
CREATE POLICY te_select ON trip_expenses FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager' OR driver_id = auth.uid()
);
CREATE POLICY te_insert ON trip_expenses FOR INSERT TO authenticated WITH CHECK (
  driver_id = auth.uid()
);

-- ── activity_logs ─────────────────────────────────────────────
DROP POLICY IF EXISTS activity_logs_all ON activity_logs;
CREATE POLICY al_select ON activity_logs FOR SELECT TO authenticated USING (
  get_my_role()::text = 'fleetManager'
);
CREATE POLICY al_insert ON activity_logs FOR INSERT TO authenticated WITH CHECK (true);
;

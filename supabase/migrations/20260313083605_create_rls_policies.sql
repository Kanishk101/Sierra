
ALTER TABLE staff_members         ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_applications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE two_factor_sessions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_documents     ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_logs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_inspections   ENABLE ROW LEVEL SECURITY;
ALTER TABLE proof_of_deliveries   ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_alerts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_tasks     ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_orders           ENABLE ROW LEVEL SECURITY;
ALTER TABLE parts_used            ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records   ENABLE ROW LEVEL SECURITY;
ALTER TABLE geofences             ENABLE ROW LEVEL SECURITY;
ALTER TABLE geofence_events       ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs         ENABLE ROW LEVEL SECURITY;

-- Fleet managers: full access to all staff
CREATE POLICY "fm_all_staff" ON staff_members FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');

-- Staff: read and update own record only
CREATE POLICY "staff_own_record_select" ON staff_members FOR SELECT
    USING (auth.uid() = id);
CREATE POLICY "staff_own_record_update" ON staff_members FOR UPDATE
    USING (auth.uid() = id);

-- Driver profiles: fleet manager full access, driver reads own
CREATE POLICY "fm_all_driver_profiles" ON driver_profiles FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "driver_own_profile" ON driver_profiles FOR SELECT
    USING (auth.uid() = staff_member_id);

-- Maintenance profiles: fleet manager full access, maintenance reads own
CREATE POLICY "fm_all_maint_profiles" ON maintenance_profiles FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "maint_own_profile" ON maintenance_profiles FOR SELECT
    USING (auth.uid() = staff_member_id);

-- Staff applications: fleet manager full access, staff reads own
CREATE POLICY "fm_all_staff_apps" ON staff_applications FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "staff_own_application" ON staff_applications FOR SELECT
    USING (auth.uid() = staff_member_id);

-- 2FA sessions: only owning user reads their session
CREATE POLICY "own_2fa_session" ON two_factor_sessions FOR SELECT
    USING (auth.uid() = user_id);

-- Vehicles: fleet manager full access, drivers/maintenance read all
CREATE POLICY "fm_all_vehicles" ON vehicles FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "staff_read_vehicles" ON vehicles FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Vehicle documents: fleet manager full access, staff read all
CREATE POLICY "fm_all_vehicle_docs" ON vehicle_documents FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "staff_read_vehicle_docs" ON vehicle_documents FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Trips: fleet manager full access, driver reads own trips
CREATE POLICY "fm_all_trips" ON trips FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "driver_own_trips" ON trips FOR SELECT
    USING (auth.uid() = driver_id);

-- Fuel logs: fleet manager reads all, driver reads/writes own
CREATE POLICY "fm_all_fuel_logs" ON fuel_logs FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "driver_own_fuel_logs" ON fuel_logs FOR ALL
    USING (auth.uid() = driver_id);

-- Vehicle inspections: fleet manager all, driver reads/writes own
CREATE POLICY "fm_all_inspections" ON vehicle_inspections FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "driver_own_inspections" ON vehicle_inspections FOR ALL
    USING (auth.uid() = driver_id);

-- Proof of deliveries: fleet manager all, driver reads/writes own
CREATE POLICY "fm_all_pods" ON proof_of_deliveries FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "driver_own_pods" ON proof_of_deliveries FOR ALL
    USING (auth.uid() = driver_id);

-- Emergency alerts: fleet manager all, driver inserts own
CREATE POLICY "fm_all_alerts" ON emergency_alerts FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "driver_own_alerts" ON emergency_alerts FOR INSERT
    WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "driver_read_own_alerts" ON emergency_alerts FOR SELECT
    USING (auth.uid() = driver_id);

-- Maintenance tasks: fleet manager all, maintenance reads assigned
CREATE POLICY "fm_all_maint_tasks" ON maintenance_tasks FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "maint_assigned_tasks" ON maintenance_tasks FOR SELECT
    USING (auth.uid() = assigned_to_id);

-- Work orders: fleet manager all, maintenance reads/updates assigned
CREATE POLICY "fm_all_work_orders" ON work_orders FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "maint_own_work_orders_select" ON work_orders FOR SELECT
    USING (auth.uid() = assigned_to_id);
CREATE POLICY "maint_own_work_orders_update" ON work_orders FOR UPDATE
    USING (auth.uid() = assigned_to_id);

-- Parts used: fleet manager all, maintenance reads/writes for own work orders
CREATE POLICY "fm_all_parts" ON parts_used FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');

-- Maintenance records: fleet manager all, maintenance reads own
CREATE POLICY "fm_all_maint_records" ON maintenance_records FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "maint_own_records" ON maintenance_records FOR SELECT
    USING (auth.uid() = performed_by_id);

-- Geofences: fleet manager all, staff read active geofences
CREATE POLICY "fm_all_geofences" ON geofences FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "staff_read_geofences" ON geofences FOR SELECT
    USING (auth.uid() IS NOT NULL AND is_active = TRUE);

-- Geofence events: fleet manager all, staff read
CREATE POLICY "fm_all_geo_events" ON geofence_events FOR ALL
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
CREATE POLICY "staff_read_geo_events" ON geofence_events FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Activity logs: fleet manager reads all
CREATE POLICY "fm_activity_logs" ON activity_logs FOR SELECT
    USING ((auth.jwt() ->> 'role') = 'fleetManager');
;

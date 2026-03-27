
-- ============================================================
-- FIX: Replace all get_my_role() / auth.uid() RLS policies
-- with open policies. The vinayak auth pattern uses no Supabase
-- Auth session, so auth.uid() always returns NULL, blocking
-- every table fetch. All data shows as 0 on the app.
-- ============================================================

-- ── vehicles ──────────────────────────────────────────────
DROP POLICY IF EXISTS fm_all_vehicles    ON public.vehicles;
DROP POLICY IF EXISTS staff_read_vehicles ON public.vehicles;

CREATE POLICY vehicles_all ON public.vehicles FOR ALL USING (true) WITH CHECK (true);

-- ── trips ─────────────────────────────────────────────────
DROP POLICY IF EXISTS fm_all_trips         ON public.trips;
DROP POLICY IF EXISTS driver_own_trips     ON public.trips;
DROP POLICY IF EXISTS driver_update_own_trips ON public.trips;

CREATE POLICY trips_all ON public.trips FOR ALL USING (true) WITH CHECK (true);

-- ── staff_applications ────────────────────────────────────
DROP POLICY IF EXISTS fm_all_staff_apps        ON public.staff_applications;
DROP POLICY IF EXISTS staff_insert_own_application ON public.staff_applications;
DROP POLICY IF EXISTS staff_own_application    ON public.staff_applications;

CREATE POLICY staff_applications_all ON public.staff_applications FOR ALL USING (true) WITH CHECK (true);

-- ── driver_profiles ───────────────────────────────────────
DROP POLICY IF EXISTS fm_all_driver_profiles ON public.driver_profiles;
DROP POLICY IF EXISTS driver_own_profile     ON public.driver_profiles;

CREATE POLICY driver_profiles_all ON public.driver_profiles FOR ALL USING (true) WITH CHECK (true);

-- ── maintenance_profiles ──────────────────────────────────
DROP POLICY IF EXISTS fm_all_maint_profiles ON public.maintenance_profiles;
DROP POLICY IF EXISTS maint_own_profile     ON public.maintenance_profiles;

CREATE POLICY maintenance_profiles_all ON public.maintenance_profiles FOR ALL USING (true) WITH CHECK (true);

-- ── vehicle_documents ─────────────────────────────────────
DROP POLICY IF EXISTS fm_all_vehicle_docs   ON public.vehicle_documents;
DROP POLICY IF EXISTS staff_read_vehicle_docs ON public.vehicle_documents;

CREATE POLICY vehicle_documents_all ON public.vehicle_documents FOR ALL USING (true) WITH CHECK (true);

-- ── fuel_logs ─────────────────────────────────────────────
DROP POLICY IF EXISTS fm_all_fuel_logs    ON public.fuel_logs;
DROP POLICY IF EXISTS driver_own_fuel_logs ON public.fuel_logs;

CREATE POLICY fuel_logs_all ON public.fuel_logs FOR ALL USING (true) WITH CHECK (true);

-- ── vehicle_inspections ───────────────────────────────────
DROP POLICY IF EXISTS fm_all_inspections    ON public.vehicle_inspections;
DROP POLICY IF EXISTS driver_own_inspections ON public.vehicle_inspections;

CREATE POLICY vehicle_inspections_all ON public.vehicle_inspections FOR ALL USING (true) WITH CHECK (true);

-- ── proof_of_deliveries ───────────────────────────────────
DROP POLICY IF EXISTS fm_all_pods    ON public.proof_of_deliveries;
DROP POLICY IF EXISTS driver_own_pods ON public.proof_of_deliveries;

CREATE POLICY proof_of_deliveries_all ON public.proof_of_deliveries FOR ALL USING (true) WITH CHECK (true);

-- ── emergency_alerts ──────────────────────────────────────
DROP POLICY IF EXISTS fm_all_alerts        ON public.emergency_alerts;
DROP POLICY IF EXISTS driver_own_alerts    ON public.emergency_alerts;
DROP POLICY IF EXISTS driver_read_own_alerts ON public.emergency_alerts;

CREATE POLICY emergency_alerts_all ON public.emergency_alerts FOR ALL USING (true) WITH CHECK (true);

-- ── maintenance_tasks ─────────────────────────────────────
DROP POLICY IF EXISTS fm_all_maint_tasks       ON public.maintenance_tasks;
DROP POLICY IF EXISTS maint_assigned_tasks     ON public.maintenance_tasks;
DROP POLICY IF EXISTS maint_update_assigned_tasks ON public.maintenance_tasks;

CREATE POLICY maintenance_tasks_all ON public.maintenance_tasks FOR ALL USING (true) WITH CHECK (true);

-- ── work_orders ───────────────────────────────────────────
DROP POLICY IF EXISTS fm_all_work_orders          ON public.work_orders;
DROP POLICY IF EXISTS maint_own_work_orders_select ON public.work_orders;
DROP POLICY IF EXISTS maint_own_work_orders_update ON public.work_orders;

CREATE POLICY work_orders_all ON public.work_orders FOR ALL USING (true) WITH CHECK (true);

-- ── maintenance_records ───────────────────────────────────
DROP POLICY IF EXISTS fm_all_maint_records   ON public.maintenance_records;
DROP POLICY IF EXISTS maint_insert_own_records ON public.maintenance_records;
DROP POLICY IF EXISTS maint_own_records      ON public.maintenance_records;

CREATE POLICY maintenance_records_all ON public.maintenance_records FOR ALL USING (true) WITH CHECK (true);

-- ── parts_used ────────────────────────────────────────────
DROP POLICY IF EXISTS fm_all_parts        ON public.parts_used;
DROP POLICY IF EXISTS maint_own_parts_used ON public.parts_used;

CREATE POLICY parts_used_all ON public.parts_used FOR ALL USING (true) WITH CHECK (true);

-- ── geofences ─────────────────────────────────────────────
DROP POLICY IF EXISTS fm_all_geofences   ON public.geofences;
DROP POLICY IF EXISTS staff_read_geofences ON public.geofences;

CREATE POLICY geofences_all ON public.geofences FOR ALL USING (true) WITH CHECK (true);

-- ── geofence_events ───────────────────────────────────────
DROP POLICY IF EXISTS fm_all_geo_events    ON public.geofence_events;
DROP POLICY IF EXISTS staff_read_geo_events ON public.geofence_events;

CREATE POLICY geofence_events_all ON public.geofence_events FOR ALL USING (true) WITH CHECK (true);

-- ── activity_logs ─────────────────────────────────────────
DROP POLICY IF EXISTS fm_activity_logs ON public.activity_logs;

CREATE POLICY activity_logs_all ON public.activity_logs FOR ALL USING (true) WITH CHECK (true);

-- ── two_factor_sessions ───────────────────────────────────
DROP POLICY IF EXISTS fm_all_2fa_sessions   ON public.two_factor_sessions;
DROP POLICY IF EXISTS insert_own_2fa_session ON public.two_factor_sessions;
DROP POLICY IF EXISTS own_2fa_session        ON public.two_factor_sessions;
DROP POLICY IF EXISTS update_own_2fa_session ON public.two_factor_sessions;

CREATE POLICY two_factor_sessions_all ON public.two_factor_sessions FOR ALL USING (true) WITH CHECK (true);
;

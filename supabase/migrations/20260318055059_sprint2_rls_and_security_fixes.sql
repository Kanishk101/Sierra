
-- ============================================================
-- SIERRA SPRINT 2 — RLS & SECURITY FIXES
-- Applied: 2026-03-18
--
-- IMPORTANT NOTE ON AUTH ARCHITECTURE:
-- The app uses the Supabase anon key with custom password auth
-- (staff_members.password). auth.uid() is always NULL, auth.role()
-- is always 'anon'. All policies therefore use USING(true) to match
-- the existing pattern. POST-SPRINT: migrate to Supabase Auth JWT
-- for proper role-scoped RLS with auth.uid() and custom claims.
-- ============================================================


-- ============================================================
-- PART 1: FIX 5 BLOCKED TABLES (Sprint 2 runtime blockers)
-- ============================================================

CREATE POLICY "vehicle_location_history_all"
  ON public.vehicle_location_history FOR ALL
  USING (true) WITH CHECK (true);

CREATE POLICY "route_deviation_events_all"
  ON public.route_deviation_events FOR ALL
  USING (true) WITH CHECK (true);

CREATE POLICY "notifications_all"
  ON public.notifications FOR ALL
  USING (true) WITH CHECK (true);

CREATE POLICY "spare_parts_requests_all"
  ON public.spare_parts_requests FOR ALL
  USING (true) WITH CHECK (true);

CREATE POLICY "trip_expenses_all"
  ON public.trip_expenses FOR ALL
  USING (true) WITH CHECK (true);


-- ============================================================
-- PART 2: FIX STAFF_MEMBERS DELETE POLICY
-- Old policy: auth.role() = 'authenticated' — NEVER matches since
-- the app uses anon key. This was silently blocking all app-side
-- staff deletions. Replace with consistent open policy.
-- ============================================================

DROP POLICY IF EXISTS "staff_members_delete_authenticated" ON public.staff_members;

CREATE POLICY "staff_members_delete_all"
  ON public.staff_members FOR DELETE
  USING (true);


-- ============================================================
-- PART 3: FIX MUTABLE search_path ON TRIGGER FUNCTIONS
-- ============================================================

ALTER FUNCTION public.handle_trip_started()
  SET search_path = public;

ALTER FUNCTION public.handle_trip_completed()
  SET search_path = public;

ALTER FUNCTION public.handle_trip_cancelled()
  SET search_path = public;

ALTER FUNCTION public.check_resource_overlap(
  p_driver_id uuid,
  p_vehicle_id uuid,
  p_start timestamp with time zone,
  p_end timestamp with time zone,
  p_exclude_trip_id uuid
)
  SET search_path = public;


-- ============================================================
-- PART 4: FK INDEXES — HIGH-TRAFFIC SPRINT 2 TABLES
-- ============================================================

-- vehicle_location_history (GPS write every 5s per active vehicle)
CREATE INDEX IF NOT EXISTS idx_vlh_trip_id
  ON public.vehicle_location_history (trip_id);
CREATE INDEX IF NOT EXISTS idx_vlh_driver_id
  ON public.vehicle_location_history (driver_id);
CREATE INDEX IF NOT EXISTS idx_vlh_vehicle_id
  ON public.vehicle_location_history (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vlh_recorded_at
  ON public.vehicle_location_history (recorded_at DESC);

-- emergency_alerts (realtime subscription for fleet manager inbox)
CREATE INDEX IF NOT EXISTS idx_ea_driver_id
  ON public.emergency_alerts (driver_id);
CREATE INDEX IF NOT EXISTS idx_ea_trip_id
  ON public.emergency_alerts (trip_id);
CREATE INDEX IF NOT EXISTS idx_ea_vehicle_id
  ON public.emergency_alerts (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_ea_acknowledged_by
  ON public.emergency_alerts (acknowledged_by)
  WHERE acknowledged_by IS NOT NULL;

-- geofence_events (realtime subscription for fleet manager)
CREATE INDEX IF NOT EXISTS idx_geo_ev_driver_id
  ON public.geofence_events (driver_id);
CREATE INDEX IF NOT EXISTS idx_geo_ev_trip_id
  ON public.geofence_events (trip_id);

-- route_deviation_events
CREATE INDEX IF NOT EXISTS idx_rde_driver_id
  ON public.route_deviation_events (driver_id);
CREATE INDEX IF NOT EXISTS idx_rde_vehicle_id
  ON public.route_deviation_events (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_rde_acknowledged_by
  ON public.route_deviation_events (acknowledged_by)
  WHERE acknowledged_by IS NOT NULL;

-- maintenance_tasks
CREATE INDEX IF NOT EXISTS idx_mt_created_by_admin
  ON public.maintenance_tasks (created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_mt_source_alert
  ON public.maintenance_tasks (source_alert_id)
  WHERE source_alert_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_mt_source_inspection
  ON public.maintenance_tasks (source_inspection_id)
  WHERE source_inspection_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_mt_approved_by
  ON public.maintenance_tasks (approved_by_id)
  WHERE approved_by_id IS NOT NULL;

-- maintenance_records
CREATE INDEX IF NOT EXISTS idx_mr_task_id
  ON public.maintenance_records (maintenance_task_id);
CREATE INDEX IF NOT EXISTS idx_mr_performed_by
  ON public.maintenance_records (performed_by_id);

-- trips (fleet manager dashboard join queries)
CREATE INDEX IF NOT EXISTS idx_trips_created_by_admin
  ON public.trips (created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_trips_pre_inspection
  ON public.trips (pre_inspection_id)
  WHERE pre_inspection_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_trips_post_inspection
  ON public.trips (post_inspection_id)
  WHERE post_inspection_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_trips_proof_of_delivery
  ON public.trips (proof_of_delivery_id)
  WHERE proof_of_delivery_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_trips_rated_by
  ON public.trips (rated_by_id)
  WHERE rated_by_id IS NOT NULL;

-- trip_expenses (driver expense history)
CREATE INDEX IF NOT EXISTS idx_te_trip_id
  ON public.trip_expenses (trip_id);
CREATE INDEX IF NOT EXISTS idx_te_driver_id
  ON public.trip_expenses (driver_id);
CREATE INDEX IF NOT EXISTS idx_te_vehicle_id
  ON public.trip_expenses (vehicle_id);

-- vehicle_inspections
CREATE INDEX IF NOT EXISTS idx_vi_driver_id
  ON public.vehicle_inspections (driver_id);
CREATE INDEX IF NOT EXISTS idx_vi_raised_task
  ON public.vehicle_inspections (raised_task_id)
  WHERE raised_task_id IS NOT NULL;

-- spare_parts_requests
CREATE INDEX IF NOT EXISTS idx_spr_task_id
  ON public.spare_parts_requests (maintenance_task_id);
CREATE INDEX IF NOT EXISTS idx_spr_work_order_id
  ON public.spare_parts_requests (work_order_id)
  WHERE work_order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_spr_requested_by
  ON public.spare_parts_requests (requested_by_id);
CREATE INDEX IF NOT EXISTS idx_spr_reviewed_by
  ON public.spare_parts_requests (reviewed_by)
  WHERE reviewed_by IS NOT NULL;

-- work_orders
CREATE INDEX IF NOT EXISTS idx_wo_vehicle_id
  ON public.work_orders (vehicle_id);

-- staff_applications
CREATE INDEX IF NOT EXISTS idx_sa_reviewed_by
  ON public.staff_applications (reviewed_by)
  WHERE reviewed_by IS NOT NULL;

-- driver_profiles
CREATE INDEX IF NOT EXISTS idx_dp_current_vehicle
  ON public.driver_profiles (current_vehicle_id)
  WHERE current_vehicle_id IS NOT NULL;

-- geofences
CREATE INDEX IF NOT EXISTS idx_gf_created_by_admin
  ON public.geofences (created_by_admin_id);
;

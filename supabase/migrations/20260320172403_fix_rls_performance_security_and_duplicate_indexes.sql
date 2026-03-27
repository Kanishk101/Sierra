
-- ============================================================
-- Migration: Fix all RLS performance + security + duplicate index issues
-- Sierra Fleet Management System — 2026-03-20
-- ============================================================

-- FIX 1: Fix handle_maintenance_task_status_change mutable search_path
ALTER FUNCTION public.handle_maintenance_task_status_change()
  SET search_path = public;

-- FIX 2: Add RLS policy for rate_limit_buckets (RLS enabled, no policy)
CREATE POLICY rlb_deny_all ON public.rate_limit_buckets
  AS RESTRICTIVE FOR ALL TO authenticated USING (false);

-- FIX 3: Replace bare auth.uid() with (select auth.uid()) everywhere
-- This prevents per-row re-evaluation, fixing query plan performance.

-- driver_profiles
DROP POLICY IF EXISTS dp_select ON public.driver_profiles;
DROP POLICY IF EXISTS dp_insert ON public.driver_profiles;
DROP POLICY IF EXISTS dp_update ON public.driver_profiles;
CREATE POLICY dp_select ON public.driver_profiles FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (staff_member_id = (SELECT auth.uid())));
CREATE POLICY dp_insert ON public.driver_profiles FOR INSERT TO authenticated
  WITH CHECK (staff_member_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');
CREATE POLICY dp_update ON public.driver_profiles FOR UPDATE TO authenticated
  USING (staff_member_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- maintenance_profiles
DROP POLICY IF EXISTS mp_select ON public.maintenance_profiles;
DROP POLICY IF EXISTS mp_insert ON public.maintenance_profiles;
DROP POLICY IF EXISTS mp_update ON public.maintenance_profiles;
CREATE POLICY mp_select ON public.maintenance_profiles FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (staff_member_id = (SELECT auth.uid())));
CREATE POLICY mp_insert ON public.maintenance_profiles FOR INSERT TO authenticated
  WITH CHECK (staff_member_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');
CREATE POLICY mp_update ON public.maintenance_profiles FOR UPDATE TO authenticated
  USING (staff_member_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- staff_applications
DROP POLICY IF EXISTS sa_select ON public.staff_applications;
CREATE POLICY sa_select ON public.staff_applications FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (staff_member_id = (SELECT auth.uid())));

-- staff_members
DROP POLICY IF EXISTS staff_members_update ON public.staff_members;
CREATE POLICY staff_members_update ON public.staff_members FOR UPDATE TO authenticated
  USING ((id = (SELECT auth.uid())) OR (get_my_role() = 'fleetManager'));

-- two_factor_sessions
DROP POLICY IF EXISTS tfs_select ON public.two_factor_sessions;
DROP POLICY IF EXISTS tfs_insert ON public.two_factor_sessions;
DROP POLICY IF EXISTS tfs_update ON public.two_factor_sessions;
CREATE POLICY tfs_select ON public.two_factor_sessions FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));
CREATE POLICY tfs_insert ON public.two_factor_sessions FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY tfs_update ON public.two_factor_sessions FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- fuel_logs
DROP POLICY IF EXISTS fl_select ON public.fuel_logs;
DROP POLICY IF EXISTS fl_insert ON public.fuel_logs;
DROP POLICY IF EXISTS fl_update ON public.fuel_logs;
CREATE POLICY fl_select ON public.fuel_logs FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY fl_insert ON public.fuel_logs FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');
CREATE POLICY fl_update ON public.fuel_logs FOR UPDATE TO authenticated
  USING (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- vehicle_inspections
DROP POLICY IF EXISTS vi_select ON public.vehicle_inspections;
DROP POLICY IF EXISTS vi_insert ON public.vehicle_inspections;
DROP POLICY IF EXISTS vi_update ON public.vehicle_inspections;
CREATE POLICY vi_select ON public.vehicle_inspections FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY vi_insert ON public.vehicle_inspections FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');
CREATE POLICY vi_update ON public.vehicle_inspections FOR UPDATE TO authenticated
  USING (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- proof_of_deliveries
DROP POLICY IF EXISTS pod_select ON public.proof_of_deliveries;
DROP POLICY IF EXISTS pod_insert ON public.proof_of_deliveries;
CREATE POLICY pod_select ON public.proof_of_deliveries FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY pod_insert ON public.proof_of_deliveries FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- emergency_alerts
DROP POLICY IF EXISTS ea_select ON public.emergency_alerts;
DROP POLICY IF EXISTS ea_insert ON public.emergency_alerts;
CREATE POLICY ea_select ON public.emergency_alerts FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY ea_insert ON public.emergency_alerts FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- maintenance_tasks
DROP POLICY IF EXISTS mt_select ON public.maintenance_tasks;
DROP POLICY IF EXISTS mt_update ON public.maintenance_tasks;
CREATE POLICY mt_select ON public.maintenance_tasks FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager')
      OR (assigned_to_id = (SELECT auth.uid()))
      OR (created_by_admin_id = (SELECT auth.uid())));
CREATE POLICY mt_update ON public.maintenance_tasks FOR UPDATE TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (assigned_to_id = (SELECT auth.uid())));

-- work_orders
DROP POLICY IF EXISTS wo_select ON public.work_orders;
DROP POLICY IF EXISTS wo_update ON public.work_orders;
CREATE POLICY wo_select ON public.work_orders FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (assigned_to_id = (SELECT auth.uid())));
CREATE POLICY wo_update ON public.work_orders FOR UPDATE TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (assigned_to_id = (SELECT auth.uid())));

-- vehicle_location_history
DROP POLICY IF EXISTS vlh_select ON public.vehicle_location_history;
DROP POLICY IF EXISTS vlh_insert ON public.vehicle_location_history;
CREATE POLICY vlh_select ON public.vehicle_location_history FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY vlh_insert ON public.vehicle_location_history FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- route_deviation_events
DROP POLICY IF EXISTS rde_select ON public.route_deviation_events;
DROP POLICY IF EXISTS rde_insert ON public.route_deviation_events;
CREATE POLICY rde_select ON public.route_deviation_events FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY rde_insert ON public.route_deviation_events FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- geofence_events
DROP POLICY IF EXISTS geo_ev_select ON public.geofence_events;
DROP POLICY IF EXISTS geo_ev_insert ON public.geofence_events;
CREATE POLICY geo_ev_select ON public.geofence_events FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY geo_ev_insert ON public.geofence_events FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- notifications
DROP POLICY IF EXISTS notif_select ON public.notifications;
DROP POLICY IF EXISTS notif_update ON public.notifications;
CREATE POLICY notif_select ON public.notifications FOR SELECT TO authenticated
  USING (recipient_id = (SELECT auth.uid()));
CREATE POLICY notif_update ON public.notifications FOR UPDATE TO authenticated
  USING (recipient_id = (SELECT auth.uid()));

-- spare_parts_requests
DROP POLICY IF EXISTS spr_select ON public.spare_parts_requests;
CREATE POLICY spr_select ON public.spare_parts_requests FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (requested_by_id = (SELECT auth.uid())));

-- trips (driver_id is UUID FK to staff_members.id — no cast needed)
DROP POLICY IF EXISTS trips_select ON public.trips;
DROP POLICY IF EXISTS trips_update ON public.trips;
CREATE POLICY trips_select ON public.trips FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager')
      OR (driver_id = (SELECT auth.uid()))
      OR (get_my_role() = 'maintenancePersonnel'));
CREATE POLICY trips_update ON public.trips FOR UPDATE TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));

-- password_reset_tokens
DROP POLICY IF EXISTS prt_select ON public.password_reset_tokens;
CREATE POLICY prt_select ON public.password_reset_tokens FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- trip_expenses
DROP POLICY IF EXISTS te_select ON public.trip_expenses;
DROP POLICY IF EXISTS te_insert ON public.trip_expenses;
CREATE POLICY te_select ON public.trip_expenses FOR SELECT TO authenticated
  USING ((get_my_role() = 'fleetManager') OR (driver_id = (SELECT auth.uid())));
CREATE POLICY te_insert ON public.trip_expenses FOR INSERT TO authenticated
  WITH CHECK (driver_id = (SELECT auth.uid()) OR get_my_role() = 'fleetManager');

-- FIX 4: Drop duplicate index on emergency_alerts
DROP INDEX IF EXISTS public.idx_ea_driver_id;
;

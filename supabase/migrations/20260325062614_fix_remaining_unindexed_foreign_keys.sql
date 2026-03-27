
-- Add indexes for all remaining unindexed foreign keys

-- driver_profiles: current_vehicle_id FK
CREATE INDEX IF NOT EXISTS idx_dp_current_vehicle
  ON public.driver_profiles (current_vehicle_id)
  WHERE current_vehicle_id IS NOT NULL;

-- emergency_alerts: acknowledged_by FK
CREATE INDEX IF NOT EXISTS idx_ea_acknowledged_by
  ON public.emergency_alerts (acknowledged_by)
  WHERE acknowledged_by IS NOT NULL;

-- geofence_events: driver_id FK
CREATE INDEX IF NOT EXISTS idx_geo_ev_driver_id
  ON public.geofence_events (driver_id)
  WHERE driver_id IS NOT NULL;

-- geofences: created_by_admin_id FK
CREATE INDEX IF NOT EXISTS idx_gf_created_by_admin
  ON public.geofences (created_by_admin_id)
  WHERE created_by_admin_id IS NOT NULL;

-- maintenance_records: work_order_id FK
CREATE INDEX IF NOT EXISTS idx_maint_rec_wo
  ON public.maintenance_records (work_order_id);

-- maintenance_tasks: approved_by_id, created_by_admin_id, source_alert_id, source_inspection_id
CREATE INDEX IF NOT EXISTS idx_mt_approved_by
  ON public.maintenance_tasks (approved_by_id)
  WHERE approved_by_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mt_created_by_admin
  ON public.maintenance_tasks (created_by_admin_id)
  WHERE created_by_admin_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mt_source_alert
  ON public.maintenance_tasks (source_alert_id)
  WHERE source_alert_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mt_source_inspection
  ON public.maintenance_tasks (source_inspection_id)
  WHERE source_inspection_id IS NOT NULL;

-- parts_used: work_order_id FK
CREATE INDEX IF NOT EXISTS idx_parts_work_order
  ON public.parts_used (work_order_id);

-- password_reset_tokens: user_id FK
CREATE INDEX IF NOT EXISTS idx_prt_user_id
  ON public.password_reset_tokens (user_id)
  WHERE user_id IS NOT NULL;

-- route_deviation_events: acknowledged_by, driver_id FKs
CREATE INDEX IF NOT EXISTS idx_rde_acknowledged_by
  ON public.route_deviation_events (acknowledged_by)
  WHERE acknowledged_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rde_driver_id
  ON public.route_deviation_events (driver_id);

-- spare_parts_requests: reviewed_by, work_order_id
CREATE INDEX IF NOT EXISTS idx_spr_reviewed_by
  ON public.spare_parts_requests (reviewed_by)
  WHERE reviewed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_spr_work_order_id
  ON public.spare_parts_requests (work_order_id)
  WHERE work_order_id IS NOT NULL;

-- staff_applications: reviewed_by FK
CREATE INDEX IF NOT EXISTS idx_sa_reviewed_by
  ON public.staff_applications (reviewed_by)
  WHERE reviewed_by IS NOT NULL;

-- trip_expenses: driver_id FK
CREATE INDEX IF NOT EXISTS idx_te_driver_id
  ON public.trip_expenses (driver_id)
  WHERE driver_id IS NOT NULL;

-- trips: created_by_admin_id, pre/post inspection, proof_of_delivery, rated_by
CREATE INDEX IF NOT EXISTS idx_trips_created_by_admin
  ON public.trips (created_by_admin_id)
  WHERE created_by_admin_id IS NOT NULL;

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

-- vehicle_inspections: driver_id, raised_task FKs
CREATE INDEX IF NOT EXISTS idx_vi_driver_id
  ON public.vehicle_inspections (driver_id)
  WHERE driver_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vi_raised_task
  ON public.vehicle_inspections (raised_task_id)
  WHERE raised_task_id IS NOT NULL;

-- vehicle_location_history: driver_id FK
CREATE INDEX IF NOT EXISTS idx_vlh_driver_id
  ON public.vehicle_location_history (driver_id)
  WHERE driver_id IS NOT NULL;
;

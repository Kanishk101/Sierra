
-- PERFORMANCE FIX: Drop the duplicate index (keep the better-named one)
DROP INDEX IF EXISTS public.idx_notifications_scheduled_undelivered;

-- Drop all confirmed unused indexes (never hit according to pg_stat_user_indexes)
-- staff_members
DROP INDEX IF EXISTS public.idx_staff_role;
DROP INDEX IF EXISTS public.idx_staff_status;
DROP INDEX IF EXISTS public.idx_staff_availability;
DROP INDEX IF EXISTS public.idx_sm_account_locked;

-- two_factor_sessions
DROP INDEX IF EXISTS public.idx_2fa_expires;

-- vehicles
DROP INDEX IF EXISTS public.idx_vehicles_status;

-- trips
DROP INDEX IF EXISTS public.idx_trips_scheduled;
DROP INDEX IF EXISTS public.idx_trips_created_by_admin;
DROP INDEX IF EXISTS public.idx_trips_pre_inspection;
DROP INDEX IF EXISTS public.idx_trips_post_inspection;
DROP INDEX IF EXISTS public.idx_trips_proof_of_delivery;
DROP INDEX IF EXISTS public.idx_trips_rated_by;
DROP INDEX IF EXISTS public.idx_trips_route_stops;
DROP INDEX IF EXISTS public.idx_trips_driver_scheduled_status;

-- vehicle_inspections
DROP INDEX IF EXISTS public.idx_inspect_result;
DROP INDEX IF EXISTS public.idx_vi_driver_id;
DROP INDEX IF EXISTS public.idx_vi_raised_task;

-- work_orders
DROP INDEX IF EXISTS public.idx_work_orders_status;

-- parts_used
DROP INDEX IF EXISTS public.idx_parts_work_order;

-- emergency_alerts
DROP INDEX IF EXISTS public.idx_alerts_status;
DROP INDEX IF EXISTS public.idx_alerts_time;
DROP INDEX IF EXISTS public.idx_emergency_alerts_status;
DROP INDEX IF EXISTS public.idx_ea_acknowledged_by;

-- maintenance_tasks
DROP INDEX IF EXISTS public.idx_maint_tasks_status;
DROP INDEX IF EXISTS public.idx_mt_created_by_admin;
DROP INDEX IF EXISTS public.idx_mt_source_alert;
DROP INDEX IF EXISTS public.idx_mt_source_inspection;
DROP INDEX IF EXISTS public.idx_mt_approved_by;

-- maintenance_records
DROP INDEX IF EXISTS public.idx_maint_rec_wo;

-- geofences
DROP INDEX IF EXISTS public.idx_geofences_active;
DROP INDEX IF EXISTS public.idx_gf_created_by_admin;

-- geofence_events
DROP INDEX IF EXISTS public.idx_geo_events_time;
DROP INDEX IF EXISTS public.idx_geo_ev_driver_id;

-- route_deviation_events
DROP INDEX IF EXISTS public.idx_rde_driver_id;
DROP INDEX IF EXISTS public.idx_rde_acknowledged_by;

-- activity_logs
DROP INDEX IF EXISTS public.idx_logs_type;
DROP INDEX IF EXISTS public.idx_logs_severity;
DROP INDEX IF EXISTS public.idx_logs_is_read;

-- notifications
DROP INDEX IF EXISTS public.idx_notifications_recipient_read;
DROP INDEX IF EXISTS public.idx_notifications_scheduled;

-- vehicle_location_history
DROP INDEX IF EXISTS public.idx_vlh_driver_id;

-- password_reset_tokens
DROP INDEX IF EXISTS public.idx_prt_email;
DROP INDEX IF EXISTS public.idx_prt_user_id;

-- rate_limit_buckets
DROP INDEX IF EXISTS public.idx_rlb_action_id;

-- spare_parts_requests
DROP INDEX IF EXISTS public.idx_spr_work_order_id;
DROP INDEX IF EXISTS public.idx_spr_reviewed_by;

-- staff_applications
DROP INDEX IF EXISTS public.idx_sa_reviewed_by;

-- driver_profiles
DROP INDEX IF EXISTS public.idx_dp_current_vehicle;

-- trip_expenses
DROP INDEX IF EXISTS public.idx_te_driver_id;

-- ADD the one MISSING index flagged by the advisor
CREATE INDEX IF NOT EXISTS idx_wo_phases_completed_by
  ON public.work_order_phases (completed_by_id);
;

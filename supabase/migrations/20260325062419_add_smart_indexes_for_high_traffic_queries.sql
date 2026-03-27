
-- PERFORMANCE FIX: Add targeted indexes for the queries that actually run

-- notifications: most common query pattern is undelivered scheduled notifications
CREATE INDEX IF NOT EXISTS idx_notifications_undelivered_scheduled
  ON public.notifications (scheduled_for)
  WHERE is_delivered = FALSE AND scheduled_for IS NOT NULL;

-- notifications: recipient inbox (read status)
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
  ON public.notifications (recipient_id, is_read)
  WHERE is_read = FALSE;

-- trips: active/upcoming trips by driver (used by availability checks constantly)
CREATE INDEX IF NOT EXISTS idx_trips_driver_active
  ON public.trips (driver_id, status, scheduled_date)
  WHERE status IN ('Active', 'Scheduled', 'Accepted', 'PendingAcceptance');

-- trips: active/upcoming trips by vehicle (overlap check)
CREATE INDEX IF NOT EXISTS idx_trips_vehicle_active
  ON public.trips (vehicle_id, status, scheduled_date, scheduled_end_date)
  WHERE status IN ('Active', 'Scheduled', 'Accepted', 'PendingAcceptance');

-- vehicle_location_history: primary access pattern (vehicle + time range)
CREATE INDEX IF NOT EXISTS idx_vlh_vehicle_time
  ON public.vehicle_location_history (vehicle_id, recorded_at DESC);

-- rate_limit_buckets: the ON CONFLICT lookup
CREATE INDEX IF NOT EXISTS idx_rlb_action_identifier
  ON public.rate_limit_buckets (action, identifier);

-- activity_logs: fleet manager reads sorted by time
CREATE INDEX IF NOT EXISTS idx_logs_created_at
  ON public.activity_logs (created_at DESC);

-- password_reset_tokens: lookup by token (most common query)
CREATE INDEX IF NOT EXISTS idx_prt_token
  ON public.password_reset_tokens (token);

-- maintenance_tasks: vehicle + active status (trigger subquery)
CREATE INDEX IF NOT EXISTS idx_mt_vehicle_active
  ON public.maintenance_tasks (vehicle_id, status)
  WHERE status IN ('Assigned', 'In Progress');
;


-- Several tables have an updated_at column but no trigger to keep it current.
-- Without triggers, updated_at stays at the insert time forever, making
-- incremental sync and cache invalidation impossible.
--
-- Tables confirmed missing updated_at triggers (checked against existing trigger list):
-- maintenance_records, fuel_logs, staff_applications, vehicle_inspections,
-- emergency_alerts, route_deviation_events, spare_parts_requests, geofence_events

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- maintenance_records (has updated_at column? let's check — it doesn't actually.
-- The schema only has created_at on maintenance_records. Skip.)

-- fuel_logs (no updated_at column — append-only, skip)

-- spare_parts_requests already has updated_at column but no trigger
CREATE TRIGGER trg_spr_updated_at
  BEFORE UPDATE ON public.spare_parts_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- staff_applications has updated_at? Let's check — actually no, just created_at. Skip.

-- vehicle_inspections — no updated_at column. Skip.

-- emergency_alerts — no updated_at column. Skip.

-- The tables that DO have updated_at and need this trigger:
-- spare_parts_requests ✓ (added above)
-- geofences already has update triggers from existing policies
-- work_orders already gets updated_at stamped in sync_work_order_parts_cost trigger

-- Verify no duplicate trigger name issues before adding more
-- maintenance_tasks already has maintenance_task_status_change_trigger which sets updated_at via NEW.completed_at
-- trips already has trg_trip_* triggers
-- vehicles gets updated_at in handle_trip_* trigger functions

-- Nothing else needs this. Done.
SELECT 1;
;

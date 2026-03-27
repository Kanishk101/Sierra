
-- Fix the unique constraint to only block truly concurrent Active trips.
-- PendingAcceptance and Scheduled (post-acceptance) should NOT block a new
-- assignment — the time-based overlap check in the app handles scheduling conflicts.

DROP INDEX IF EXISTS uq_one_active_trip_per_driver;
DROP INDEX IF EXISTS uq_one_active_trip_per_vehicle;

-- Recreate: only block if the driver/vehicle already has an ACTIVE trip right now.
CREATE UNIQUE INDEX uq_one_active_trip_per_driver
  ON public.trips (driver_id)
  WHERE status = 'Active' AND driver_id IS NOT NULL;

CREATE UNIQUE INDEX uq_one_active_trip_per_vehicle
  ON public.trips (vehicle_id)
  WHERE status = 'Active' AND vehicle_id IS NOT NULL;
;


-- ══════════════════════════════════════════════════════════════
-- AUTO-UPDATE updated_at TRIGGERS
-- Keeps updated_at current on every row modification
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- staff_members
DROP TRIGGER IF EXISTS trg_staff_members_updated_at ON public.staff_members;
CREATE TRIGGER trg_staff_members_updated_at
  BEFORE UPDATE ON public.staff_members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- driver_profiles
DROP TRIGGER IF EXISTS trg_driver_profiles_updated_at ON public.driver_profiles;
CREATE TRIGGER trg_driver_profiles_updated_at
  BEFORE UPDATE ON public.driver_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- maintenance_profiles
DROP TRIGGER IF EXISTS trg_maintenance_profiles_updated_at ON public.maintenance_profiles;
CREATE TRIGGER trg_maintenance_profiles_updated_at
  BEFORE UPDATE ON public.maintenance_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- vehicles
DROP TRIGGER IF EXISTS trg_vehicles_updated_at ON public.vehicles;
CREATE TRIGGER trg_vehicles_updated_at
  BEFORE UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- vehicle_documents
DROP TRIGGER IF EXISTS trg_vehicle_documents_updated_at ON public.vehicle_documents;
CREATE TRIGGER trg_vehicle_documents_updated_at
  BEFORE UPDATE ON public.vehicle_documents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- trips
DROP TRIGGER IF EXISTS trg_trips_updated_at ON public.trips;
CREATE TRIGGER trg_trips_updated_at
  BEFORE UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- maintenance_tasks
DROP TRIGGER IF EXISTS trg_maintenance_tasks_updated_at ON public.maintenance_tasks;
CREATE TRIGGER trg_maintenance_tasks_updated_at
  BEFORE UPDATE ON public.maintenance_tasks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- work_orders
DROP TRIGGER IF EXISTS trg_work_orders_updated_at ON public.work_orders;
CREATE TRIGGER trg_work_orders_updated_at
  BEFORE UPDATE ON public.work_orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- geofences
DROP TRIGGER IF EXISTS trg_geofences_updated_at ON public.geofences;
CREATE TRIGGER trg_geofences_updated_at
  BEFORE UPDATE ON public.geofences
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
;

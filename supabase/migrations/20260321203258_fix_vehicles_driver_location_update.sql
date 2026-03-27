
-- CRITICAL FIX: Allow the assigned driver to update their vehicle's location.
-- VehicleLocationService.publishLocation() does:
--   UPDATE vehicles SET current_latitude=?, current_longitude=? WHERE id=?
-- The existing vehicles_update policy only permits fleetManager, so every
-- location publish from the driver was silently dropped — live tracking never worked.
--
-- We add a second UPDATE policy scoped to the assigned driver.
-- WITH CHECK ensures assigned_driver_id cannot be changed by the driver.

CREATE POLICY vehicles_update_driver_location ON public.vehicles
  FOR UPDATE TO authenticated
  USING  (assigned_driver_id = ( SELECT auth.uid()))
  WITH CHECK (assigned_driver_id = ( SELECT auth.uid()));

-- Also create a SECURITY DEFINER RPC so future code can call it cleanly
-- without relying on the broader UPDATE policy.
CREATE OR REPLACE FUNCTION public.update_vehicle_location(
    p_vehicle_id  uuid,
    p_latitude    double precision,
    p_longitude   double precision
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE vehicles
       SET current_latitude  = p_latitude,
           current_longitude = p_longitude,
           updated_at        = now()
     WHERE id                = p_vehicle_id
       AND assigned_driver_id = auth.uid();
END;
$$;

-- Allow any authenticated user to call this function
-- (the body itself enforces driver-owns-vehicle)
GRANT EXECUTE ON FUNCTION public.update_vehicle_location(uuid, double precision, double precision)
  TO authenticated;
;

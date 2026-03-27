-- Fix runtime permission errors for vehicle_part_life_profiles reads.
-- This keeps RLS in place and only grants required table privileges.

GRANT SELECT ON TABLE public.vehicle_part_life_profiles TO authenticated;
GRANT UPDATE ON TABLE public.vehicle_part_life_profiles TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicle_part_life_profiles TO service_role;
GRANT SELECT, INSERT ON TABLE public.vehicle_trip_distance_ledger TO service_role;


-- ================================================================
-- FIX 4: Add missing tables to realtime publication
-- vehicle_location_history — admin breadcrumb trail (live)
-- geofence_events          — admin geofence alert stream
-- ================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'vehicle_location_history'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicle_location_history;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'geofence_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.geofence_events;
  END IF;
END$$;
;

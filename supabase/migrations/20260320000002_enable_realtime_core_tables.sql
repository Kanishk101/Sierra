-- ============================================================
-- Migration: Enable Supabase Realtime for all tables that the
-- iOS app subscribes to via RealtimeChannelV2.
--
-- BEFORE this migration only `staff_members` was in the
-- supabase_realtime publication. This meant:
--
--   AppDataStore.subscribeToVehicleUpdates()  → BROKEN (live admin map)
--   AppDataStore.subscribeToTripUpdates()     → BROKEN (trip status stale)
--   AppDataStore.subscribeToEmergencyAlerts() → BROKEN (SOS not live)
--   NotificationService realtime channel      → BROKEN (notifs silent)
--
-- Adding the four missing tables fixes all four subscriptions.
-- staff_members was already in the publication.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'vehicles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicles;
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'trips'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'emergency_alerts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_alerts;
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END
$$;

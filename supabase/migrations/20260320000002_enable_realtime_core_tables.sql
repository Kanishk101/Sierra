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

ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;


-- ============================================================
-- Migration: Enable Supabase Realtime for all tables that the
-- iOS app subscribes to via RealtimeChannelV2.
--
-- BEFORE this migration only `staff_members` was in the
-- supabase_realtime publication. This means:
--
--   subscribeToVehicleUpdates()   → BROKEN  (live admin map dead)
--   subscribeToTripUpdates()      → BROKEN  (trip status stale)
--   subscribeToEmergencyAlerts()  → BROKEN  (SOS not pushed live)
--   NotificationService realtime  → BROKEN  (in-app notifs silent)
--
-- Adding the four missing tables fixes all four subscriptions.
-- staff_members is already in the publication — skipped.
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
;

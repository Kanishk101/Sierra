-- Fix: notifications INSERT policy
-- Old policy blocked drivers/maintenance from sending notifications to fleet managers.
-- Any authenticated user should be able to insert notifications for any recipient —
-- the SELECT policy already ensures users can only READ their own notifications.
-- This is standard notification system design.

DROP POLICY IF EXISTS notif_insert ON public.notifications;

CREATE POLICY notif_insert ON public.notifications
    FOR INSERT TO authenticated
    WITH CHECK (true);
;

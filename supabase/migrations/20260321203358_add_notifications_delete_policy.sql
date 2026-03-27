
-- Notifications accumulate forever with no way for the user to clear them.
-- Allow recipients to delete their own notifications so the UI can
-- implement "Clear All" and individual swipe-to-delete.

CREATE POLICY notif_delete ON public.notifications
  FOR DELETE TO authenticated
  USING (recipient_id = ( SELECT auth.uid()));
;

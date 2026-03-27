
-- Add route_deviation_events and maintenance_tasks to the Realtime publication.
--
-- route_deviation_events: fleet manager needs to see new deviations in real time
--   on the admin dashboard without polling.
-- maintenance_tasks: fleet manager and maintenance personnel both need live
--   status updates when tasks are assigned, started, or completed.

ALTER PUBLICATION supabase_realtime ADD TABLE public.route_deviation_events;
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_tasks;
;

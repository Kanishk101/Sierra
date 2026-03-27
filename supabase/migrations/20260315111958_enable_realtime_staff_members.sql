
-- Enable Realtime for staff_members table
-- This adds it to the supabase_realtime publication so UPDATE events are broadcast
ALTER PUBLICATION supabase_realtime ADD TABLE public.staff_members;
;


-- Revoke EXECUTE from anon and PUBLIC on check_resource_overlap
-- Unauthenticated users were able to probe trip scheduling data.
REVOKE EXECUTE ON FUNCTION public.check_resource_overlap(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.check_resource_overlap(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.check_resource_overlap(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated;
;

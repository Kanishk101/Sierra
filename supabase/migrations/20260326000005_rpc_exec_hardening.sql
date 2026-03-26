-- RPC execute hardening
-- Revoke broad execute rights and keep only service_role for privileged helpers.

REVOKE EXECUTE ON FUNCTION public.purge_old_location_history(integer)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.purge_expired_password_reset_tokens()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.create_staff_member(text, text, text, text)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.check_resource_overlap(text, text, timestamptz, timestamptz, text)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.purge_old_location_history(integer)
  TO service_role;

GRANT EXECUTE ON FUNCTION public.purge_expired_password_reset_tokens()
  TO service_role;

GRANT EXECUTE ON FUNCTION public.create_staff_member(text, text, text, text)
  TO service_role;

GRANT EXECUTE ON FUNCTION public.check_resource_overlap(text, text, timestamptz, timestamptz, text)
  TO service_role;

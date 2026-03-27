-- Backend hardening (step 1)
-- 1) Lock search_path on SECURITY DEFINER / trigger functions flagged by advisor
-- 2) Remove app-user execute access to maintenance purge RPCs

ALTER FUNCTION public.fn_inventory_parts_set_updated_at()
  SET search_path = public, pg_temp;

ALTER FUNCTION public.handle_maintenance_task_status_change()
  SET search_path = public, pg_temp;

ALTER FUNCTION public.fn_auto_create_work_order()
  SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.purge_old_location_history(integer)
  FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.purge_expired_password_reset_tokens()
  FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.purge_old_location_history(integer)
  TO service_role;

GRANT EXECUTE ON FUNCTION public.purge_expired_password_reset_tokens()
  TO service_role;;

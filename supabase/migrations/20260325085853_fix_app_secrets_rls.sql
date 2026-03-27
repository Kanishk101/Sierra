
-- ================================================================
-- FIX 2: app_secrets has RLS ON but ZERO policies = total lockout
-- The seed-app-secrets edge function writes here using service_role.
-- get_app_secret() is SECURITY DEFINER so reads work fine via fn.
-- But without a service_role policy, even the edge fn can't write.
-- ================================================================
CREATE POLICY "app_secrets_service_role_all"
  ON public.app_secrets
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);
;

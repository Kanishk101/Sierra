-- Storage + function hardening sweep
-- Date: 2026-03-26

-- 1) Lock down accidental public execute surface on run_sql helper.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'run_sql'
      AND pg_get_function_identity_arguments(p.oid) = 'query text'
  ) THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.run_sql(text) FROM PUBLIC, anon, authenticated';
    EXECUTE 'ALTER FUNCTION public.run_sql(text) SET search_path = public, pg_temp';
  END IF;
END $$;

-- 2) Remove legacy permissive storage policies created during early setup.
DROP POLICY IF EXISTS "Allow uploads flreew_0" ON storage.objects;
DROP POLICY IF EXISTS "Give anon users access to JPG images in folder flreew_0" ON storage.objects;
DROP POLICY IF EXISTS "Give anon users access to JPG images in folder flreew_1" ON storage.objects;
DROP POLICY IF EXISTS "authenticated flreew_0" ON storage.objects;

-- 3) Disable unused legacy public buckets.
UPDATE storage.buckets
SET public = false
WHERE id IN ('documents', 'File')
  AND public = true;;

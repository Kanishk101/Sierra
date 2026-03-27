
-- ══════════════════════════════════════════════════════════════
-- SIERRA RLS HELPER FUNCTION
-- Returns the authenticated user's role string from staff_members
-- SECURITY DEFINER so it can bypass RLS on staff_members itself
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.sierra_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role::text FROM public.staff_members WHERE id = auth.uid()
$$;

-- Grant execution to authenticated users only
GRANT EXECUTE ON FUNCTION public.sierra_user_role() TO authenticated;
;

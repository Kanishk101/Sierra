
-- ── Security fix: duplicate permissive INSERT policies ───────────────────────
-- Two INSERT policies exist:
--   prt_insert_anon  → only allows insert when the email already exists in staff_members
--   prt_insert       → allows ALL inserts unconditionally
--
-- In Supabase, permissive policies are combined with OR.
-- The catch-all prt_insert makes prt_insert_anon useless — anyone can spam
-- token inserts for any email, including ones that don't exist.
-- Drop the catch-all; keep the restrictive one.

DROP POLICY IF EXISTS prt_insert ON public.password_reset_tokens;


-- ── Missing UPDATE policy ────────────────────────────────────────────────────
-- The `used` boolean on password_reset_tokens must be set to true after
-- a token is consumed. Without UPDATE, tokens can be reused indefinitely.
-- We scope this to the token owner only.

CREATE POLICY prt_update ON public.password_reset_tokens
  FOR UPDATE TO authenticated
  USING  (user_id = ( SELECT auth.uid()))
  WITH CHECK (user_id = ( SELECT auth.uid()));


-- ── Missing DELETE policy ────────────────────────────────────────────────────
-- Expired/used tokens should be cleanable.

CREATE POLICY prt_delete ON public.password_reset_tokens
  FOR DELETE TO authenticated
  USING (user_id = ( SELECT auth.uid()));
;

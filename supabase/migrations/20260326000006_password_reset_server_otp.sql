-- Move password reset verification fully server-side.
-- App no longer needs anon table access for reset flow.

ALTER TABLE public.password_reset_tokens
  ADD COLUMN IF NOT EXISTS otp_code_hash text;

DROP POLICY IF EXISTS prt_insert_anon ON public.password_reset_tokens;
DROP POLICY IF EXISTS staff_members_select_anon_reset ON public.staff_members;

REVOKE SELECT ON TABLE public.staff_members FROM anon;

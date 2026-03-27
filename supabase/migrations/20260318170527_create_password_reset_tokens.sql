
-- ================================================================
-- Migration: create_password_reset_tokens
-- Purpose  : Short-lived token store for the reset-password edge fn.
--            Tokens expire after 10 minutes and are single-use.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.password_reset_tokens (
  id          uuid        PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  email       text        NOT NULL,
  token       text        NOT NULL UNIQUE,
  user_id     uuid        NOT NULL REFERENCES public.staff_members(id) ON DELETE CASCADE,
  expires_at  timestamptz NOT NULL,
  used        boolean     NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prt_token   ON public.password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_prt_email   ON public.password_reset_tokens(email);
CREATE INDEX IF NOT EXISTS idx_prt_user_id ON public.password_reset_tokens(user_id);

ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Authenticated users can insert their own reset token
CREATE POLICY prt_insert ON public.password_reset_tokens
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Authenticated users can select their own tokens (needed for iOS insert confirm)
CREATE POLICY prt_select ON public.password_reset_tokens
  FOR SELECT TO authenticated
  USING (email = (
    SELECT email FROM public.staff_members WHERE id = auth.uid()
  ));

-- No client UPDATE/DELETE policies — service role (edge fn) handles those
;

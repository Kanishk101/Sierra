-- Phase 5: push_tokens table for APNs device token registration
-- Each staff member can have multiple tokens (multiple devices).
-- UNIQUE(staff_id, device_token) prevents duplicate registrations.

CREATE TABLE IF NOT EXISTS public.push_tokens (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id     UUID        NOT NULL REFERENCES public.staff_members(id) ON DELETE CASCADE,
    device_token TEXT        NOT NULL,
    platform     TEXT        NOT NULL DEFAULT 'ios',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(staff_id, device_token)
);

-- RLS
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- Users can manage their own push tokens (read + write)
DROP POLICY IF EXISTS "push_tokens_own" ON public.push_tokens;
CREATE POLICY "push_tokens_own" ON public.push_tokens
    FOR ALL
    USING (staff_id = auth.uid())
    WITH CHECK (staff_id = auth.uid());

-- Service role bypasses RLS — edge functions can read all tokens for a recipient
-- (This is the default Supabase behaviour for service role key.);

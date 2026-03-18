# Phase 4 — Supabase: `password_reset_tokens` Table + `reset-password` Edge Function

> **This phase is Supabase-side only — no Swift changes.**
> **Depends on:** Phase 3 (edge function source file created).

---

## Step A — Apply the migration in Supabase SQL Editor

Run this SQL in the Supabase dashboard → SQL Editor for project `Sierra-FMS-v2`:

```sql
-- ================================================================
-- Migration : create_password_reset_tokens
-- Purpose   : Short-lived token store for the reset-password edge
--             function. Tokens expire after 10 minutes, single-use.
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

-- RLS: enable. The iOS client (authenticated) can INSERT its own tokens.
-- The reset-password edge function uses the service role (bypasses RLS).
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Authenticated users can insert reset tokens for themselves
CREATE POLICY prt_insert ON public.password_reset_tokens
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- No SELECT/UPDATE client policies — only the service-role edge fn touches those.
```

---

## Step B — Deploy `reset-password` edge function

From the Supabase dashboard → Edge Functions → New Function, paste the
contents of `supabase/functions/reset-password/index.ts` (created in Phase 3).

Set **verify_jwt = false** (the caller has no session during reset).

Or via CLI:
```bash
supabase functions deploy reset-password --no-verify-jwt
```

---

## Step C — Also add migration file to repo

Create `supabase/migrations/20260318000002_create_password_reset_tokens.sql`
with the exact SQL from Step A above.

---

## Verification

- [ ] `password_reset_tokens` table appears in Supabase dashboard → Table Editor
- [ ] RLS is enabled on the table
- [ ] `reset-password` edge function shows as **Active** in Supabase dashboard
- [ ] `verify_jwt` is **false** on the reset-password function
- [ ] End-to-end test:
  1. Tap "Forgot Password" → enter registered email → OTP arrives
  2. Enter OTP → enter new password → success
  3. Log in with new password → works
  4. Attempt to reuse the same OTP/token → rejected

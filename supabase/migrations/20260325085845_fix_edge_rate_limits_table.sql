
-- ================================================================
-- FIX 1: Create missing `edge_rate_limits` table
-- ================================================================
CREATE TABLE IF NOT EXISTS public.edge_rate_limits (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  key        text        NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_erl_key_time
  ON public.edge_rate_limits (key, created_at DESC);

ALTER TABLE public.edge_rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "erl_service_role_all"
  ON public.edge_rate_limits
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.purge_old_rate_limit_entries()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  DELETE FROM public.edge_rate_limits
  WHERE created_at < now() - interval '24 hours';
END;
$$;
;

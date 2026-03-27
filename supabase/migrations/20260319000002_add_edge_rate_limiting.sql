-- ============================================================
-- Migration: Add Edge Function Rate Limiting Support
-- Date: 2026-03-19
--
-- Used by:
--   - send-email edge function
--   - reset-password edge function
-- ============================================================

CREATE TABLE IF NOT EXISTS public.edge_rate_limits (
    action TEXT NOT NULL,
    identifier TEXT NOT NULL,
    bucket_start TIMESTAMPTZ NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT edge_rate_limits_pk PRIMARY KEY (action, identifier, bucket_start)
);

ALTER TABLE public.edge_rate_limits
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_edge_rate_limits_updated_at
    ON public.edge_rate_limits (updated_at);

CREATE OR REPLACE FUNCTION public.enforce_edge_rate_limit(
    p_action TEXT,
    p_identifier TEXT,
    p_window_seconds INTEGER,
    p_max_requests INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_bucket_start TIMESTAMPTZ;
    v_count INTEGER;
BEGIN
    IF p_action IS NULL OR p_action = '' THEN
        RAISE EXCEPTION 'p_action is required';
    END IF;
    IF p_identifier IS NULL OR p_identifier = '' THEN
        RAISE EXCEPTION 'p_identifier is required';
    END IF;
    IF p_window_seconds <= 0 THEN
        RAISE EXCEPTION 'p_window_seconds must be > 0';
    END IF;
    IF p_max_requests <= 0 THEN
        RAISE EXCEPTION 'p_max_requests must be > 0';
    END IF;

    v_bucket_start := to_timestamp(
        floor(extract(epoch FROM now()) / p_window_seconds) * p_window_seconds
    );

    INSERT INTO public.edge_rate_limits (action, identifier, bucket_start, request_count)
    VALUES (p_action, p_identifier, v_bucket_start, 1)
    ON CONFLICT (action, identifier, bucket_start)
    DO UPDATE SET
        request_count = public.edge_rate_limits.request_count + 1,
        updated_at = now()
    RETURNING request_count INTO v_count;

    RETURN v_count <= p_max_requests;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_edge_rate_limit(TEXT, TEXT, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enforce_edge_rate_limit(TEXT, TEXT, INTEGER, INTEGER)
    TO service_role, authenticated;

-- ============================================================
-- Create enforce_edge_rate_limit RPC
-- Called by reset-password and send-email edge functions.
-- Returns TRUE if the request is within limits, FALSE if blocked.
-- Uses a dedicated rate_limit_buckets table with a sliding window.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rate_limit_buckets (
    id          uuid        PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    action      text        NOT NULL,
    identifier  text        NOT NULL,
    request_count int       NOT NULL DEFAULT 1,
    window_start timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_rate_bucket UNIQUE (action, identifier)
);

ALTER TABLE public.rate_limit_buckets ENABLE ROW LEVEL SECURITY;
-- Only service role (edge functions) can access this table
-- No client policies needed

CREATE INDEX IF NOT EXISTS idx_rlb_action_id ON public.rate_limit_buckets (action, identifier);

CREATE OR REPLACE FUNCTION public.enforce_edge_rate_limit(
    p_action        TEXT,
    p_identifier    TEXT,
    p_window_seconds INT,
    p_max_requests  INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now         TIMESTAMPTZ := now();
    v_window_start TIMESTAMPTZ := v_now - (p_window_seconds || ' seconds')::INTERVAL;
    v_count       INT;
BEGIN
    -- Upsert: insert a fresh bucket or update existing
    INSERT INTO rate_limit_buckets (action, identifier, request_count, window_start)
    VALUES (p_action, p_identifier, 1, v_now)
    ON CONFLICT (action, identifier) DO UPDATE
        SET request_count = CASE
                WHEN rate_limit_buckets.window_start < v_window_start
                -- Window has expired — reset the bucket
                THEN 1
                ELSE rate_limit_buckets.request_count + 1
            END,
            window_start = CASE
                WHEN rate_limit_buckets.window_start < v_window_start
                THEN v_now
                ELSE rate_limit_buckets.window_start
            END
    RETURNING request_count INTO v_count;

    RETURN v_count <= p_max_requests;
END;
$$;

GRANT EXECUTE ON FUNCTION public.enforce_edge_rate_limit(TEXT, TEXT, INT, INT) TO service_role;
-- Do NOT grant to anon or authenticated — only edge functions (service role) call this
;

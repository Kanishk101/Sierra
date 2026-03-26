import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// check-resource-overlap  (Sierra Fleet Management System)
//
// verify_jwt: FALSE
// Why: The Supabase Swift SDK's FunctionsClient sends the anon key as the
// Authorization header when verify_jwt is checked by the gateway. This causes
// fast (~100-400ms) 401s before the Deno runtime even starts.
//
// Manual JWT verification below uses auth.getUser(accessToken) explicitly,
// with standardized 401 payloads for deterministic client retry behavior.
//
// POST body (JSON):
// {
//   driver_id:       string  (UUID)
//   vehicle_id:      string  (UUID)
//   start:           string  (ISO-8601 datetime)
//   end:             string  (ISO-8601 datetime)
//   exclude_trip_id: string? (UUID, optional)
// }

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed. Use POST.");
  }

  // ── JWT verification via GoTrue (proven pattern) ──────────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : null;
  if (!jwt) {
    return unauthorized("missing_token", "Missing Authorization bearer token.");
  }

  const supabaseAnon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { auth: { persistSession: false } }
  );

  const { data: { user }, error: authError } = await supabaseAnon.auth.getUser(jwt);
  if (authError || !user) {
    console.error("[check-resource-overlap] JWT validation failed:", authError?.message);
    return unauthorized(
      "invalid_or_expired_token",
      "Invalid or expired access token.",
      authError?.message
    );
  }
  // ──────────────────────────────────────────────────────────────────────────

  let body: { driver_id: string; vehicle_id: string; start: string; end: string; exclude_trip_id?: string | null; };
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "Invalid JSON body.");
  }

  const { driver_id, vehicle_id, start, end, exclude_trip_id } = body;
  if (!driver_id || !vehicle_id || !start || !end) {
    return errorResponse(400, "Missing required fields: driver_id, vehicle_id, start, end.");
  }

  const startDate = new Date(start);
  const endDate   = new Date(end);
  if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    return errorResponse(400, "start and end must be valid ISO-8601 datetimes.");
  }
  if (endDate <= startDate) {
    return errorResponse(400, "end must be after start.");
  }

  // Service role client for the SECURITY DEFINER RPC — bypasses RLS
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  const { data, error } = await supabaseAdmin.rpc("check_resource_overlap", {
    p_driver_id:       driver_id,
    p_vehicle_id:      vehicle_id,
    p_start:           startDate.toISOString(),
    p_end:             endDate.toISOString(),
    p_exclude_trip_id: exclude_trip_id ?? null,
  });

  if (error) {
    console.error("[check-resource-overlap] RPC error:", error);
    return errorResponse(500, error.message);
  }

  const row    = Array.isArray(data) ? data[0] : data;
  const result = {
    driver_conflict:  row?.driver_conflict  ?? false,
    vehicle_conflict: row?.vehicle_conflict ?? false,
  };

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
});

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin":  "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type, apikey, x-client-info",
  };
}

function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

function unauthorized(code: "missing_token" | "invalid_or_expired_token", message: string, detail?: string): Response {
  return new Response(JSON.stringify({
    error: "Unauthorized",
    code,
    message,
    detail: detail ?? null,
  }), {
    status: 401,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

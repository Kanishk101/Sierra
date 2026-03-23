import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// check-resource-overlap  (Sierra Fleet Management System)
//
// verify_jwt: TRUE
// The Supabase gateway validates the Bearer token before this function runs.
// The Swift SDK (v2+) sends the session access_token as Authorization: Bearer
// automatically via supabase.functions.invoke() — no manual JWT handling needed.
//
// POST body (JSON):
// {
//   driver_id:       string  (UUID — lowercase or uppercase, LOWER() applied in SQL)
//   vehicle_id:      string  (UUID)
//   start:           string  (ISO-8601 datetime)
//   end:             string  (ISO-8601 datetime)
//   exclude_trip_id: string? (UUID, optional — exclude current trip when editing)
// }

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed. Use POST.");
  }

  // JWT already verified by gateway. Use service-role to query all trips
  // (SECURITY DEFINER RPC bypasses per-row RLS for conflict detection).
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  let body: {
    driver_id: string;
    vehicle_id: string;
    start: string;
    end: string;
    exclude_trip_id?: string | null;
  };

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

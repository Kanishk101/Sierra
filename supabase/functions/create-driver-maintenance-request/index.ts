import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// create-driver-maintenance-request
//
// verify_jwt: FALSE
// Caller JWT is validated explicitly via auth.getUser(accessToken).
// Inserts maintenance_tasks with service-role client to bypass table RLS
// while preserving caller identity in created_by_admin_id.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface CreateRequestPayload {
  vehicle_id: string;
  title: string;
  task_description: string;
  source_inspection_id?: string | null;
  due_date?: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed. Use POST." });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return unauthorized("missing_token", "Missing Authorization bearer token.");
    }
    const accessToken = authHeader.slice(7).trim();
    if (!accessToken) {
      return unauthorized("missing_token", "Missing Authorization bearer token.");
    }

    const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: { user }, error: userErr } = await anonClient.auth.getUser(accessToken);
    if (userErr || !user) {
      return unauthorized(
        "invalid_or_expired_token",
        "Invalid or expired access token.",
        userErr?.message
      );
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: staffRow, error: staffErr } = await adminClient
      .from("staff_members")
      .select("id, role")
      .eq("id", user.id)
      .single();
    if (staffErr || !staffRow) {
      return json(403, { error: "Caller not found in staff_members." });
    }

    const allowedRoles = new Set(["driver", "maintenancePersonnel", "fleetManager"]);
    if (!allowedRoles.has(String(staffRow.role))) {
      return json(403, { error: "Role is not allowed to create maintenance request." });
    }

    const body = await req.json() as CreateRequestPayload;
    const vehicleId = body.vehicle_id?.trim().toLowerCase();
    const title = body.title?.trim();
    const description = body.task_description?.trim();
    const sourceInspectionId = body.source_inspection_id?.trim() || null;
    const dueDateRaw = body.due_date?.trim();

    if (!vehicleId || !title || !description) {
      return json(400, { error: "Missing required fields: vehicle_id, title, task_description." });
    }

    const dueDate = dueDateRaw && !isNaN(Date.parse(dueDateRaw))
      ? new Date(dueDateRaw)
      : new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);

    const insertPayload = {
      vehicle_id: vehicleId,
      created_by_admin_id: user.id.toLowerCase(),
      title,
      task_description: description,
      status: "Pending",
      task_type: "Inspection Defect",
      request_origin: "inspection_report",
      source_inspection_id: sourceInspectionId,
      due_date: dueDate.toISOString(),
    };

    const { data: inserted, error: insertErr } = await adminClient
      .from("maintenance_tasks")
      .insert(insertPayload)
      .select("id")
      .single();

    if (insertErr || !inserted) {
      return json(500, { error: insertErr?.message ?? "Failed to create maintenance request." });
    }

    return json(200, { id: inserted.id });
  } catch (err) {
    return json(500, { error: String(err) });
  }
});

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function unauthorized(
  code: "missing_token" | "invalid_or_expired_token",
  message: string,
  detail?: string
): Response {
  return json(401, {
    error: "Unauthorized",
    code,
    message,
    detail: detail ?? null,
  });
}

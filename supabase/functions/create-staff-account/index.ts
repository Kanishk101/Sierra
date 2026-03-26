import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// create-staff-account  (Sierra Fleet Management System)
//
// verify_jwt: FALSE
// Same verified auth pattern used across critical functions:
// - verify_jwt remains FALSE at gateway level
// - explicit caller JWT validation via auth.getUser(accessToken)
// - standardized 401 payloads for deterministic client retry behavior
//
// POST body (JSON):
// { email, password, name, role: "driver" | "maintenancePersonnel" }

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface CreateStaffPayload {
  email:    string;
  password: string;
  name:     string;
  role:     "driver" | "maintenancePersonnel";
}

Deno.serve(async (req: Request) => {
  const t0 = Date.now();
  console.log("[create-staff-account] START v11", req.method);

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // ── Step 1: Extract Bearer token ──────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      console.error("[create-staff-account] Missing Bearer token");
      return unauthorized("missing_token", "Missing Authorization bearer token.");
    }
    const accessToken = authHeader.slice(7).trim();
    if (!accessToken) {
      return unauthorized("missing_token", "Missing Authorization bearer token.");
    }
    console.log("[create-staff-account] token_length=", accessToken.length);

    // ── Step 2: Validate token via GoTrue (proven pattern) ────────────────
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user }, error: userErr } = await adminClient.auth.getUser(accessToken);
    if (userErr || !user) {
      console.error("[create-staff-account] GoTrue rejected token:", userErr?.message);
      return unauthorized(
        "invalid_or_expired_token",
        "Invalid or expired access token.",
        userErr?.message
      );
    }
    const callerId = user.id;
    console.log("[create-staff-account] Caller validated: sub=", callerId);

    // ── Step 3: Verify caller is a fleet manager ──────────────────────────
    const { data: staffRow, error: staffErr } = await adminClient
      .from("staff_members")
      .select("role")
      .eq("id", callerId)
      .single();

    console.log("[create-staff-account] role=", staffRow?.role, "err=", staffErr?.message);

    if (staffErr || !staffRow) {
      return json(403, { error: "Caller not found in staff_members" });
    }
    if (String(staffRow.role) !== "fleetManager") {
      return json(403, { error: "Only fleet managers can create staff accounts" });
    }

    // ── Step 4: Parse and validate body ───────────────────────────────────
    const body: CreateStaffPayload = await req.json();
    const { email, password, name, role } = body;

    console.log("[create-staff-account] Creating: email=", email, "name=", name, "role=", role);

    if (!email || !password || !name || !role) {
      return json(400, { error: "Missing required fields: email, password, name, role" });
    }
    if (!["driver", "maintenancePersonnel"].includes(role)) {
      return json(400, { error: "Role must be 'driver' or 'maintenancePersonnel'" });
    }

    // ── Step 5: Create Supabase Auth user ─────────────────────────────────
    const { data: authUser, error: authError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authError || !authUser.user) {
      console.error("[create-staff-account] Auth user creation failed:", authError?.message);
      return json(400, { error: authError?.message ?? "Failed to create auth user" });
    }

    const userId = authUser.user.id;
    console.log("[create-staff-account] Auth user created:", userId);

    // ── Step 6: Insert staff_members row (rollback on failure) ────────────
    const { error: dbError } = await adminClient.from("staff_members").insert({
      id:                  userId,
      name,
      email,
      role,
      status:              "Pending Approval",
      availability:        "Unavailable",
      is_first_login:      true,
      is_profile_complete: false,
      is_approved:         false,
    });

    if (dbError) {
      console.error("[create-staff-account] DB insert failed, rolling back:", dbError.message);
      await adminClient.auth.admin.deleteUser(userId);
      return json(500, { error: `DB insert failed: ${dbError.message}` });
    }

    console.log("[create-staff-account] Done in", Date.now() - t0, "ms userId=", userId);
    return json(200, { id: userId, email });

  } catch (err) {
    console.error("[create-staff-account] Unexpected error:", err);
    return json(500, { error: String(err) });
  }
});

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function unauthorized(code: "missing_token" | "invalid_or_expired_token", message: string, detail?: string): Response {
  return json(401, {
    error: "Unauthorized",
    code,
    message,
    detail: detail ?? null,
  });
}

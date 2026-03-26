// update-vehicle-status edge function
// verify_jwt: true — only authenticated maintenance users can call this.
//
// Updates a vehicle's status, bypassing RLS via service role.
// Authorization: caller must be the maintenance personnel assigned to
// an active maintenance task for the target vehicle.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")         ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface UpdateVehicleStatusPayload {
  vehicleId: string;
  status: string; // e.g. "Idle", "Busy", "Maintenance"
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // ── 1. Require Authorization header ──────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Admin client — service role, bypasses RLS
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ── 2. Verify calling user JWT ────────────────────────────────────────────
    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: callerUser }, error: callerErr } = await callerClient.auth.getUser();
    if (callerErr || !callerUser) {
      return new Response(JSON.stringify({ error: "Invalid caller session" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // ── 3. Parse + validate request body ─────────────────────────────────────
    const body: UpdateVehicleStatusPayload = await req.json();
    const { vehicleId, status } = body;

    if (!vehicleId || typeof vehicleId !== "string" || vehicleId.trim() === "") {
      return new Response(JSON.stringify({ error: "vehicleId is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
    if (!status || typeof status !== "string" || status.trim() === "") {
      return new Response(JSON.stringify({ error: "status is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const allowedStatuses = ["Idle", "Busy", "Active", "In Maintenance", "Out of Service"];
    if (!allowedStatuses.includes(status)) {
      return new Response(JSON.stringify({ error: `Invalid status. Allowed: ${allowedStatuses.join(", ")}` }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // ── 4. Verify caller is assigned to a maintenance task for this vehicle ──
    const { data: callerStaff, error: staffErr } = await adminClient
      .from("staff_members")
      .select("id, role")
      .eq("id", callerUser.id)
      .single();

    if (staffErr || !callerStaff) {
      return new Response(JSON.stringify({ error: "Caller not found in staff_members" }), {
        status: 403,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Fleet managers can update any vehicle status
    if (callerStaff.role !== "fleetManager") {
      // Maintenance personnel must be assigned to an active task for this vehicle
      const { data: assignedTasks, error: taskErr } = await adminClient
        .from("maintenance_tasks")
        .select("id")
        .eq("vehicle_id", vehicleId.trim().toLowerCase())
        .eq("assigned_to_id", callerUser.id)
        .in("status", ["Assigned", "In Progress"])
        .limit(1);

      if (taskErr || !assignedTasks || assignedTasks.length === 0) {
        return new Response(
          JSON.stringify({ error: "You are not assigned to an active maintenance task for this vehicle" }),
          { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }
    }

    // ── 5. Update vehicle status via service role (bypasses RLS) ─────────────
    const { error: updateErr } = await adminClient
      .from("vehicles")
      .update({ status: status, updated_at: new Date().toISOString() })
      .eq("id", vehicleId.trim().toLowerCase());

    if (updateErr) {
      console.error("[update-vehicle-status] Update failed:", updateErr);
      return new Response(JSON.stringify({ error: `Update failed: ${updateErr.message}` }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    return new Response(
      JSON.stringify({ success: true, vehicleId: vehicleId.trim(), status }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );

  } catch (err) {
    console.error("[update-vehicle-status] Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

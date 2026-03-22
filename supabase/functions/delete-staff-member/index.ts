// delete-staff-member edge function
// verify_jwt: true — only authenticated fleet managers can call this.
//
// Deletes a staff member atomically:
//   1. Verifies the caller is a fleet manager
//   2. Prevents self-deletion
//   3. Deletes staff_members row (blocks app access immediately)
//   4. Deletes Supabase Auth user via admin API (non-fatal if this fails —
//      the staff_members row is gone so the user cannot sign in anyway,
//      and the orphaned auth user can be cleaned up from the dashboard)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")         ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DeleteStaffPayload {
  staffMemberId: string; // UUID string of the staff member to delete
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

    // ── 3. Verify caller is a fleet manager ───────────────────────────────────
    const { data: callerRow, error: callerRoleErr } = await adminClient
      .from("staff_members")
      .select("role")
      .eq("id", callerUser.id)
      .single();

    if (callerRoleErr || !callerRow || callerRow.role !== "fleetManager") {
      return new Response(JSON.stringify({ error: "Only fleet managers can delete staff members" }), {
        status: 403,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // ── 4. Parse + validate request body ─────────────────────────────────────
    const body: DeleteStaffPayload = await req.json();
    const { staffMemberId } = body;

    if (!staffMemberId || typeof staffMemberId !== "string" || staffMemberId.trim() === "") {
      return new Response(JSON.stringify({ error: "staffMemberId is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const targetId = staffMemberId.trim().toLowerCase();

    // ── 5. Prevent self-deletion ──────────────────────────────────────────────
    if (targetId === callerUser.id.toLowerCase()) {
      return new Response(JSON.stringify({ error: "You cannot delete your own account" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // ── 6. Confirm target staff member exists ─────────────────────────────────
    const { data: targetRow, error: fetchErr } = await adminClient
      .from("staff_members")
      .select("id, email, role")
      .eq("id", targetId)
      .single();

    if (fetchErr || !targetRow) {
      return new Response(JSON.stringify({ error: `Staff member not found: ${targetId}` }), {
        status: 404,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Prevent deleting another fleet manager
    if (targetRow.role === "fleetManager") {
      return new Response(JSON.stringify({ error: "Cannot delete another fleet manager account" }), {
        status: 403,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // ── 7. Delete staff_members row ───────────────────────────────────────────
    const { error: dbError } = await adminClient
      .from("staff_members")
      .delete()
      .eq("id", targetId);

    if (dbError) {
      console.error("[delete-staff-member] DB delete failed:", dbError);
      return new Response(JSON.stringify({ error: `DB delete failed: ${dbError.message}` }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // ── 8. Delete Supabase Auth user (non-fatal) ──────────────────────────────
    // staff_members row is gone — user cannot sign in regardless.
    // Auth deletion failure is logged but does NOT fail the request.
    const { error: authDeleteErr } = await adminClient.auth.admin.deleteUser(targetId);
    if (authDeleteErr) {
      console.warn(
        `[delete-staff-member] Auth user deletion non-fatal for ${targetId}:`,
        authDeleteErr.message
      );
    }

    return new Response(
      JSON.stringify({ success: true, deletedId: targetId }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );

  } catch (err) {
    console.error("[delete-staff-member] Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

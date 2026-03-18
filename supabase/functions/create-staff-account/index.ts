// create-staff-account edge function
// verify_jwt: true — only authenticated fleet managers can call this.
//
// Creates a Supabase Auth user + staff_members row atomically.
// Rolls back the auth user if the DB insert fails.
// Password goes to auth.admin.createUser() only — staff_members has no
// password column (dropped in migration 20260318000001).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")         ?? "";

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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Verify calling user JWT
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

    // Verify caller is a fleet manager
    const { data: staffRow } = await adminClient
      .from("staff_members")
      .select("role")
      .eq("id", callerUser.id)
      .single();

    if (!staffRow || staffRow.role !== "fleetManager") {
      return new Response(JSON.stringify({ error: "Only fleet managers can create staff accounts" }), {
        status: 403,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const body: CreateStaffPayload = await req.json();
    const { email, password, name, role } = body;

    if (!email || !password || !name || !role) {
      return new Response(JSON.stringify({ error: "Missing required fields: email, password, name, role" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    if (!["driver", "maintenancePersonnel"].includes(role)) {
      return new Response(JSON.stringify({ error: "Role must be 'driver' or 'maintenancePersonnel'" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Create Supabase Auth user — password stored here as bcrypt, never in staff_members
    const { data: authUser, error: authError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authError || !authUser.user) {
      return new Response(JSON.stringify({ error: authError?.message ?? "Failed to create auth user" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const userId = authUser.user.id;

    // Insert staff_members row — no password field (column dropped 2026-03-18)
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
      // Rollback: remove the auth user we just created
      await adminClient.auth.admin.deleteUser(userId);
      return new Response(JSON.stringify({ error: `DB insert failed: ${dbError.message}` }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    return new Response(
      JSON.stringify({ id: userId, email }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (err) {
    console.error("[create-staff-account] error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

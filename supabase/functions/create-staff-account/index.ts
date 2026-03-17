// Deploy with: supabase functions deploy create-staff-account
// Secrets required:
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
//   supabase secrets set SUPABASE_URL=https://ldqcdngdlbbiojlnbnjg.supabase.co
//   supabase secrets set SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

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
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Require a valid JWT in the Authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Admin client - only used server-side, never sent to iOS
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Verify the calling user's JWT is valid
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

    // Verify the caller is a fleet manager
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

    // Parse and validate body
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

    // Create the Supabase Auth user (email_confirm: true skips confirmation email)
    const { data: authUser, error: authError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authError || !authUser.user) {
      const msg = authError?.message ?? "Failed to create auth user";
      return new Response(JSON.stringify({ error: msg }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const userId = authUser.user.id;

    // Insert staff_members row
    const { error: dbError } = await adminClient.from("staff_members").insert({
      id:                   userId,
      name,
      email,
      role,
      status:               "Pending Approval",
      availability:         "Unavailable",
      is_first_login:       true,
      is_profile_complete:  false,
      is_approved:          false,
    });

    if (dbError) {
      // Rollback: delete the auth user we just created
      await adminClient.auth.admin.deleteUser(userId);
      return new Response(JSON.stringify({ error: `DB insert failed: ${dbError.message}` }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    return new Response(
      JSON.stringify({ id: userId, email }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      }
    );
  } catch (err) {
    console.error("create-staff-account error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

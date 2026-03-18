// Deploy with: supabase functions deploy sign-in --no-verify-jwt
// Secrets required:
//   SUPABASE_SERVICE_ROLE_KEY
//   SUPABASE_URL
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { email, password } = await req.json();

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: "Missing email or password" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Service-role client: bypasses RLS entirely — credentials are verified here
    // so the iOS anon key never needs to query staff_members unauthenticated.
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Verify email + password against staff_members.password
    const { data: rows, error: dbErr } = await adminClient
      .from("staff_members")
      .select("id, email, name, role, is_first_login, is_profile_complete, is_approved, rejection_reason, phone, created_at")
      .eq("email", email)
      .eq("password", password)
      .limit(1);

    if (dbErr || !rows || rows.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid credentials" }),
        { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const staffRow = rows[0];

    // Sync Supabase Auth password so supabase.auth.signInWithPassword always
    // succeeds on the iOS side — fixes drift from password changes that only
    // updated staff_members and never touched Supabase Auth.
    const { error: syncErr } = await adminClient.auth.admin.updateUserById(
      staffRow.id,
      { password }
    );
    if (syncErr) {
      console.error("[sign-in] Auth password sync error:", syncErr.message);
      // Non-fatal — still return the row; iOS will get a signInWithPassword
      // error and surface it to the user if sync truly failed.
    }

    return new Response(JSON.stringify(staffRow), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (err) {
    console.error("[sign-in] Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

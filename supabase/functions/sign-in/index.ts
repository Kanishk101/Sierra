// sign-in edge function — v2 (pure Supabase Auth)
//
// Called by iOS AFTER supabase.auth.signInWithPassword() succeeds.
// Receives the user's valid JWT, fetches the staff_members profile row,
// and returns it so the iOS app can build its AuthUser model.
//
// Credentials are NEVER handled here — Supabase Auth owns that entirely.
// verify_jwt: true  (Supabase validates the JWT before this function runs)

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
    // Service-role client for the profile fetch (bypasses RLS)
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Extract the caller's user ID from the validated JWT
    const authHeader = req.headers.get("Authorization") ?? "";
    const anonClient = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user }, error: userErr } = await anonClient.auth.getUser();
    if (userErr || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Fetch the staff profile row — no password field, it no longer exists
    const { data: rows, error: dbErr } = await adminClient
      .from("staff_members")
      .select("id, email, name, role, is_first_login, is_profile_complete, is_approved, rejection_reason, phone, created_at")
      .eq("id", user.id)
      .limit(1);

    if (dbErr || !rows || rows.length === 0) {
      return new Response(
        JSON.stringify({ error: "Staff profile not found" }),
        { status: 404, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    return new Response(JSON.stringify(rows[0]), {
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

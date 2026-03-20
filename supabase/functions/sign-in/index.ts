// sign-in edge function — v9 (ES256 FIX)
//
// ROOT CAUSE:
//   This Supabase project issues ES256 (ECDSA) access tokens.
//   The edge function gateway 'verify_jwt: true' validates using the project's
//   HS256 JWT secret — ES256 ≠ HS256, so EVERY iOS access token was rejected
//   with 401 before this function body even ran.
//
//   The old code also called anonClient.auth.getUser() WITHOUT passing the token
//   string, which caused "missing sub claim" (it sent the anon key instead).
//
// FIX:
//   verify_jwt: false — bypass the broken HS256 gateway check.
//   Call adminClient.auth.getUser(accessToken) passing the raw JWT string.
//   GoTrue validates ES256 correctly using its own key pair.
//   Service-role client then fetches the staff_members profile (bypasses RLS).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  const t0 = Date.now();
  const ms = () => Date.now() - t0;
  console.log(`[sign-in v9] ====== START ======`);

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // STEP 1: Extract Bearer token
    const authHeader = req.headers.get("Authorization") ?? "";
    console.log(`[sign-in v9] T+${ms()}ms STEP1 auth header length=${authHeader.length}`);

    if (!authHeader.startsWith("Bearer ")) {
      console.error(`[sign-in v9] no Bearer token`);
      return new Response(JSON.stringify({ error: "Unauthorized: no Bearer token" }), {
        status: 401, headers: { "Content-Type": "application/json", ...corsHeaders }
      });
    }

    const accessToken = authHeader.slice(7).trim();
    console.log(`[sign-in v9] T+${ms()}ms token parts=${accessToken.split(".").length} len=${accessToken.length}`);
    console.log(`[sign-in v9] token prefix: ${accessToken.substring(0, 30)}`);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // STEP 2: Validate token via GoTrue (handles ES256 correctly)
    // adminClient.auth.getUser(token) passes the JWT to GoTrue /auth/v1/user.
    // GoTrue validates ES256 using its own public key — this is the correct path.
    console.log(`[sign-in v9] T+${ms()}ms STEP2 calling getUser(token)`);
    const { data: { user }, error: userErr } = await adminClient.auth.getUser(accessToken);
    console.log(`[sign-in v9] T+${ms()}ms getUser done. user=${user?.id ?? "null"} err=${userErr?.message ?? "none"}`);

    if (userErr || !user) {
      console.error(`[sign-in v9] getUser failed: ${userErr?.message} status=${userErr?.status}`);
      return new Response(JSON.stringify({ error: "Unauthorized", detail: userErr?.message }), {
        status: 401, headers: { "Content-Type": "application/json", ...corsHeaders }
      });
    }

    // STEP 3: Fetch staff_members profile (service-role bypasses RLS)
    console.log(`[sign-in v9] T+${ms()}ms STEP3 querying staff_members id=${user.id}`);
    const { data: rows, error: dbErr } = await adminClient
      .from("staff_members")
      .select("id,email,name,role,is_first_login,is_profile_complete,is_approved,rejection_reason,phone,created_at")
      .eq("id", user.id)
      .limit(1);

    console.log(`[sign-in v9] T+${ms()}ms DB done. rows=${rows?.length ?? 0} err=${dbErr?.message ?? "none"}`);

    if (dbErr) {
      return new Response(JSON.stringify({ error: "Database error", detail: dbErr.message }), {
        status: 500, headers: { "Content-Type": "application/json", ...corsHeaders }
      });
    }

    if (!rows || rows.length === 0) {
      console.error(`[sign-in v9] no staff_members row for ${user.id}`);
      return new Response(JSON.stringify({ error: "Staff profile not found" }), {
        status: 404, headers: { "Content-Type": "application/json", ...corsHeaders }
      });
    }

    const profile = rows[0];
    console.log(`[sign-in v9] SUCCESS T+${ms()}ms role=${profile.role}`);
    console.log(`[sign-in v9] ====== END ======`);

    return new Response(JSON.stringify(profile), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });

  } catch (err) {
    console.error(`[sign-in v9] EXCEPTION T+${ms()}ms: ${err}`);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

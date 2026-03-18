// reset-password edge function
// verify_jwt: false — caller has no session during password reset.
//
// Accepts: { email: string, reset_token: string, new_password: string }
// Validates a short-lived UUID token from the password_reset_tokens table,
// then calls auth.admin.updateUserById() to set the new Supabase Auth password.
// Marks the token as used (single-use enforcement).
//
// Deploy: supabase functions deploy reset-password --no-verify-jwt

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
    const { email, reset_token, new_password } = await req.json();

    if (!email || !reset_token || !new_password) {
      return new Response(JSON.stringify({ error: "Missing fields" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Validate the reset token against the database
    const { data: tokens, error: tokenErr } = await admin
      .from("password_reset_tokens")
      .select("user_id, expires_at, used")
      .eq("email", email)
      .eq("token", reset_token)
      .limit(1);

    if (tokenErr || !tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const tokenRow = tokens[0];

    if (tokenRow.used) {
      return new Response(JSON.stringify({ error: "Token already used" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    if (new Date(tokenRow.expires_at) < new Date()) {
      return new Response(JSON.stringify({ error: "Token expired" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Update Supabase Auth password (bcrypt-hashed server-side by Supabase)
    const { error: updateErr } = await admin.auth.admin.updateUserById(
      tokenRow.user_id,
      { password: new_password }
    );

    if (updateErr) {
      console.error("[reset-password] auth update error:", updateErr.message);
      return new Response(JSON.stringify({ error: updateErr.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Mark token as used — prevents replay attacks
    await admin
      .from("password_reset_tokens")
      .update({ used: true })
      .eq("token", reset_token);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (err) {
    console.error("[reset-password] unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

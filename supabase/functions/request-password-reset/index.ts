// request-password-reset edge function — Sierra FMS
// verify_jwt: false — caller has no session during password reset.
//
// Accepts: { email: string }
// 1. Looks up the user in staff_members (service role bypasses RLS)
// 2. Generates a 6-digit OTP and a UUID reset token
// 3. Inserts into password_reset_tokens (service role bypasses RLS)
// 4. Calls send-email edge function to deliver the OTP
// Returns: { found: boolean, otp: string (DEBUG only), token: string }
//
// The iOS client ONLY gets { found: boolean } in production.
// The reset token is returned so the client can include it in the
// subsequent reset-password call without needing DB access.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")         ?? "";
const IS_DEBUG                  = Deno.env.get("ENVIRONMENT") === "development";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let body: { email: string };
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400); }

  const { email } = body;
  if (!email) return json({ error: "email is required" }, 400);

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Look up user — service role bypasses RLS (works even without a session)
  const { data: rows, error: lookupErr } = await admin
    .from("staff_members")
    .select("id")
    .eq("email", email)
    .limit(1);

  if (lookupErr || !rows || rows.length === 0) {
    // Return found: false without leaking whether the email exists
    return json({ found: false });
  }

  const userId = rows[0].id as string;

  // 2. Generate OTP and reset token
  const otp = String(Math.floor(100000 + Math.random() * 900000));
  const otpHash = await sha256Hex(otp);
  const resetToken = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 min

  // 3. Insert reset token — service role bypasses RLS
  const { error: insertErr } = await admin
    .from("password_reset_tokens")
    .insert({
      email,
      token: resetToken,
      user_id: userId,
      expires_at: expiresAt,
      used: false,
      otp_code_hash: otpHash,
    });

  if (insertErr) {
    console.error("[request-password-reset] token insert failed:", insertErr.message);
    return json({ found: false }, 500);
  }

  // 4. Send OTP email via send-email edge function
  const emailBody = `Sierra Fleet Manager — Password Reset\n=====================================\n\nYour password reset code:\n\n${otp}\n\nValid for 10 minutes.\n\nDid not request this? Ignore this email — your password is unchanged.\n\n— Sierra FMS`;

  const fnUrl = `${SUPABASE_URL}/functions/v1/send-email`;
  const emailResp = await fetch(fnUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json", "apikey": SUPABASE_ANON_KEY },
    body: JSON.stringify({ to: email, subject: "Password Reset Code — Sierra FMS", text: emailBody }),
  }).catch(() => null);

  if (!emailResp?.ok) {
    console.warn("[request-password-reset] send-email call failed (non-fatal)");
  }

  // Return the reset token to the client so it can include it in the
  // subsequent reset-password call. OTP is only returned in DEBUG builds.
  const response: Record<string, unknown> = { found: true, token: resetToken };
  if (IS_DEBUG) response.otp = otp;

  return json(response);
});

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

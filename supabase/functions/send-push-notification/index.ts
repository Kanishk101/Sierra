// send-push-notification edge function
// verify_jwt: false — called by Postgres DB trigger using service role key.
// The function validates the Authorization header internally.
//
// Sends an APNs push notification to all registered devices for a recipient.
// Required env vars:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   APNS_KEY_ID       — 10-char key ID from Apple Developer Portal
//   APNS_TEAM_ID      — 10-char Team ID from Apple Developer Portal
//   APNS_PRIVATE_KEY  — ES256 private key contents (PEM format, newlines as \n)
//   APNS_BUNDLE_ID    — e.g. "com.yourcompany.SierraFMS"
//   APNS_ENVIRONMENT  — "sandbox" | "production"

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APNS_KEY_ID               = Deno.env.get("APNS_KEY_ID")               ?? "";
const APNS_TEAM_ID              = Deno.env.get("APNS_TEAM_ID")              ?? "";
const APNS_PRIVATE_KEY          = Deno.env.get("APNS_PRIVATE_KEY")          ?? "";
const APNS_BUNDLE_ID            = Deno.env.get("APNS_BUNDLE_ID")            ?? "com.sierrafms.app";
const APNS_ENVIRONMENT          = Deno.env.get("APNS_ENVIRONMENT")          ?? "sandbox";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PushPayload {
  recipientId: string; // UUID of the staff member to receive the notification
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

// --- APNs JWT Helper ---
async function generateApnsJwt(): Promise<string> {
  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const payload = {
    iss: APNS_TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const headerB64  = encode(header);
  const payloadB64 = encode(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  // Import the ES256 private key
  const pemBody = APNS_PRIVATE_KEY.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const sigBytes = await crypto.subtle.sign(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    key,
    new TextEncoder().encode(signingInput)
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBytes)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${signingInput}.${sig}`;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Accept both service-role key (from DB trigger) and valid user JWT.
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
    const token = authHeader.slice(7).trim();
    if (!token) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const isServiceRole = token === SUPABASE_SERVICE_ROLE_KEY;
    if (!isServiceRole) {
      const { data: { user }, error: authErr } = await adminClient.auth.getUser(token);
      if (authErr || !user) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401, headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
    }

    const body: PushPayload = await req.json();
    const { recipientId, title, body: bodyText, data } = body;

    if (!recipientId || !title || !bodyText) {
      return new Response(JSON.stringify({ error: "Missing required fields: recipientId, title, body" }), {
        status: 400, headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Fetch all registered device tokens for this recipient
    const { data: tokens, error: tokenErr } = await adminClient
      .from("push_tokens")
      .select("device_token")
      .eq("staff_id", recipientId);

    if (tokenErr || !tokens || tokens.length === 0) {
      // No tokens registered — user hasn't granted push permission. Not an error.
      return new Response(
        JSON.stringify({ sent: 0, reason: "no_tokens_registered" }),
        { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const apnsBase = APNS_ENVIRONMENT === "production"
      ? "https://api.push.apple.com"
      : "https://api.sandbox.push.apple.com";

    let sentCount = 0;
    const jwt = await generateApnsJwt();

    for (const { device_token } of tokens) {
      const apnsPayload = {
        aps: {
          alert: { title, body: bodyText },
          sound: "default",
          badge: 1,
        },
        ...(data ?? {}),
      };

      try {
        const res = await fetch(`${apnsBase}/3/device/${device_token}`, {
          method: "POST",
          headers: {
            "authorization": `bearer ${jwt}`,
            "apns-topic": APNS_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "content-type": "application/json",
          },
          body: JSON.stringify(apnsPayload),
        });

        if (res.ok) {
          sentCount++;
        } else {
          const errText = await res.text();
          console.error(`[send-push] APNs error for token ${device_token.slice(0, 8)}…: ${res.status} ${errText}`);
        }
      } catch (sendErr) {
        console.error(`[send-push] fetch failed for token: ${sendErr}`);
      }
    }

    return new Response(
      JSON.stringify({ sent: sentCount, total: tokens.length }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (err) {
    console.error("[send-push-notification] error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

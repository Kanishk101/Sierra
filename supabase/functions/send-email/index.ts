// send-email edge function — Sierra FMS
//
// Sends transactional emails via Gmail SMTP using nodemailer.
// verify_jwt: false — called during login/reset flows before any session exists.
//
// Secrets required (set via: supabase secrets set KEY=value):
//   GMAIL_USER          — e.g. fleet.manager.system.infosys@gmail.com
//   GMAIL_APP_PASSWORD  — 16-char Gmail App Password (NOT the account password)
//   GMAIL_SENDER_NAME   — e.g. "Sierra Fleet Manager"
//
// POST body (JSON): { to: string, subject: string, text: string }
// Response:         { sent: boolean } | { error: string }

import nodemailer from "npm:nodemailer@6.9.9";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GMAIL_USER         = Deno.env.get("GMAIL_USER")         ?? "";
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD") ?? "";
const GMAIL_SENDER_NAME  = Deno.env.get("GMAIL_SENDER_NAME")  ?? "Sierra Fleet Manager";
const SUPABASE_URL              = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed. Use POST." }, 405);
  }

  if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
    console.error("[send-email] GMAIL_USER or GMAIL_APP_PASSWORD secret not set.");
    return json({ error: "Email service not configured — set GMAIL_USER and GMAIL_APP_PASSWORD secrets." }, 500);
  }

  let body: { to: string; subject: string; text: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  const { to, subject, text } = body;

  if (!to || !subject || !text) {
    return json({ error: "Missing required fields: to, subject, text." }, 400);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const ip = getClientIp(req);
  const recipient = String(to).trim().toLowerCase();

  const ipAllowed = await enforceRateLimit(admin, "send-email-ip", `ip:${ip}`, 600, 20);
  if (!ipAllowed) {
    return json({ error: "Too many requests. Please wait and try again." }, 429);
  }

  const recipientAllowed = await enforceRateLimit(admin, "send-email-recipient", `to:${recipient}`, 600, 5);
  if (!recipientAllowed) {
    return json({ error: "Too many emails sent to this recipient. Please wait." }, 429);
  }

  try {
    const transporter = nodemailer.createTransport({
      host:   "smtp.gmail.com",
      port:   465,
      secure: true,
      auth: {
        user: GMAIL_USER,
        pass: GMAIL_APP_PASSWORD,
      },
    });

    const info = await transporter.sendMail({
      from:    `"${GMAIL_SENDER_NAME}" <${GMAIL_USER}>`,
      to,
      subject,
      text,
    });

    console.log(`[send-email] ✅ Sent to ${to} — messageId: ${info.messageId}`);
    return json({ sent: true }, 200);

  } catch (err) {
    console.error("[send-email] SMTP error:", err);
    return json({ error: String(err) }, 500);
  }
});

function json(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

async function enforceRateLimit(
  admin: ReturnType<typeof createClient>,
  action: string,
  identifier: string,
  windowSeconds: number,
  maxRequests: number,
): Promise<boolean> {
  const { data, error } = await admin.rpc("enforce_edge_rate_limit", {
    p_action: action,
    p_identifier: identifier,
    p_window_seconds: windowSeconds,
    p_max_requests: maxRequests,
  });

  if (error) {
    console.error("[send-email] rate-limit rpc failed:", error.message);
    return false;
  }

  return Boolean(data);
}

function getClientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for") ?? "";
  const first = forwarded.split(",")[0]?.trim();
  if (first && first.length > 0) return first;
  return "unknown";
}

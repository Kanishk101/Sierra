// Deploy with: supabase functions deploy notify-fleet-manager
// Set secrets: supabase secrets set RESEND_API_KEY=re_xxx FLEET_MANAGER_EMAIL=admin@yourdomain.com FROM_EMAIL=noreply@yourdomain.com

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const RESEND_API_KEY      = Deno.env.get("RESEND_API_KEY") ?? "";
const FLEET_MANAGER_EMAIL = Deno.env.get("FLEET_MANAGER_EMAIL") ?? "fleetmanager@sierra.com";
const FROM_EMAIL          = Deno.env.get("FROM_EMAIL") ?? "noreply@sierra.app";

interface NotifyPayload {
  applicantName:  string;
  applicantEmail: string;
  role:           string;
  submittedAt:    string;
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload: NotifyPayload = await req.json();
    const { applicantName, applicantEmail, role, submittedAt } = payload;

    const roleDisplay = role === "driver" ? "Driver" : "Maintenance Personnel";
    const subject     = `New Staff Application — ${roleDisplay}`;
    const html        = `
      <h2>New Staff Application Received</h2>
      <p>A new staff member has submitted their application on Sierra Fleet.</p>
      <table>
        <tr><td><strong>Name:</strong></td><td>${applicantName}</td></tr>
        <tr><td><strong>Email:</strong></td><td>${applicantEmail}</td></tr>
        <tr><td><strong>Role:</strong></td><td>${roleDisplay}</td></tr>
        <tr><td><strong>Submitted:</strong></td><td>${submittedAt}</td></tr>
      </table>
      <p>Log in to Sierra Fleet to review and approve or reject this application.</p>
    `;

    // If no Resend key, skip silently (dev mode)
    if (!RESEND_API_KEY) {
      console.log("RESEND_API_KEY not set — skipping email notification");
      return new Response(JSON.stringify({ sent: false, reason: "no_api_key" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from:    FROM_EMAIL,
        to:      FLEET_MANAGER_EMAIL,
        subject,
        html,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Resend API error: ${err}`);
    }

    return new Response(JSON.stringify({ sent: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("notify-fleet-manager error:", err);
    return new Response(JSON.stringify({ sent: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

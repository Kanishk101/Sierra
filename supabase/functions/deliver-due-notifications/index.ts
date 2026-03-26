// deliver-due-notifications edge function
// verify_jwt: false — uses GoTrue auth.getUser() to validate the caller.
//
// Called by the iOS app on every app-open / foreground event via
// AppDataStore.loadDriverData(). Marks all past-due scheduled
// notifications as is_delivered=true, which fires the
// fn_send_push_on_notification_delivered trigger for each one,
// sending the push at the correct time rather than at insert time.
//
// Why this exists:
//   pg_cron is not available on this project. The iOS app calling this
//   on foreground is an effective substitute for most practical cases
//   (app is foregrounded around the time reminders are due).
//   Local UNUserNotificationCenter scheduling (TripReminderService) handles
//   background delivery; this function syncs the in-app notification inbox.

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
    // Validate caller — must be an authenticated user
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const accessToken = authHeader.slice(7).trim();
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user }, error: userErr } = await adminClient.auth.getUser(accessToken);
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized", detail: userErr?.message }), {
        status: 401, headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Call the DB function to mark due notifications as delivered
    // The DB trigger fn_send_push_on_notification_delivered handles push dispatch.
    const { data, error: rpcError } = await adminClient.rpc("deliver_scheduled_notifications");

    if (rpcError) {
      console.error("[deliver-due-notifications] RPC error:", rpcError.message);
      return new Response(JSON.stringify({ error: rpcError.message }), {
        status: 500, headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const deliveredCount = data as number ?? 0;
    console.log(`[deliver-due-notifications] Delivered ${deliveredCount} scheduled notifications for user ${user.id}`);

    return new Response(
      JSON.stringify({ delivered: deliveredCount }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (err) {
    console.error("[deliver-due-notifications] Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

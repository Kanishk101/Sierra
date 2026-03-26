// deliver-scheduled-notifications — v3
// verify_jwt: false — validates Authorization header internally.
//
// DUAL PURPOSE:
//   1. Seeds app_secrets.service_role_key on first run (activates the DB
//      pg_net push triggers which were previously dead because the key
//      was not accessible from trigger functions).
//   2. Delivers any past-due scheduled notifications (1-hr accept reminders,
//      30-min pre-inspection reminders) by flipping is_delivered = TRUE,
//      which fires the DB-level push triggers, AND by directly calling
//      send-push-notification as a direct fallback.
//
// CALL SITES:
//   - iOS app: AppDataStore.loadDriverData() on driver login/foreground
//   - iOS app: AppDataStore.loadAll() on fleet manager login/foreground
//   - iOS app: SierraApp.onChange(.active) on every foreground resume

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")              ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Unauthorized" }, 401);
  }

  // Accept any valid user JWT or the service role key
  const token      = authHeader.slice(7).trim();
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Validate: either service role key OR a valid Supabase user session
  const isServiceRole = token === SUPABASE_SERVICE_ROLE_KEY;
  if (!isServiceRole) {
    const { data: { user }, error } = await adminClient.auth.getUser(token);
    if (error || !user) return json({ error: "Unauthorized" }, 401);
  }

  // ── Step 1: Self-seed app_secrets (idempotent) ───────────────────
  try {
    await adminClient
      .from("app_secrets")
      .upsert(
        [
          { key: "supabase_url",     value: SUPABASE_URL },
          { key: "service_role_key", value: SUPABASE_SERVICE_ROLE_KEY },
        ],
        { onConflict: "key" }
      );
    console.log("[deliver-scheduled-notifications] app_secrets seeded/verified");
  } catch (seedErr) {
    console.warn("[deliver-scheduled-notifications] seed warning:", seedErr);
  }

  // ── Step 2: Find all past-due undelivered scheduled notifications ──
  const { data: pending, error: fetchErr } = await adminClient
    .from("notifications")
    .select("id, recipient_id, title, body, type, entity_type, entity_id")
    .lte("scheduled_for", new Date().toISOString())
    .eq("is_delivered", false);

  if (fetchErr) {
    console.error("[deliver-scheduled-notifications] fetch error:", fetchErr.message);
    return json({ error: fetchErr.message }, 500);
  }

  if (!pending || pending.length === 0) {
    return json({ delivered: 0, message: "nothing_pending", seeded: true });
  }

  const ids = pending.map((n: { id: string }) => n.id);
  console.log(`[deliver-scheduled-notifications] Delivering ${ids.length} notifications`);

  // ── Step 3: Flip is_delivered = TRUE ──────────────────────────────
  const { error: updateErr } = await adminClient
    .from("notifications")
    .update({ is_delivered: true })
    .in("id", ids);

  if (updateErr) {
    console.error("[deliver-scheduled-notifications] update error:", updateErr.message);
    return json({ error: updateErr.message }, 500);
  }

  // ── Step 4: Direct push fallback ────────────────────────────────
  // BUG 4 FIX: Pass Authorization header with service role key so
  // send-push-notification doesn't reject with 401.
  let pushSent = 0;
  for (const notif of pending) {
    try {
      const { error: pushErr } = await adminClient.functions.invoke(
        "send-push-notification",
        {
          headers: { Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
          body: {
            recipientId: notif.recipient_id,
            title:       notif.title,
            body:        notif.body,
            data: {
              type:     notif.type,
              entityId: notif.entity_id ?? "",
            },
          },
        }
      );
      if (!pushErr) pushSent++;
      else console.warn(`[deliver-scheduled-notifications] push warn for ${notif.id}:`, pushErr.message);
    } catch (e) {
      console.warn(`[deliver-scheduled-notifications] push exception for ${notif.id}:`, e);
    }
  }

  console.log(`[deliver-scheduled-notifications] ✅ delivered=${ids.length} pushSent=${pushSent}`);
  return json({ delivered: ids.length, pushSent, seeded: true });
});

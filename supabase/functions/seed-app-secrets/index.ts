// seed-app-secrets (deprecated/locked)
// verify_jwt: true
//
// This function is intentionally disabled. Secret seeding now happens inside
// deliver-scheduled-notifications with service-role context.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  return new Response(
    JSON.stringify({
      error: "deprecated",
      message: "seed-app-secrets is disabled; use deliver-scheduled-notifications bootstrap flow.",
    }),
    {
      status: 410,
      headers: { "Content-Type": "application/json", ...cors },
    }
  );
});

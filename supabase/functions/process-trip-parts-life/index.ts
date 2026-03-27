import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type UUID = string;

interface RequestPayload {
  trip_id: UUID;
  fallback_distance_km?: number | null;
}

interface PartLifeProfile {
  id: UUID;
  vehicle_id: UUID;
  service_interval_km: number;
  remaining_km: number;
  total_consumed_km: number;
  depletion_threshold_km: number;
  service_cycle_count: number;
  last_service_task_id: UUID | null;
  last_processed_trip_id: UUID | null;
  created_at: string;
  updated_at: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed. Use POST." });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return unauthorized("missing_token", "Missing Authorization bearer token.");
    }
    const accessToken = authHeader.slice(7).trim();
    if (!accessToken) {
      return unauthorized("missing_token", "Missing Authorization bearer token.");
    }

    const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: authData, error: userErr } = await anonClient.auth.getUser(accessToken);
    const user = authData.user;
    if (userErr || !user) {
      return unauthorized("invalid_or_expired_token", "Invalid or expired access token.", userErr?.message);
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: staffRow, error: staffErr } = await adminClient
      .from("staff_members")
      .select("id, role")
      .eq("id", user.id)
      .single();

    if (staffErr || !staffRow) {
      return json(403, { error: "Caller not found in staff_members." });
    }

    const allowedRoles = new Set(["driver", "maintenancePersonnel", "fleetManager"]);
    if (!allowedRoles.has(String(staffRow.role))) {
      return json(403, { error: "Role is not allowed to process parts life." });
    }

    const body = (await req.json()) as RequestPayload;
    const tripId = body.trip_id?.trim().toLowerCase();
    if (!tripId) {
      return json(400, { error: "Missing required field: trip_id" });
    }

    const { data: tripRow, error: tripErr } = await adminClient
      .from("trips")
      .select("id, task_id, vehicle_id, start_mileage, end_mileage, status, created_by_admin_id")
      .eq("id", tripId)
      .single();

    if (tripErr || !tripRow) {
      return json(404, { error: "Trip not found." });
    }

    const vehicleId = String(tripRow.vehicle_id ?? "").trim().toLowerCase();
    if (!vehicleId) {
      return json(400, { error: "Trip has no assigned vehicle_id." });
    }

    let distanceKm = 0;
    const startMileage = typeof tripRow.start_mileage === "number" ? tripRow.start_mileage : null;
    const endMileage = typeof tripRow.end_mileage === "number" ? tripRow.end_mileage : null;

    if (startMileage !== null && endMileage !== null && endMileage >= startMileage) {
      distanceKm = endMileage - startMileage;
    } else if (typeof body.fallback_distance_km === "number" && body.fallback_distance_km > 0) {
      distanceKm = body.fallback_distance_km;
    }

    let profile = await ensureProfile(adminClient, vehicleId);

    if (distanceKm > 0) {
      const { error: ledgerErr } = await adminClient
        .from("vehicle_trip_distance_ledger")
        .insert({
          trip_id: tripId,
          vehicle_id: vehicleId,
          distance_km: distanceKm,
        });

      if (ledgerErr) {
        // Duplicate trip processing should be idempotent.
        if (String(ledgerErr.code) === "23505") {
          profile = await ensureProfile(adminClient, vehicleId);
          return json(200, {
            trip_id: tripId,
            vehicle_id: vehicleId,
            distance_km_applied: 0,
            service_task_created: false,
            service_task_id: null,
            profile,
          });
        }
        return json(500, { error: ledgerErr.message });
      }

      const nextRemaining = Math.max(0, Number(profile.remaining_km) - distanceKm);
      const nextConsumed = Math.max(0, Number(profile.total_consumed_km) + distanceKm);

      const { data: updatedProfile, error: profileUpdateErr } = await adminClient
        .from("vehicle_part_life_profiles")
        .update({
          remaining_km: nextRemaining,
          total_consumed_km: nextConsumed,
          last_processed_trip_id: tripId,
        })
        .eq("id", profile.id)
        .select()
        .single();

      if (profileUpdateErr || !updatedProfile) {
        return json(500, { error: profileUpdateErr?.message ?? "Failed to update profile." });
      }

      profile = updatedProfile;
    }

    let serviceTaskId: string | null = null;
    let serviceTaskCreated = false;

    const shouldCreateServiceTask = Number(profile.remaining_km) <= Number(profile.depletion_threshold_km);

    if (shouldCreateServiceTask) {
      const { data: openServiceTask, error: openTaskErr } = await adminClient
        .from("maintenance_tasks")
        .select("id")
        .eq("vehicle_id", vehicleId)
        .eq("task_type", "Scheduled")
        .in("status", ["Pending", "Assigned", "In Progress"])
        .limit(1)
        .maybeSingle();

      if (openTaskErr) {
        return json(500, { error: openTaskErr.message });
      }

      if (openServiceTask?.id) {
        serviceTaskId = String(openServiceTask.id);
      } else {
        const creatorId = await resolveServiceTaskCreatorId(
          adminClient,
          String(tripRow.created_by_admin_id ?? "").toLowerCase(),
          user.id.toLowerCase(),
        );

        const { data: vehicleRow } = await adminClient
          .from("vehicles")
          .select("license_plate, name")
          .eq("id", vehicleId)
          .single();

        const vehicleLabel = vehicleRow?.license_plate || vehicleRow?.name || vehicleId.slice(0, 8).toUpperCase();
        const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

        const { data: insertedTask, error: insertTaskErr } = await adminClient
          .from("maintenance_tasks")
          .insert({
            vehicle_id: vehicleId,
            created_by_admin_id: creatorId,
            title: `Scheduled Service Due - ${vehicleLabel}`,
            task_description: `Auto-generated service request after trip ${String(tripRow.task_id ?? tripId).toUpperCase()} consumed ${distanceKm.toFixed(2)} km and parts life reached ${Number(profile.remaining_km).toFixed(2)} km remaining.`,
            status: "Pending",
            task_type: "Scheduled",
            request_origin: "parts_life_auto",
            source_trip_id: tripId,
            due_date: dueDate,
          })
          .select("id")
          .single();

        if (insertTaskErr || !insertedTask) {
          return json(500, { error: insertTaskErr?.message ?? "Failed to create service task." });
        }

        serviceTaskId = insertedTask.id;
        serviceTaskCreated = true;
      }

      // Keep vehicle blocked for allocation as soon as service is due/open.
      const { error: vehicleStatusErr } = await adminClient
        .from("vehicles")
        .update({ status: "In Maintenance" })
        .eq("id", vehicleId);
      if (vehicleStatusErr) {
        return json(500, { error: vehicleStatusErr.message });
      }
    }

    return json(200, {
      trip_id: tripId,
      vehicle_id: vehicleId,
      distance_km_applied: distanceKm,
      service_task_created: serviceTaskCreated,
      service_task_id: serviceTaskId,
      profile,
    });
  } catch (err) {
    return json(500, { error: String(err) });
  }
});

async function ensureProfile(adminClient: ReturnType<typeof createClient>, vehicleId: string): Promise<PartLifeProfile> {
  const { data: existing, error: existingErr } = await adminClient
    .from("vehicle_part_life_profiles")
    .select()
    .eq("vehicle_id", vehicleId)
    .maybeSingle();

  if (existingErr) {
    throw new Error(existingErr.message);
  }

  if (existing) {
    return existing as PartLifeProfile;
  }

  const { data: inserted, error: insertErr } = await adminClient
    .from("vehicle_part_life_profiles")
    .insert({ vehicle_id: vehicleId })
    .select()
    .single();

  if (insertErr || !inserted) {
    throw new Error(insertErr?.message ?? "Failed to create profile.");
  }

  return inserted as PartLifeProfile;
}

async function resolveServiceTaskCreatorId(
  adminClient: ReturnType<typeof createClient>,
  tripCreatorId: string,
  callerId: string,
): Promise<string> {
  if (tripCreatorId) {
    const { data: creator } = await adminClient
      .from("staff_members")
      .select("id, role")
      .eq("id", tripCreatorId)
      .maybeSingle();

    if (creator?.id && creator.role === "fleetManager") {
      return String(creator.id).toLowerCase();
    }
  }

  const { data: fallbackAdmin } = await adminClient
    .from("staff_members")
    .select("id")
    .eq("role", "fleetManager")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (fallbackAdmin?.id) {
    return String(fallbackAdmin.id).toLowerCase();
  }

  return callerId;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function unauthorized(
  code: "missing_token" | "invalid_or_expired_token",
  message: string,
  detail?: string,
): Response {
  return json(401, {
    error: "Unauthorized",
    code,
    message,
    detail: detail ?? null,
  });
}

# Phase 10 — Supabase Backend: RLS Policy Gaps, Missing Columns, and Data Integrity

## Context
- **Project:** Sierra FMS — Supabase project `ldqcdngdlbbiojlnbnjg` (region: ap-south-1)
- **Architecture:** No RLS enforcement (all business logic in Swift). However, missing UPDATE policies still cause silent failures for certain write paths.
- **Tools:** Use `supabase:apply_migration` for DDL (schema changes). Use `supabase:execute_sql` for enum ALTER VALUE and one-shot fixes.

---

## Fix 1 — Missing UPDATE RLS Policies on 6 Tables

The following tables have SELECT + INSERT policies but NO UPDATE policy. This means any attempt to UPDATE rows in these tables from the iOS client will be silently denied by RLS (the query returns success but 0 rows are affected):

| Table | Affected Operations |
|---|---|
| `activity_logs` | Marking logs as read |
| `geofence_events` | — (append-only in practice, acceptable) |
| `proof_of_deliveries` | Updating POD after initial capture |
| `trip_expenses` | Updating expense records |
| `vehicle_location_history` | — (append-only, acceptable) |

For tables that are intentionally append-only (`geofence_events`, `vehicle_location_history`), no fix needed.

For tables that need UPDATE:

```sql
-- activity_logs: allow authenticated users to mark their own entries read
CREATE POLICY al_update ON activity_logs FOR UPDATE TO authenticated
  USING (true)  -- fleet manager updates any; simplified since no RLS enforcement
  WITH CHECK (true);

-- proof_of_deliveries: driver can update their own
CREATE POLICY pod_update ON proof_of_deliveries FOR UPDATE TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

-- trip_expenses: driver can update their own  
CREATE POLICY te_update ON trip_expenses FOR UPDATE TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());
```

Apply via `supabase:apply_migration` with name `add_missing_update_policies`.

---

## Fix 2 — Verify `route_deviation_events` Table Has Correct Schema for `driverId`

The Swift model `RouteDeviationEvent` has `driverId: UUID` (non-optional). Verify that the DB column `driver_id` is `NOT NULL`. If it's nullable, the decoder could crash on null rows.

```sql
SELECT column_name, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'route_deviation_events' AND column_name = 'driver_id';
```

If `is_nullable = YES`, either:
a) Add a NOT NULL constraint (requires all rows have driver_id — check existing data first)
b) Make `RouteDeviationEvent.driverId: UUID?` in Swift

Option (b) is safer — apply it in `Sierra/Shared/Models/RouteDeviationEvent.swift`.

---

## Fix 3 — `trips` Table: Verify `driver_rating` Column Type

`Trip.driverRating: Int?` in Swift maps to `driver_rating smallint nullable` in DB — confirmed correct. No fix needed.

However, the Swift decoder uses `Int` for `driverRating`. Supabase returns `smallint` as an integer. This should decode correctly. Verify in a test build that `trip.driverRating` decodes without error.

---

## Fix 4 — `spare_parts_requests` Table: Confirm Status Enum Values Match Swift

The Swift `SparePartsRequestStatus` enum has:
```swift
case pending   = "Pending"
case approved  = "Approved"
case rejected  = "Rejected"
case fulfilled = "Fulfilled"
```

Verify the DB enum:
```sql
SELECT unnest(enum_range(NULL::spare_parts_request_status));
```

If the DB enum values don't match (e.g., lowercase `pending` vs Swift `Pending`), align them. Either update the Swift rawValues to match DB lowercase, or migrate the DB enum.

To check and align:
```sql
-- If DB uses lowercase:
-- Update Swift to: case pending = "pending", case approved = "approved", etc.
-- OR update DB enum values (requires DROP and recreate for text changes)
```

Do NOT blindly run ALTER TYPE ADD VALUE for this — check the actual DB enum values first via the SELECT above.

---

## Fix 5 — `notifications` Table: Add DELETE Policy (for notification cleanup)

Currently there is no DELETE policy on `notifications`. Old notifications accumulate forever. Add a policy allowing users to delete their own:

```sql
CREATE POLICY notif_delete ON notifications FOR DELETE TO authenticated
  USING (recipient_id = auth.uid());
```

Apply via migration. Also add a corresponding `deleteNotification(id: UUID)` method to `NotificationService` and `AppDataStore.deleteNotification(id:)` that removes from both DB and in-memory array.

---

## Fix 6 — `rate_limit_buckets` Table: Confirm RLS Policy Is Correct

The earlier audit showed `rate_limit_buckets` has an `ALL` policy but no SELECT-specific policy. This table is used by the `enforce_edge_rate_limit` RPC function. Since it's accessed via a service-role key inside Edge Functions, the existing `ALL` policy (which covers service role) is correct. No change needed.

---

## Fix 7 — Add `route_stops` Column to `trips` Table (for Phase 07 stops persistence)

This fix enables the stops created in `CreateTripView` (Phase 07) to be stored in the DB.

```sql
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_stops JSONB DEFAULT '[]'::jsonb;
```

Apply via migration with name `add_route_stops_to_trips`.

The JSON format should be:
```json
[
  {"name": "Stop Name", "latitude": 12.345, "longitude": 67.890, "order": 1},
  ...
]
```

In Swift:
- Add `var routeStops: [RouteStop]?` to `Trip.swift`
- Add `struct RouteStop: Codable { let name: String; let latitude: Double; let longitude: Double; let order: Int }`
- Add `case routeStops = "route_stops"` to `Trip.CodingKeys`
- `TripService` insert/update payloads need to include `route_stops` serialised as a JSON string or handled by the Supabase Swift SDK's JSONB encoding

---

## Fix 8 — Verify Supabase Realtime Is Enabled on Required Tables

Realtime must be enabled on these tables for the subscription channels in AppDataStore to receive events:
- `emergency_alerts` (INSERT — for real-time SOS alerts to fleet manager)
- `trips` (INSERT + UPDATE — for fleet manager to see trip status changes live)
- `staff_members` (UPDATE — for availability changes)
- `vehicles` (UPDATE — for status/location changes)
- `notifications` (INSERT — for push notifications to users)

Verify via Supabase dashboard or:
```sql
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';
```

Realtime publication must include these tables. If not enabled, run:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE emergency_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE trips;
ALTER PUBLICATION supabase_realtime ADD TABLE staff_members;
ALTER PUBLICATION supabase_realtime ADD TABLE vehicles;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
```

(These may already be enabled from previous sprints — verify before running.)

---

## Execution Order
1. Fix 1: `add_missing_update_policies` migration
2. Fix 2: Check `route_deviation_events.driver_id` nullability, fix Swift model if needed
3. Fix 4: Verify spare_parts_request_status enum values, fix Swift rawValues if needed
4. Fix 5: `add_notification_delete_policy` migration + service method
5. Fix 7: `add_route_stops_to_trips` migration + Swift model update
6. Fix 8: Verify and enable Realtime publications

## Verification Checklist
- [ ] `UPDATE` on `activity_logs`, `proof_of_deliveries`, `trip_expenses` succeeds from authenticated client
- [ ] `RouteDeviationEvent.driverId` decodes correctly for all DB rows
- [ ] `SparePartsRequestStatus` Swift rawValues match DB enum values exactly
- [ ] Old notifications can be deleted; `store.notifications` array updates in-memory
- [ ] `Trip.routeStops` decodes from DB and encodes back correctly
- [ ] Realtime channels open without errors in Xcode console
- [ ] Migration names are unique and descriptive
- [ ] All migrations are idempotent (`IF NOT EXISTS`, `IF EXISTS`)

# Fix A — Role String Normalisation 🔴 CRITICAL

**Audit ID:** C-13 (root cause), affects all RLS policies, all edge functions, all notification fan-out  
**Priority:** Must be done before any production testing — everything that touches role checks silently fails until this is resolved

---

## The Problem

Three systems store or check staff roles using completely different string values:

| System | Role strings used |
|---|---|
| RLS migration `20260322000001` | `'Admin'`, `'Driver'`, `'Maintenance'` |
| Edge functions (`create-staff-account`, `delete-staff-member`, `update-vehicle-status`) | `'fleetManager'`, `'maintenancePersonnel'` |
| Swift `UserRole` enum | unknown — needs to be verified against actual rawValues |
| `AppDataStore` notification filters | Swift `.fleetManager` (resolves to whatever enum rawValue is) |

If the DB stores `'Admin'` but the RLS policy checks `'fleetManager'`, every policy that looks up the caller's role returns false — geofence CRUD, vehicle CRUD, trip management, notifications all fail silently.

---

## Tasks

### Task 1 — Verify what's actually stored

Before writing any migration, run this query in the Supabase SQL editor to see what role strings are actually in use:

```sql
SELECT DISTINCT role, COUNT(*) as count
FROM public.staff_members
GROUP BY role
ORDER BY count DESC;
```

Also check the Swift enum rawValues in `Sierra/Shared/Models/StaffMember.swift` — look for `enum UserRole` and note the `rawValue` strings.

---

### Task 2 — Write migration `20260322000004_normalise_role_strings.sql`

Create `supabase/migrations/20260322000004_normalise_role_strings.sql` with the following structure:

```sql
-- ============================================================
-- Migration: Normalise role strings across staff_members
-- Target canonical values: 'fleetManager', 'driver', 'maintenancePersonnel'
-- These match the Swift UserRole enum rawValues and edge function checks.
-- ============================================================

-- Step 1: Show current values (for audit trail in migration logs)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT role, COUNT(*) as cnt FROM public.staff_members GROUP BY role LOOP
        RAISE NOTICE 'Current role value: % (count: %)', r.role, r.cnt;
    END LOOP;
END;
$$;

-- Step 2: Normalise all role variants to canonical strings
-- Add/remove variant spellings as needed based on Task 1 findings
UPDATE public.staff_members
    SET role = 'fleetManager'
    WHERE role IN ('Admin', 'admin', 'Fleet Manager', 'fleet_manager', 'FleetManager');

UPDATE public.staff_members
    SET role = 'driver'
    WHERE role IN ('Driver', 'driver');

UPDATE public.staff_members
    SET role = 'maintenancePersonnel'
    WHERE role IN ('Maintenance', 'maintenance', 'MaintenancePersonnel',
                   'maintenance_personnel', 'Maintenance Personnel');

-- Step 3: Verify — should only see the 3 canonical values now
DO $$
DECLARE
    r RECORD;
    bad_count INT := 0;
BEGIN
    FOR r IN
        SELECT DISTINCT role FROM public.staff_members
        WHERE role NOT IN ('fleetManager', 'driver', 'maintenancePersonnel')
    LOOP
        RAISE WARNING 'Unexpected role value still present: %', r.role;
        bad_count := bad_count + 1;
    END LOOP;
    IF bad_count = 0 THEN
        RAISE NOTICE 'Role normalisation complete. All values canonical.';
    END IF;
END;
$$;

-- Step 4: Rewrite all RLS policies using new canonical role strings
-- (Drop and recreate every policy that contains a role check)

-- staff_members policies
DROP POLICY IF EXISTS staff_members_select_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_insert_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_update_admin     ON public.staff_members;
DROP POLICY IF EXISTS staff_members_delete_admin     ON public.staff_members;

CREATE POLICY staff_members_select_admin
    ON public.staff_members FOR SELECT TO authenticated
    USING ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY staff_members_insert_admin
    ON public.staff_members FOR INSERT TO authenticated
    WITH CHECK ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY staff_members_update_admin
    ON public.staff_members FOR UPDATE TO authenticated
    USING  ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager')
    WITH CHECK ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY staff_members_delete_admin
    ON public.staff_members FOR DELETE TO authenticated
    USING ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

-- vehicles policies
DROP POLICY IF EXISTS vehicles_insert_admin ON public.vehicles;
DROP POLICY IF EXISTS vehicles_update_admin ON public.vehicles;
DROP POLICY IF EXISTS vehicles_delete_admin ON public.vehicles;

CREATE POLICY vehicles_insert_admin
    ON public.vehicles FOR INSERT TO authenticated
    WITH CHECK ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY vehicles_update_admin
    ON public.vehicles FOR UPDATE TO authenticated
    USING  ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager')
    WITH CHECK ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY vehicles_delete_admin
    ON public.vehicles FOR DELETE TO authenticated
    USING ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

-- geofences policies
DROP POLICY IF EXISTS geofences_select_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_insert_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_update_admin ON public.geofences;
DROP POLICY IF EXISTS geofences_delete_admin ON public.geofences;

CREATE POLICY geofences_select_admin
    ON public.geofences FOR SELECT TO authenticated
    USING ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY geofences_insert_admin
    ON public.geofences FOR INSERT TO authenticated
    WITH CHECK ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY geofences_update_admin
    ON public.geofences FOR UPDATE TO authenticated
    USING  ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager')
    WITH CHECK ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY geofences_delete_admin
    ON public.geofences FOR DELETE TO authenticated
    USING ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

-- trips policies
DROP POLICY IF EXISTS trips_all_admin          ON public.trips;
DROP POLICY IF EXISTS trips_select_driver      ON public.trips;
DROP POLICY IF EXISTS trips_update_driver      ON public.trips;
DROP POLICY IF EXISTS trips_select_maintenance ON public.trips;

CREATE POLICY trips_all_admin
    ON public.trips FOR ALL TO authenticated
    USING  ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager')
    WITH CHECK ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'fleetManager');

CREATE POLICY trips_select_driver
    ON public.trips FOR SELECT TO authenticated
    USING (
        driver_id = auth.uid()::text
        AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'driver'
    );

CREATE POLICY trips_update_driver
    ON public.trips FOR UPDATE TO authenticated
    USING  (driver_id = auth.uid()::text AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'driver')
    WITH CHECK (driver_id = auth.uid()::text AND (SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'driver');

CREATE POLICY trips_select_maintenance
    ON public.trips FOR SELECT TO authenticated
    USING ((SELECT role FROM public.staff_members WHERE id = auth.uid()) = 'maintenancePersonnel');

-- Step 5: Update trigger functions to use canonical role strings
CREATE OR REPLACE FUNCTION public.fn_notify_on_geofence_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_admin_id   UUID;
    v_event_type TEXT;
    v_geo_name   TEXT;
    v_title      TEXT;
    v_body       TEXT;
BEGIN
    SELECT COALESCE(name, 'Unknown Zone') INTO v_geo_name
      FROM public.geofences WHERE id = NEW.geofence_id;

    v_event_type := CASE WHEN LOWER(NEW.event_type::text) = 'enter' THEN 'entered' ELSE 'exited' END;
    v_title := 'Geofence Alert: ' || v_event_type || ' ' || v_geo_name;
    v_body  := 'Vehicle ' || NEW.vehicle_id::text || ' ' || v_event_type
               || ' geofence zone "' || v_geo_name || '"'
               || ' at ' || TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS UTC');

    -- Use canonical 'fleetManager' role string
    FOR v_admin_id IN
        SELECT id FROM public.staff_members WHERE role = 'fleetManager'
    LOOP
        INSERT INTO public.notifications (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
        VALUES (gen_random_uuid(), v_admin_id::text, 'geofence_alert', v_title, v_body, 'geofence_event', NEW.id::text, false, NOW());
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_notify_driver_trip_assigned()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_scheduled TEXT;
BEGIN
    IF NEW.driver_id IS NULL THEN RETURN NEW; END IF;
    v_scheduled := TO_CHAR(NEW.scheduled_date AT TIME ZONE 'UTC', 'Mon DD, YYYY at HH24:MI UTC');
    INSERT INTO public.notifications (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
    VALUES (
        gen_random_uuid(), NEW.driver_id, 'Trip Assigned',
        'New Trip Assigned: ' || NEW.task_id,
        'You have been assigned a trip from ' || NEW.origin || ' to ' || NEW.destination || ' scheduled for ' || v_scheduled,
        'trip', NEW.id::text, false, NOW()
    );
    RETURN NEW;
END;
$$;
```

---

### Task 3 — Verify Swift enum rawValues

Open `Sierra/Shared/Models/StaffMember.swift` and find `enum UserRole`. Confirm the rawValues are exactly:

```swift
enum UserRole: String, Codable {
    case fleetManager           = "fleetManager"
    case driver                 = "driver"
    case maintenancePersonnel   = "maintenancePersonnel"
}
```

If they differ, update the rawValues to match the canonical strings above.

---

### Task 4 — Update edge function role check consistency

In `supabase/functions/create-staff-account/index.ts`, confirm the role guard reads:
```typescript
if (!staffRow || staffRow.role !== 'fleetManager') {
```

In `supabase/functions/delete-staff-member/index.ts`, confirm:
```typescript
if (callerRoleErr || !callerRow || callerRow.role !== 'fleetManager') {
```

In `supabase/functions/update-vehicle-status/index.ts`, confirm:
```typescript
if (callerStaff.role !== 'fleetManager') {
```

All three should already be using `'fleetManager'` — just verify and note if any differ.

---

## Acceptance Criteria

- `SELECT DISTINCT role FROM staff_members` returns exactly 3 rows: `fleetManager`, `driver`, `maintenancePersonnel`
- Fleet manager can CREATE/UPDATE/DELETE vehicles without RLS error
- Fleet manager can CREATE/UPDATE/DELETE geofences without RLS error
- Driver receives in-app notification when a trip is assigned
- Admin receives geofence event notification when a driver enters a monitored zone

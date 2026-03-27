-- ============================================================
-- Migration: Harden driver live-location backend path
-- Date: 2026-03-27
--
-- Goals:
-- 1) Ensure vehicle_location_history is in Supabase Realtime publication.
-- 2) Provide a SECURITY DEFINER RPC for driver location publishing so
--    driver sessions do not require broad UPDATE rights on vehicles.
-- 3) Ensure vehicle_location_history has explicit RLS policies for
--    fleet managers (full read) and drivers (own rows).
-- ============================================================

-- 1) Ensure realtime publication includes vehicle_location_history.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
       AND EXISTS (
           SELECT 1
             FROM pg_class c
             JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relname = 'vehicle_location_history'
       )
       AND NOT EXISTS (
           SELECT 1
             FROM pg_publication_rel pr
             JOIN pg_publication p ON p.oid = pr.prpubid
             JOIN pg_class c ON c.oid = pr.prrelid
             JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE p.pubname = 'supabase_realtime'
              AND n.nspname = 'public'
              AND c.relname = 'vehicle_location_history'
       )
    THEN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicle_location_history';
    END IF;
END
$$;

-- 2) SECURITY DEFINER RPC for atomic + policy-safe driver publish.
CREATE OR REPLACE FUNCTION public.driver_publish_vehicle_location(
    p_vehicle_id uuid,
    p_trip_id uuid,
    p_driver_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_speed_kmh double precision DEFAULT NULL,
    p_recorded_at timestamptz DEFAULT now()
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth_user uuid := auth.uid();
    v_role_text text;
    v_trip_ok boolean := false;
    v_recorded_at timestamptz := COALESCE(p_recorded_at, now());
BEGIN
    IF v_auth_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    SELECT sm.role::text
      INTO v_role_text
      FROM public.staff_members sm
     WHERE sm.id = v_auth_user;

    IF v_role_text IS NULL THEN
        RAISE EXCEPTION 'Authenticated user is not a staff member'
            USING ERRCODE = '42501';
    END IF;

    IF v_role_text NOT IN ('driver', 'fleetManager') THEN
        RAISE EXCEPTION 'Only drivers or fleet managers can publish vehicle location'
            USING ERRCODE = '42501';
    END IF;

    -- Prevent caller from spoofing another driver.
    IF p_driver_id IS NULL OR p_driver_id <> v_auth_user THEN
        RAISE EXCEPTION 'driver_id does not match authenticated user'
            USING ERRCODE = '42501';
    END IF;

    IF p_latitude < -90 OR p_latitude > 90 OR p_longitude < -180 OR p_longitude > 180 THEN
        RAISE EXCEPTION 'Invalid coordinates'
            USING ERRCODE = '22023';
    END IF;

    SELECT EXISTS (
        SELECT 1
          FROM public.trips t
         WHERE t.id = p_trip_id
           AND t.vehicle_id::text = p_vehicle_id::text
           AND (
               t.driver_id::text = v_auth_user::text
               OR v_role_text = 'fleetManager'
           )
           AND t.status IN ('PendingAcceptance', 'Accepted', 'Scheduled', 'Active')
    )
      INTO v_trip_ok;

    IF NOT v_trip_ok THEN
        RAISE EXCEPTION 'Trip, vehicle, and driver relationship is invalid for live location publish'
            USING ERRCODE = '42501';
    END IF;

    IF to_regclass('public.vehicle_location_history') IS NULL THEN
        RAISE EXCEPTION 'vehicle_location_history table does not exist'
            USING ERRCODE = '42P01';
    END IF;

    INSERT INTO public.vehicle_location_history (
        vehicle_id,
        trip_id,
        driver_id,
        latitude,
        longitude,
        speed_kmh,
        recorded_at
    ) VALUES (
        p_vehicle_id,
        p_trip_id,
        v_auth_user,
        p_latitude,
        p_longitude,
        p_speed_kmh,
        v_recorded_at
    );

    UPDATE public.vehicles
       SET current_latitude = p_latitude,
           current_longitude = p_longitude,
           updated_at = GREATEST(COALESCE(updated_at, v_recorded_at), v_recorded_at)
     WHERE id = p_vehicle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vehicle % not found', p_vehicle_id
            USING ERRCODE = '23503';
    END IF;
END
$$;

REVOKE ALL ON FUNCTION public.driver_publish_vehicle_location(
    uuid, uuid, uuid, double precision, double precision, double precision, timestamptz
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.driver_publish_vehicle_location(
    uuid, uuid, uuid, double precision, double precision, double precision, timestamptz
) TO authenticated;

-- 3) Ensure vehicle_location_history RLS policies are explicit and compatible with app reads.
DO $$
BEGIN
    IF to_regclass('public.vehicle_location_history') IS NOT NULL THEN
        ALTER TABLE public.vehicle_location_history ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS vehicle_location_history_select_fleet_or_driver
            ON public.vehicle_location_history;
        DROP POLICY IF EXISTS vehicle_location_history_insert_driver_or_fleet
            ON public.vehicle_location_history;

        CREATE POLICY vehicle_location_history_select_fleet_or_driver
            ON public.vehicle_location_history
            FOR SELECT
            TO authenticated
            USING (
                (
                    SELECT sm.role::text
                      FROM public.staff_members sm
                     WHERE sm.id = auth.uid()
                ) = 'fleetManager'
                OR driver_id = auth.uid()
            );

        CREATE POLICY vehicle_location_history_insert_driver_or_fleet
            ON public.vehicle_location_history
            FOR INSERT
            TO authenticated
            WITH CHECK (
                driver_id = auth.uid()
                AND (
                    SELECT sm.role::text
                      FROM public.staff_members sm
                     WHERE sm.id = auth.uid()
                ) IN ('driver', 'fleetManager')
            );
    END IF;
END
$$;

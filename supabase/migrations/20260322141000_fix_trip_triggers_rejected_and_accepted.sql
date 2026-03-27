
-- Fix 1: handle_trip_started — also fires when Accepted -> Active (Phase 3)
CREATE OR REPLACE FUNCTION public.handle_trip_started()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    -- Fires for Scheduled -> Active OR Accepted -> Active (Phase 3 acceptance flow)
    IF NEW.status = 'Active' AND OLD.status IN ('Scheduled', 'Accepted') THEN
        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE vehicles SET status = 'Busy', updated_at = now()
            WHERE id = NEW.vehicle_id;
        END IF;
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE staff_members SET availability = 'Busy', updated_at = now()
            WHERE id = NEW.driver_id;
        END IF;
        NEW.actual_start_date = COALESCE(NEW.actual_start_date, now());
    END IF;
    RETURN NEW;
END;
$$;

-- Fix 2: handle_trip_cancelled — also fires for Rejected (driver declined)
CREATE OR REPLACE FUNCTION public.handle_trip_cancelled()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    -- Release resources when trip is Cancelled OR Rejected
    -- Guard: only release if no OTHER Active trip for this driver/vehicle
    IF NEW.status IN ('Cancelled', 'Rejected')
       AND OLD.status NOT IN ('Cancelled', 'Rejected', 'Completed')
    THEN
        IF NEW.vehicle_id IS NOT NULL THEN
            UPDATE vehicles SET status = 'Idle', updated_at = now()
            WHERE id = NEW.vehicle_id
              AND NOT EXISTS (
                  SELECT 1 FROM trips t2
                  WHERE t2.vehicle_id = NEW.vehicle_id
                    AND t2.id <> NEW.id
                    AND t2.status = 'Active'
              );
        END IF;
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE staff_members SET availability = 'Available', updated_at = now()
            WHERE id = NEW.driver_id
              AND NOT EXISTS (
                  SELECT 1 FROM trips t2
                  WHERE t2.driver_id = NEW.driver_id
                    AND t2.id <> NEW.id
                    AND t2.status = 'Active'
              );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
;

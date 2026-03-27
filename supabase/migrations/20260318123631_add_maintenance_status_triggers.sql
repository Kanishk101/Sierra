
-- ============================================================
-- Maintenance Task Status Triggers
-- Fires BEFORE UPDATE on maintenance_tasks
-- 
-- Status flow: Pending → Assigned → In Progress → Completed/Cancelled
--
-- In Progress  → vehicle set to 'In Maintenance'
-- Completed    → vehicle set to 'Idle', notify Fleet Manager
-- Cancelled    → vehicle set to 'Idle' (if it was In Maintenance)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_maintenance_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_admin_id UUID;
BEGIN

  -- In Progress: work has started, lock down the vehicle
  IF NEW.status = 'In Progress' AND OLD.status != 'In Progress' THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles
        SET status = 'In Maintenance', updated_at = now()
        WHERE id = NEW.vehicle_id;
    END IF;
    NEW.updated_at = now();

  -- Completed: repair done, free the vehicle and notify the Fleet Manager
  ELSIF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles
        SET status = 'Idle', updated_at = now()
        WHERE id = NEW.vehicle_id;
    END IF;

    -- Stamp completion time
    NEW.completed_at = COALESCE(NEW.completed_at, now());
    NEW.updated_at   = now();

    -- Notify the Fleet Manager who created the task
    IF NEW.created_by_admin_id IS NOT NULL THEN
      INSERT INTO notifications (
        id,
        recipient_id,
        type,
        title,
        body,
        entity_type,
        entity_id,
        is_read,
        sent_at,
        created_at
      ) VALUES (
        gen_random_uuid(),
        NEW.created_by_admin_id,
        'General',
        'Maintenance Completed',
        COALESCE('Task "' || NEW.title || '" has been marked complete.', 'A maintenance task has been completed.'),
        'maintenance_task',
        NEW.id,
        false,
        now(),
        now()
      );
    END IF;

  -- Cancelled: if work had started (vehicle was locked), free it
  ELSIF NEW.status = 'Cancelled' AND OLD.status != 'Cancelled' THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles
        SET status = 'Idle', updated_at = now()
        WHERE id = NEW.vehicle_id
          AND status = 'In Maintenance';  -- only undo our own lock
    END IF;
    NEW.updated_at = now();

  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_maintenance_status_change
  BEFORE UPDATE OF status ON maintenance_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_maintenance_status_change();
;

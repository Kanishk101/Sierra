
-- ============================================================
-- Maintenance task status triggers
-- When a task goes Assigned/In Progress → vehicle In Maintenance
-- When a task goes Completed → vehicle Idle + notify Fleet Manager
-- When a task goes Cancelled → vehicle Idle (if it was In Maintenance)
-- ============================================================

CREATE OR REPLACE FUNCTION handle_maintenance_task_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_fleet_manager_id uuid;
BEGIN
  -- Assigned or In Progress: lock the vehicle for maintenance
  IF NEW.status IN ('Assigned', 'In Progress') 
     AND OLD.status NOT IN ('Assigned', 'In Progress') THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles
        SET status = 'In Maintenance', updated_at = now()
        WHERE id = NEW.vehicle_id;
    END IF;

  -- Completed: free the vehicle and stamp the completion time
  ELSIF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles
        SET status = 'Idle', updated_at = now()
        WHERE id = NEW.vehicle_id;
    END IF;

    -- Record completion timestamp
    NEW.completed_at := COALESCE(NEW.completed_at, now());

    -- Notify the Fleet Manager who created the task
    IF NEW.created_by_admin_id IS NOT NULL THEN
      INSERT INTO notifications (
        id, recipient_id, type, title, body,
        entity_type, entity_id, is_read, sent_at, created_at
      ) VALUES (
        gen_random_uuid(),
        NEW.created_by_admin_id,
        'General',
        'Maintenance Completed',
        'Task "' || NEW.title || '" has been completed. Vehicle is now available.',
        'maintenance_task',
        NEW.id,
        false,
        now(),
        now()
      );
    END IF;

  -- Cancelled: release the vehicle if it was locked for this task
  ELSIF NEW.status = 'Cancelled' AND OLD.status NOT IN ('Cancelled', 'Completed') THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      -- Only release if no other active maintenance task holds this vehicle
      IF NOT EXISTS (
        SELECT 1 FROM maintenance_tasks
        WHERE vehicle_id = NEW.vehicle_id
          AND id != NEW.id
          AND status IN ('Assigned', 'In Progress')
      ) THEN
        UPDATE vehicles
          SET status = 'Idle', updated_at = now()
          WHERE id = NEW.vehicle_id
            AND status = 'In Maintenance';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER maintenance_task_status_change_trigger
  BEFORE UPDATE OF status ON maintenance_tasks
  FOR EACH ROW
  EXECUTE FUNCTION handle_maintenance_task_status_change();
;

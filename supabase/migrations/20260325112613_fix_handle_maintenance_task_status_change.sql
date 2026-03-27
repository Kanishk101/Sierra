
-- Fix: handle_maintenance_task_status_change should also set vehicle to
-- 'In Maintenance' when task goes directly from 'Pending' to 'In Progress'
-- (edge case) and correctly handle the Open→InProgress work order transition.
-- The original only checked OLD.status NOT IN ('Assigned','In Progress'),
-- which is correct, but the work order status wasn't being updated.
-- This version also syncs work_orders.status when task status changes.

CREATE OR REPLACE FUNCTION handle_maintenance_task_status_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Assigned or In Progress → mark vehicle as In Maintenance
  IF NEW.status IN ('Assigned', 'In Progress')
     AND OLD.status NOT IN ('Assigned', 'In Progress') THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles SET status = 'In Maintenance', updated_at = now()
      WHERE id = NEW.vehicle_id;
    END IF;
  END IF;

  -- In Progress → also set the work order to In Progress if it's Open
  IF NEW.status = 'In Progress' AND OLD.status != 'In Progress' THEN
    UPDATE work_orders
    SET status = 'In Progress',
        started_at = COALESCE(started_at, now()),
        updated_at = now()
    WHERE maintenance_task_id = NEW.id
      AND status IN ('Open', 'On Hold');
  END IF;

  -- Completed → reset vehicle to Idle, stamp completed_at, notify admin
  IF NEW.status = 'Completed' AND OLD.status != 'Completed' THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      UPDATE vehicles SET status = 'Idle', updated_at = now()
      WHERE id = NEW.vehicle_id;
    END IF;
    NEW.completed_at := COALESCE(NEW.completed_at, now());

    -- Also close the work order
    UPDATE work_orders
    SET status = 'Completed',
        completed_at = COALESCE(completed_at, now()),
        updated_at = now()
    WHERE maintenance_task_id = NEW.id
      AND status NOT IN ('Completed', 'Closed');

    -- Notify admin
    IF NEW.created_by_admin_id IS NOT NULL THEN
      INSERT INTO notifications (
        id, recipient_id, type, title, body,
        entity_type, entity_id, is_read, sent_at, created_at
      ) VALUES (
        gen_random_uuid(),
        NEW.created_by_admin_id,
        'Maintenance Complete',
        'Maintenance Completed',
        'Task "' || NEW.title || '" has been completed. Vehicle is now available.',
        'maintenance_task', NEW.id, false, now(), now()
      );
    END IF;

  -- Cancelled → reset vehicle if no other active tasks
  ELSIF NEW.status = 'Cancelled'
        AND OLD.status NOT IN ('Cancelled', 'Completed') THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM maintenance_tasks
        WHERE vehicle_id = NEW.vehicle_id AND id != NEW.id
          AND status IN ('Assigned', 'In Progress')
      ) THEN
        UPDATE vehicles SET status = 'Idle', updated_at = now()
        WHERE id = NEW.vehicle_id AND status = 'In Maintenance';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
;


-- Trigger function: auto-create a work order when a maintenance task moves Pending → Assigned
CREATE OR REPLACE FUNCTION fn_auto_create_work_order()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_wo_type text;
BEGIN
  -- Only fire when status changes from 'Pending' to 'Assigned'
  IF OLD.status = 'Pending' AND NEW.status = 'Assigned' THEN

    -- Determine work order type from task type
    IF NEW.task_type = 'Scheduled' THEN
      v_wo_type := 'service';
    ELSE
      v_wo_type := 'repair';
    END IF;

    -- Create work order (idempotent via ON CONFLICT)
    INSERT INTO work_orders (
      id, maintenance_task_id, vehicle_id, assigned_to_id,
      work_order_type, status, repair_description,
      parts_sub_status, labour_cost_total, parts_cost_total,
      vin_scanned, created_at, updated_at
    ) VALUES (
      gen_random_uuid(), NEW.id, NEW.vehicle_id, NEW.assigned_to_id,
      v_wo_type, 'Open', NEW.task_description,
      'none', 0, 0,
      false, now(), now()
    )
    ON CONFLICT (maintenance_task_id) DO NOTHING;

    -- Notify the assigned technician
    IF NEW.assigned_to_id IS NOT NULL THEN
      INSERT INTO notifications (
        id, recipient_id, type, title, body,
        entity_type, entity_id, is_read, sent_at, created_at
      ) VALUES (
        gen_random_uuid(),
        NEW.assigned_to_id,
        'Task Assigned',
        'New Work Order: ' || NEW.title,
        'You have been assigned a ' || v_wo_type || ' task for vehicle ' || NEW.vehicle_id::text,
        'maintenance_task', NEW.id, false, now(), now()
      );
    END IF;

  END IF;

  RETURN NEW;
END;
$$;

-- Create the trigger (BEFORE UPDATE so it fires before the status-change trigger)
DROP TRIGGER IF EXISTS trg_auto_create_work_order ON maintenance_tasks;
CREATE TRIGGER trg_auto_create_work_order
  BEFORE UPDATE ON maintenance_tasks
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_create_work_order();
;

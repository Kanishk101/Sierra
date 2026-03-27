
-- Remove the older, less complete trigger — keep handle_maintenance_task_status_change
-- which also handles 'Assigned' status and has the multi-task cancel guard
DROP TRIGGER IF EXISTS trg_maintenance_status_change ON maintenance_tasks;
DROP FUNCTION IF EXISTS handle_maintenance_status_change();
;

-- Remove maintenance-task priority system from DB.

ALTER TABLE public.maintenance_tasks
    DROP COLUMN IF EXISTS priority;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'task_priority'
          AND n.nspname = 'public'
    ) THEN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_type t ON t.oid = a.atttypid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE a.attnum > 0
              AND NOT a.attisdropped
              AND t.typname = 'task_priority'
              AND n.nspname = 'public'
        ) THEN
            DROP TYPE public.task_priority;
        END IF;
    END IF;
END;
$$;;


-- When parts_used rows are inserted, updated, or deleted, automatically
-- recalculate and sync work_orders.parts_cost_total.
--
-- Without this, the iOS app has to manually sum all parts and write the total,
-- which creates race conditions when multiple parts are added in quick succession.
-- The trigger keeps the denormalized total always correct.

CREATE OR REPLACE FUNCTION public.sync_work_order_parts_cost()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_work_order_id uuid;
    v_parts_total   double precision;
BEGIN
    -- Identify the affected work order
    v_work_order_id := COALESCE(NEW.work_order_id, OLD.work_order_id);

    -- Sum all parts for that work order
    SELECT COALESCE(SUM(quantity * unit_cost), 0)
      INTO v_parts_total
      FROM parts_used
     WHERE work_order_id = v_work_order_id;

    -- Update the denormalized total on work_orders
    UPDATE work_orders
       SET parts_cost_total = v_parts_total,
           updated_at       = now()
     WHERE id = v_work_order_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Fire after every change to parts_used
CREATE TRIGGER trg_sync_parts_cost
  AFTER INSERT OR UPDATE OR DELETE ON public.parts_used
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_work_order_parts_cost();
;

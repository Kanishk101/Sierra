
-- CRITICAL FIX 2: Fix auth_rls_initplan warnings — wrap auth.uid() in SELECT
-- so it's evaluated once per query, not once per row.

-- ── push_tokens ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS push_tokens_own ON public.push_tokens;
CREATE POLICY push_tokens_own ON public.push_tokens
  FOR ALL
  USING      (staff_id = (SELECT auth.uid()))
  WITH CHECK (staff_id = (SELECT auth.uid()));

-- ── work_order_phases ────────────────────────────────────────────────────────
-- Also MERGES the three overlapping permissive policies into two clean ones
-- (fixes both auth_rls_initplan AND multiple_permissive_policies warnings)

DROP POLICY IF EXISTS "Fleet managers can manage all WO phases"   ON public.work_order_phases;
DROP POLICY IF EXISTS "Maintenance can view own WO phases"        ON public.work_order_phases;
DROP POLICY IF EXISTS "Maintenance can update own WO phases"      ON public.work_order_phases;

-- Single SELECT policy that covers both roles
CREATE POLICY wo_phases_select ON public.work_order_phases
  FOR SELECT
  USING (
    (SELECT role FROM public.staff_members WHERE id = (SELECT auth.uid())) = 'fleetManager'
    OR
    work_order_id IN (
      SELECT id FROM public.work_orders
      WHERE assigned_to_id = (SELECT auth.uid())
    )
  );

-- Single UPDATE policy that covers both roles
CREATE POLICY wo_phases_update ON public.work_order_phases
  FOR UPDATE
  USING (
    (SELECT role FROM public.staff_members WHERE id = (SELECT auth.uid())) = 'fleetManager'
    OR
    work_order_id IN (
      SELECT id FROM public.work_orders
      WHERE assigned_to_id = (SELECT auth.uid())
    )
  );

-- Fleet manager INSERT / DELETE
CREATE POLICY wo_phases_insert ON public.work_order_phases
  FOR INSERT
  WITH CHECK (
    (SELECT role FROM public.staff_members WHERE id = (SELECT auth.uid())) = 'fleetManager'
  );

CREATE POLICY wo_phases_delete ON public.work_order_phases
  FOR DELETE
  USING (
    (SELECT role FROM public.staff_members WHERE id = (SELECT auth.uid())) = 'fleetManager'
  );
;

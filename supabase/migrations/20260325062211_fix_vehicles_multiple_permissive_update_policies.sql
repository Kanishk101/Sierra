
-- CRITICAL FIX 3: Merge the two overlapping UPDATE policies on vehicles
-- (fixes multiple_permissive_policies warning for authenticated UPDATE)

DROP POLICY IF EXISTS vehicles_update                ON public.vehicles;
DROP POLICY IF EXISTS vehicles_update_driver_location ON public.vehicles;

-- Fleet managers can update any column; drivers can only update their own vehicle location cols
CREATE POLICY vehicles_update ON public.vehicles
  FOR UPDATE
  USING (
    (SELECT role FROM public.staff_members WHERE id = (SELECT auth.uid())) = 'fleetManager'
    OR
    assigned_driver_id = (SELECT auth.uid())
  )
  WITH CHECK (
    (SELECT role FROM public.staff_members WHERE id = (SELECT auth.uid())) = 'fleetManager'
    OR
    assigned_driver_id = (SELECT auth.uid())
  );
;

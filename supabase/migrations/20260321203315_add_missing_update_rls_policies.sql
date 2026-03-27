
-- ── activity_logs ────────────────────────────────────────────────────────────
-- Fleet managers need to mark logs as read (is_read = true).
-- Without this, every markAsRead() call returned success from the client
-- but 0 rows were actually updated.

CREATE POLICY al_update ON public.activity_logs
  FOR UPDATE TO authenticated
  USING  (get_my_role() = 'fleetManager')
  WITH CHECK (get_my_role() = 'fleetManager');


-- ── proof_of_deliveries ──────────────────────────────────────────────────────
-- Driver may need to update a POD row after initial insert
-- (e.g. GPS coordinates resolved asynchronously, OTP verification step).
-- Fleet manager needs UPDATE to acknowledge/annotate deliveries.

CREATE POLICY pod_update ON public.proof_of_deliveries
  FOR UPDATE TO authenticated
  USING  ((driver_id = ( SELECT auth.uid())) OR (get_my_role() = 'fleetManager'))
  WITH CHECK ((driver_id = ( SELECT auth.uid())) OR (get_my_role() = 'fleetManager'));


-- ── trip_expenses ────────────────────────────────────────────────────────────
-- Driver may need to correct an expense record; FM may need to approve/flag.

CREATE POLICY te_update ON public.trip_expenses
  FOR UPDATE TO authenticated
  USING  ((driver_id = ( SELECT auth.uid())) OR (get_my_role() = 'fleetManager'))
  WITH CHECK ((driver_id = ( SELECT auth.uid())) OR (get_my_role() = 'fleetManager'));
;

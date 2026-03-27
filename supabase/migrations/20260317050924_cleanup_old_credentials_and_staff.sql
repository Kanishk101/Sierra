
-- ============================================================
-- PHASE 1: CLEANUP
-- Keep only: 70c3213c (fleet.manager.system.infosys@gmail.com)
--            f3439b6b (kanin21stcentury@gmail.com)
-- ============================================================

-- Define keepers
DO $$
DECLARE
  keeper_admin UUID := '70c3213c-25ad-49e2-b175-f53dd5d00271';
  keeper_driver UUID := 'f3439b6b-e55e-4ac9-8608-f1ef8e4fd7d2';
BEGIN

  -- 1. NULL out maintenance_tasks assigned_to for non-keepers
  UPDATE maintenance_tasks
  SET assigned_to_id = NULL
  WHERE assigned_to_id IS NOT NULL
    AND assigned_to_id NOT IN (keeper_admin, keeper_driver);

  -- 2. NULL out vehicles assigned_driver for non-keepers
  UPDATE vehicles
  SET assigned_driver_id = NULL
  WHERE assigned_driver_id IS NOT NULL
    AND assigned_driver_id NOT IN (keeper_admin, keeper_driver);

  -- 3. NULL out driver_profiles.current_vehicle_id (no FK issue, just housekeeping)
  -- Already nullable, fine.

  -- 4. Delete staff_applications for non-keepers
  DELETE FROM staff_applications
  WHERE staff_member_id NOT IN (keeper_admin, keeper_driver);

  -- 5. Delete driver_profiles for non-keepers
  DELETE FROM driver_profiles
  WHERE staff_member_id NOT IN (keeper_admin, keeper_driver);

  -- 6. Delete maintenance_profiles for non-keepers
  DELETE FROM maintenance_profiles
  WHERE staff_member_id NOT IN (keeper_admin, keeper_driver);

  -- 7. Delete staff_members for non-keepers
  DELETE FROM staff_members
  WHERE id NOT IN (keeper_admin, keeper_driver);

END $$;

-- 8. Delete old sierra.test auth users
DELETE FROM auth.identities
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email LIKE '%@sierra.test'
);
DELETE FROM auth.users WHERE email LIKE '%@sierra.test';
;

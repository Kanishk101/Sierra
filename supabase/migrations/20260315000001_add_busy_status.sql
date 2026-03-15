-- ============================================================
-- Migration: Add 'Busy' status to vehicle_status and
--            staff_availability enums
-- Sierra Fleet Management System
-- Date: 2026-03-15
-- ============================================================

-- STEP 1: Extend vehicle_status enum with 'Busy'
-- PostgreSQL ADD VALUE is non-transactional; run outside an
-- explicit transaction block (Supabase dashboard / psql \i).
ALTER TYPE vehicle_status ADD VALUE IF NOT EXISTS 'Busy';

-- STEP 2: Extend staff_availability enum with 'Busy'
ALTER TYPE staff_availability ADD VALUE IF NOT EXISTS 'Busy';

-- STEP 3: Back-fill — migrate any existing 'On Trip' rows
-- to the new unified 'Busy' value.
-- (Safe to re-run; does nothing if no rows match.)
UPDATE staff_members
   SET availability = 'Busy'
 WHERE availability = 'On Trip';

-- STEP 4: Back-fill — any vehicle that has an assigned driver
-- AND a currently active/scheduled trip should be marked Busy.
-- This handles data that existed before this migration.
UPDATE vehicles v
   SET status = 'Busy'
  FROM trips t
 WHERE t.vehicle_id  = v.id::text
   AND t.status      IN ('Scheduled', 'Active')
   AND v.status      NOT IN ('In Maintenance', 'Out of Service', 'Decommissioned');

-- ============================================================
-- END OF MIGRATION
-- ============================================================

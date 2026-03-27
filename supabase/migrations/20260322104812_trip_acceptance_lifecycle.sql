-- Phase 2/3: Trip Acceptance Lifecycle
-- Adds new enum values + acceptance columns to the trips table.

-- 1. Add new status values to trip_status enum
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'PendingAcceptance'
      AND enumtypid = 'trip_status'::regtype
  ) THEN
    ALTER TYPE trip_status ADD VALUE 'PendingAcceptance';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'Accepted'
      AND enumtypid = 'trip_status'::regtype
  ) THEN
    ALTER TYPE trip_status ADD VALUE 'Accepted';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'Rejected'
      AND enumtypid = 'trip_status'::regtype
  ) THEN
    ALTER TYPE trip_status ADD VALUE 'Rejected';
  END IF;
END $$;

-- 2. Add acceptance lifecycle columns to trips table
ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS accepted_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS acceptance_deadline  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejected_reason      TEXT;;

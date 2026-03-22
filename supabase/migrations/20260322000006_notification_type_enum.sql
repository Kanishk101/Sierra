-- ============================================================
-- Migration: Add missing notification_type enum values
-- Sierra Fleet Management System
-- Date: 2026-03-22 (seq 006)
--
-- Context:
-- If notifications.type is a Postgres enum, missing values cause
-- PostgREST to reject INSERTs with "invalid input value for enum"
-- silently breaking all notifications that use those types.
--
-- All target values are Swift NotificationType rawValue strings
-- (space-separated Title Case) from SierraNotification.swift.
--
-- Each DO block uses duplicate_object / undefined_object handlers
-- so this is safe regardless of whether notification_type is an
-- enum or text column, and whether the value already exists.
-- ============================================================

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Trip Assigned';
EXCEPTION WHEN duplicate_object THEN NULL;
         WHEN undefined_object  THEN RAISE NOTICE 'notification_type not an enum — ADD VALUE skipped'; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Trip Accepted';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Trip Rejected';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Trip Cancelled';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Vehicle Assigned';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Maintenance Approved';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Maintenance Rejected';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Maintenance Overdue';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Maintenance Complete';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'SOS Alert';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Defect Alert';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Route Deviation';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Geofence Alert';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Document Expiry';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Inspection Failed';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Emergency';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'General';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

-- ============================================================
-- END OF MIGRATION 006
-- ============================================================

-- Migration: add inspection lifecycle notification types
-- Ensures Postgres enum notification_type accepts new values emitted by app

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Pre-Trip Completed';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Post-Trip Completed';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Pre-Trip Failed';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Post-Trip Failed';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Pre-Trip Warning';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Post-Trip Warning';
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

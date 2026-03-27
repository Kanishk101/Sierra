
-- Add notification_type enum values that Swift uses but DB doesn't have.
-- Each DO block is independent so one failure doesn't block the rest.

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Trip Accepted';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Trip Rejected';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Geofence Alert';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Document Expiry';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Emergency';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'Maintenance Complete';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
;

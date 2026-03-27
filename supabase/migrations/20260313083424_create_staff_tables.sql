
-- Base identity for all staff. id = auth.users.id (same UUID).
CREATE TABLE staff_members (
    id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name                    TEXT,
    role                    user_role NOT NULL,
    status                  staff_status NOT NULL DEFAULT 'Pending Approval',
    email                   TEXT NOT NULL UNIQUE,
    phone                   TEXT,
    availability            staff_availability NOT NULL DEFAULT 'Unavailable',
    date_of_birth           DATE,
    gender                  TEXT,
    address                 TEXT,
    emergency_contact_name  TEXT,
    emergency_contact_phone TEXT,
    aadhaar_number          TEXT,
    profile_photo_url       TEXT,
    is_first_login          BOOLEAN NOT NULL DEFAULT TRUE,
    is_profile_complete     BOOLEAN NOT NULL DEFAULT FALSE,
    is_approved             BOOLEAN NOT NULL DEFAULT FALSE,
    rejection_reason        TEXT,
    joined_date             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Driver-specific credentials and stats (1-1 with staff_members where role = driver).
-- current_vehicle_id FK added after vehicles table is created.
CREATE TABLE driver_profiles (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_member_id       UUID NOT NULL UNIQUE REFERENCES staff_members(id) ON DELETE CASCADE,
    license_number        TEXT NOT NULL,
    license_expiry        DATE NOT NULL,
    license_class         TEXT NOT NULL,
    license_issuing_state TEXT NOT NULL,
    license_document_url  TEXT,
    aadhaar_document_url  TEXT,
    total_trips_completed INT NOT NULL DEFAULT 0,
    total_distance_km     DOUBLE PRECISION NOT NULL DEFAULT 0,
    average_rating        DOUBLE PRECISION,
    current_vehicle_id    UUID,
    notes                 TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Maintenance-specific credentials and stats (1-1 with staff_members where role = maintenance).
CREATE TABLE maintenance_profiles (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_member_id             UUID NOT NULL UNIQUE REFERENCES staff_members(id) ON DELETE CASCADE,
    certification_type          TEXT NOT NULL,
    certification_number        TEXT NOT NULL,
    issuing_authority           TEXT NOT NULL,
    certification_expiry        DATE NOT NULL,
    certification_document_url  TEXT,
    years_of_experience         INT NOT NULL DEFAULT 0,
    specializations             TEXT[] NOT NULL DEFAULT '{}',
    total_tasks_assigned        INT NOT NULL DEFAULT 0,
    total_tasks_completed       INT NOT NULL DEFAULT 0,
    aadhaar_document_url        TEXT,
    notes                       TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Onboarding submission. Common fields + prefixed role-specific columns.
CREATE TABLE staff_applications (
    id                               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_member_id                  UUID NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    role                             user_role NOT NULL,
    submitted_date                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status                           approval_status NOT NULL DEFAULT 'Pending',
    rejection_reason                 TEXT,
    reviewed_by                      UUID REFERENCES staff_members(id) ON DELETE SET NULL,
    reviewed_at                      TIMESTAMPTZ,
    phone                            TEXT NOT NULL,
    date_of_birth                    DATE NOT NULL,
    gender                           TEXT NOT NULL,
    address                          TEXT NOT NULL,
    emergency_contact_name           TEXT NOT NULL,
    emergency_contact_phone          TEXT NOT NULL,
    aadhaar_number                   TEXT NOT NULL,
    aadhaar_document_url             TEXT,
    profile_photo_url                TEXT,
    driver_license_number            TEXT,
    driver_license_expiry            DATE,
    driver_license_class             TEXT,
    driver_license_issuing_state     TEXT,
    driver_license_document_url      TEXT,
    maint_certification_type         TEXT,
    maint_certification_number       TEXT,
    maint_issuing_authority          TEXT,
    maint_certification_expiry       DATE,
    maint_certification_document_url TEXT,
    maint_years_of_experience        INT,
    maint_specializations            TEXT[],
    created_at                       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
;

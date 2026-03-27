
-- 2FA session tracking. OTP stored as SHA-256 hash only, never plaintext.
CREATE TABLE two_factor_sessions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    method        two_factor_method NOT NULL DEFAULT 'email',
    destination   TEXT NOT NULL,
    otp_hash      TEXT NOT NULL,
    expires_at    TIMESTAMPTZ NOT NULL,
    attempt_count INT NOT NULL DEFAULT 0,
    max_attempts  INT NOT NULL DEFAULT 5,
    is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
    is_locked     BOOLEAN NOT NULL DEFAULT FALSE,
    locked_until  TIMESTAMPTZ,
    verified_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Core vehicle registry. Doc fields (insurance, registration) live in vehicle_documents.
CREATE TABLE vehicles (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name               TEXT NOT NULL,
    manufacturer       TEXT NOT NULL,
    model              TEXT NOT NULL,
    year               INT NOT NULL,
    vin                TEXT NOT NULL UNIQUE,
    license_plate      TEXT NOT NULL UNIQUE,
    color              TEXT NOT NULL,
    fuel_type          fuel_type NOT NULL,
    seating_capacity   INT NOT NULL DEFAULT 2,
    status             vehicle_status NOT NULL DEFAULT 'Idle',
    assigned_driver_id UUID REFERENCES staff_members(id) ON DELETE SET NULL,
    current_latitude   DOUBLE PRECISION,
    current_longitude  DOUBLE PRECISION,
    odometer           DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_trips        INT NOT NULL DEFAULT 0,
    total_distance_km  DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add deferred FK from driver_profiles to vehicles
ALTER TABLE driver_profiles
    ADD CONSTRAINT fk_driver_profiles_current_vehicle
    FOREIGN KEY (current_vehicle_id)
    REFERENCES vehicles(id)
    ON DELETE SET NULL;

-- Each row is one document for one vehicle. A vehicle can have many.
CREATE TABLE vehicle_documents (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id        UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    document_type     vehicle_document_type NOT NULL,
    document_number   TEXT NOT NULL,
    issued_date       DATE NOT NULL,
    expiry_date       DATE NOT NULL,
    issuing_authority TEXT NOT NULL,
    document_url      TEXT,
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
;

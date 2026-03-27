
-- Central operational record. Created by admin, executed by driver.
-- proof_of_delivery_id, pre/post_inspection_id are deferred FKs added below.
CREATE TABLE trips (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id               TEXT NOT NULL UNIQUE,
    driver_id             UUID REFERENCES staff_members(id) ON DELETE SET NULL,
    vehicle_id            UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    created_by_admin_id   UUID NOT NULL REFERENCES staff_members(id),
    origin                TEXT NOT NULL,
    destination           TEXT NOT NULL,
    delivery_instructions TEXT NOT NULL DEFAULT '',
    scheduled_date        TIMESTAMPTZ NOT NULL,
    scheduled_end_date    TIMESTAMPTZ,
    actual_start_date     TIMESTAMPTZ,
    actual_end_date       TIMESTAMPTZ,
    start_mileage         DOUBLE PRECISION,
    end_mileage           DOUBLE PRECISION,
    notes                 TEXT NOT NULL DEFAULT '',
    status                trip_status NOT NULL DEFAULT 'Scheduled',
    priority              trip_priority NOT NULL DEFAULT 'Normal',
    proof_of_delivery_id  UUID,
    pre_inspection_id     UUID,
    post_inspection_id    UUID,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Driver fuel entries. trip_id optional (can log outside active trip).
CREATE TABLE fuel_logs (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id            UUID NOT NULL REFERENCES staff_members(id),
    vehicle_id           UUID NOT NULL REFERENCES vehicles(id),
    trip_id              UUID REFERENCES trips(id) ON DELETE SET NULL,
    fuel_quantity_litres DOUBLE PRECISION NOT NULL,
    fuel_cost            DOUBLE PRECISION NOT NULL,
    price_per_litre      DOUBLE PRECISION NOT NULL,
    odometer_at_fill     DOUBLE PRECISION NOT NULL,
    fuel_station         TEXT,
    receipt_image_url    TEXT,
    logged_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pre/post trip inspections. items = JSONB array of InspectionItem.
-- Failed result triggers admin alert and maintenance workflow.
CREATE TABLE vehicle_inspections (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id              UUID NOT NULL REFERENCES trips(id),
    vehicle_id           UUID NOT NULL REFERENCES vehicles(id),
    driver_id            UUID NOT NULL REFERENCES staff_members(id),
    type                 inspection_type NOT NULL,
    overall_result       inspection_result NOT NULL DEFAULT 'Passed',
    items                JSONB NOT NULL DEFAULT '[]',
    defects_reported     TEXT,
    additional_notes     TEXT,
    driver_signature_url TEXT,
    inspected_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add deferred FKs from trips to vehicle_inspections
ALTER TABLE trips
    ADD CONSTRAINT fk_trips_pre_inspection
    FOREIGN KEY (pre_inspection_id) REFERENCES vehicle_inspections(id) ON DELETE SET NULL;

ALTER TABLE trips
    ADD CONSTRAINT fk_trips_post_inspection
    FOREIGN KEY (post_inspection_id) REFERENCES vehicle_inspections(id) ON DELETE SET NULL;

-- One POD per trip (UNIQUE on trip_id).
CREATE TABLE proof_of_deliveries (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id            UUID NOT NULL UNIQUE REFERENCES trips(id),
    driver_id          UUID NOT NULL REFERENCES staff_members(id),
    method             proof_of_delivery_method NOT NULL,
    photo_url          TEXT,
    signature_url      TEXT,
    otp_verified       BOOLEAN NOT NULL DEFAULT FALSE,
    recipient_name     TEXT,
    delivery_latitude  DOUBLE PRECISION,
    delivery_longitude DOUBLE PRECISION,
    captured_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add deferred FK from trips to proof_of_deliveries
ALTER TABLE trips
    ADD CONSTRAINT fk_trips_proof_of_delivery
    FOREIGN KEY (proof_of_delivery_id) REFERENCES proof_of_deliveries(id) ON DELETE SET NULL;

-- Driver SOS/emergency triggers. Enable Realtime on this table.
CREATE TABLE emergency_alerts (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id        UUID NOT NULL REFERENCES staff_members(id),
    trip_id          UUID REFERENCES trips(id) ON DELETE SET NULL,
    vehicle_id       UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    latitude         DOUBLE PRECISION NOT NULL,
    longitude        DOUBLE PRECISION NOT NULL,
    alert_type       emergency_alert_type NOT NULL DEFAULT 'SOS',
    status           emergency_alert_status NOT NULL DEFAULT 'Active',
    description      TEXT,
    acknowledged_by  UUID REFERENCES staff_members(id) ON DELETE SET NULL,
    acknowledged_at  TIMESTAMPTZ,
    resolved_at      TIMESTAMPTZ,
    triggered_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
;


-- Virtual geographic boundaries. is_active allows disabling without deleting.
CREATE TABLE geofences (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                TEXT NOT NULL,
    description         TEXT NOT NULL DEFAULT '',
    latitude            DOUBLE PRECISION NOT NULL,
    longitude           DOUBLE PRECISION NOT NULL,
    radius_meters       DOUBLE PRECISION NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_admin_id UUID NOT NULL REFERENCES staff_members(id),
    alert_on_entry      BOOLEAN NOT NULL DEFAULT TRUE,
    alert_on_exit       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Generated when a vehicle crosses a geofence boundary. Full historical record.
CREATE TABLE geofence_events (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    geofence_id  UUID NOT NULL REFERENCES geofences(id),
    vehicle_id   UUID NOT NULL REFERENCES vehicles(id),
    trip_id      UUID REFERENCES trips(id) ON DELETE SET NULL,
    driver_id    UUID REFERENCES staff_members(id) ON DELETE SET NULL,
    event_type   geofence_event_type NOT NULL,
    latitude     DOUBLE PRECISION NOT NULL,
    longitude    DOUBLE PRECISION NOT NULL,
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Append-only system audit trail. Written by Edge Functions/triggers only.
-- iOS app reads only, never writes directly.
CREATE TABLE activity_logs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type        activity_type NOT NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    actor_id    UUID REFERENCES staff_members(id) ON DELETE SET NULL,
    entity_type TEXT NOT NULL,
    entity_id   UUID,
    severity    activity_severity NOT NULL DEFAULT 'Info',
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
;


-- Admin-facing maintenance request. Can be sourced from manual, emergency alert, or inspection failure.
CREATE TABLE maintenance_tasks (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id           UUID NOT NULL REFERENCES vehicles(id),
    created_by_admin_id  UUID NOT NULL REFERENCES staff_members(id),
    assigned_to_id       UUID REFERENCES staff_members(id) ON DELETE SET NULL,
    title                TEXT NOT NULL,
    task_description     TEXT NOT NULL,
    priority             task_priority NOT NULL DEFAULT 'Medium',
    status               maintenance_task_status NOT NULL DEFAULT 'Pending',
    task_type            maintenance_task_type NOT NULL DEFAULT 'Scheduled',
    source_alert_id      UUID REFERENCES emergency_alerts(id) ON DELETE SET NULL,
    source_inspection_id UUID REFERENCES vehicle_inspections(id) ON DELETE SET NULL,
    due_date             TIMESTAMPTZ NOT NULL,
    completed_at         TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Maintenance-personnel-facing view. One-to-one with maintenance_tasks.
-- total_cost auto-computed from labour + parts.
CREATE TABLE work_orders (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    maintenance_task_id UUID NOT NULL UNIQUE REFERENCES maintenance_tasks(id),
    vehicle_id          UUID NOT NULL REFERENCES vehicles(id),
    assigned_to_id      UUID NOT NULL REFERENCES staff_members(id),
    status              work_order_status NOT NULL DEFAULT 'Open',
    repair_description  TEXT NOT NULL DEFAULT '',
    labour_cost_total   DOUBLE PRECISION NOT NULL DEFAULT 0,
    parts_cost_total    DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_cost          DOUBLE PRECISION GENERATED ALWAYS AS (labour_cost_total + parts_cost_total) STORED,
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    technician_notes    TEXT,
    vin_scanned         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Each row = one part used in one work order. total_cost auto-computed.
CREATE TABLE parts_used (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_order_id UUID NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
    part_name     TEXT NOT NULL,
    part_number   TEXT,
    quantity      INT NOT NULL DEFAULT 1,
    unit_cost     DOUBLE PRECISION NOT NULL,
    total_cost    DOUBLE PRECISION GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    supplier      TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Permanent audit record created when a work_order is closed.
-- total_cost auto-computed.
CREATE TABLE maintenance_records (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id          UUID NOT NULL REFERENCES vehicles(id),
    work_order_id       UUID NOT NULL REFERENCES work_orders(id),
    maintenance_task_id UUID NOT NULL REFERENCES maintenance_tasks(id),
    performed_by_id     UUID NOT NULL REFERENCES staff_members(id),
    issue_reported      TEXT NOT NULL,
    repair_details      TEXT NOT NULL,
    odometer_at_service DOUBLE PRECISION NOT NULL,
    labour_cost         DOUBLE PRECISION NOT NULL DEFAULT 0,
    parts_cost          DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_cost          DOUBLE PRECISION GENERATED ALWAYS AS (labour_cost + parts_cost) STORED,
    status              maintenance_record_status NOT NULL DEFAULT 'Completed',
    service_date        TIMESTAMPTZ NOT NULL,
    next_service_due    TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
;

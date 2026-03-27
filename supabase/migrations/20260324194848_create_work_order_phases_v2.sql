
CREATE TABLE work_order_phases (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id    UUID NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
  phase_number     INT  NOT NULL,
  title            TEXT NOT NULL,
  description      TEXT,
  is_completed     BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at     TIMESTAMPTZ,
  completed_by_id  UUID REFERENCES staff_members(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (work_order_id, phase_number)
);

ALTER TABLE work_order_phases ENABLE ROW LEVEL SECURITY;

-- Allow maintenance personnel to read phases for their own WOs
CREATE POLICY "Maintenance can view own WO phases"
  ON work_order_phases FOR SELECT
  USING (
    work_order_id IN (
      SELECT id FROM work_orders WHERE assigned_to_id = auth.uid()
    )
  );

-- Allow maintenance personnel to update (mark complete) phases for their own WOs
CREATE POLICY "Maintenance can update own WO phases"
  ON work_order_phases FOR UPDATE
  USING (
    work_order_id IN (
      SELECT id FROM work_orders WHERE assigned_to_id = auth.uid()
    )
  );

-- Fleet managers can manage all phases
CREATE POLICY "Fleet managers can manage all WO phases"
  ON work_order_phases FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM staff_members
      WHERE id = auth.uid()
      AND role = 'fleetManager'
    )
  );
;

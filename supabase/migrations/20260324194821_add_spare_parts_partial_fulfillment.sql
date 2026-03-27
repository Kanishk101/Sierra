
ALTER TABLE spare_parts_requests
  ADD COLUMN quantity_available  INT NOT NULL DEFAULT 0,
  ADD COLUMN quantity_allocated  INT NOT NULL DEFAULT 0,
  ADD COLUMN quantity_on_order   INT NOT NULL DEFAULT 0,
  ADD COLUMN admin_ordered_at    TIMESTAMPTZ,
  ADD COLUMN expected_arrival_at TIMESTAMPTZ,
  ADD COLUMN order_reference     TEXT;
;


CREATE TYPE work_order_type AS ENUM ('repair', 'service');

ALTER TABLE work_orders
  ADD COLUMN work_order_type work_order_type NOT NULL DEFAULT 'repair';
;

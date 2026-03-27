
CREATE TYPE parts_sub_status AS ENUM (
  'none',
  'requested',
  'partially_ready',
  'approved',
  'order_placed',
  'ready'
);

ALTER TABLE work_orders
  ADD COLUMN parts_sub_status parts_sub_status NOT NULL DEFAULT 'none';
;

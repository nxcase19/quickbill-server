-- Ensure purchase_orders.status supports lifecycle values used by app.
ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'draft';

ALTER TABLE purchase_orders
  ALTER COLUMN status TYPE VARCHAR(50);

ALTER TABLE purchase_orders
  ALTER COLUMN status SET DEFAULT 'draft';

ALTER TABLE purchase_orders
  DROP CONSTRAINT IF EXISTS purchase_orders_status_check;

ALTER TABLE purchase_orders
  ADD CONSTRAINT purchase_orders_status_check
  CHECK (status IN ('draft', 'approved', 'received', 'cancelled', 'paid'));

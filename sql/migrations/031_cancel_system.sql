-- Sales order cancellation (batch by order_id) + document/PO cancel metadata.
-- `documents.status` may already exist (payment/draft); use sales_order_status for lifecycle.

CREATE TABLE IF NOT EXISTS orders (
  account_id UUID NOT NULL,
  order_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  cancelled_at TIMESTAMPTZ NULL,
  cancel_reason TEXT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (account_id, order_id)
);

CREATE INDEX IF NOT EXISTS idx_orders_account_status ON orders (account_id, status);

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ NULL;

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT NULL;

-- Lifecycle for sales batch (active | cancelled); separate from payment columns.
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS sales_order_status TEXT DEFAULT 'active';

ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ NULL;

ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT NULL;

-- Normalize PO status only when empty (do not overwrite valid statuses)
UPDATE purchase_orders
SET status = 'draft'
WHERE status IS NULL OR TRIM(BOTH FROM COALESCE(status::text, '')) = '';

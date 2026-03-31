-- Harden cancel v2: valid sales_order_status values + helpful indexes.

UPDATE documents
SET sales_order_status = 'active'
WHERE sales_order_status IS NULL;

ALTER TABLE documents
  ALTER COLUMN sales_order_status SET DEFAULT 'active';

ALTER TABLE documents
  DROP CONSTRAINT IF EXISTS documents_sales_order_status_check;

ALTER TABLE documents
  ADD CONSTRAINT documents_sales_order_status_check
  CHECK (sales_order_status IN ('active', 'cancelled'));

CREATE INDEX IF NOT EXISTS idx_documents_account_order
  ON documents (account_id, order_id);

CREATE INDEX IF NOT EXISTS idx_documents_sales_order_status
  ON documents (account_id, sales_order_status);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_status
  ON purchase_orders (account_id, status);

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE purchase_orders
ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE documents
SET is_locked = TRUE
WHERE LOWER(COALESCE(status, '')) IN ('paid', 'cancelled');

UPDATE documents
SET is_locked = FALSE
WHERE LOWER(COALESCE(status, '')) NOT IN ('paid', 'cancelled');

UPDATE purchase_orders
SET is_locked = TRUE
WHERE LOWER(COALESCE(status, '')) IN ('paid', 'cancelled');

UPDATE purchase_orders
SET is_locked = FALSE
WHERE LOWER(COALESCE(status, '')) IN ('draft', 'approved', 'received')
   OR LOWER(COALESCE(status, '')) NOT IN ('paid', 'cancelled');

UPDATE documents
SET is_locked = FALSE
WHERE is_locked IS NULL;

UPDATE purchase_orders
SET is_locked = FALSE
WHERE is_locked IS NULL;

ALTER TABLE documents
ALTER COLUMN is_locked SET NOT NULL;

ALTER TABLE purchase_orders
ALTER COLUMN is_locked SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_documents_account_locked
ON documents(account_id, is_locked);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_account_locked
ON purchase_orders(account_id, is_locked);

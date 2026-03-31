-- Reconcile lock-state drift for environments that already ran migration 033.
-- Runtime rule:
--   documents locked only when status in ('paid', 'cancelled')
--   purchase_orders locked only when status in ('paid', 'cancelled')

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE purchase_orders
ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE documents
SET is_locked = CASE
  WHEN LOWER(COALESCE(status, '')) IN ('paid', 'cancelled') THEN TRUE
  ELSE FALSE
END;

UPDATE purchase_orders
SET is_locked = CASE
  WHEN LOWER(COALESCE(status, '')) IN ('paid', 'cancelled') THEN TRUE
  ELSE FALSE
END;

CREATE INDEX IF NOT EXISTS idx_documents_account_locked
ON documents(account_id, is_locked);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_account_locked
ON purchase_orders(account_id, is_locked);

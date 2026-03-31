ALTER TABLE suppliers
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL;

CREATE INDEX IF NOT EXISTS idx_suppliers_account_deleted
ON suppliers(account_id, deleted_at);

ALTER TABLE customers
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

ALTER TABLE suppliers
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_customers_account_deleted
ON customers(account_id, deleted_at);

CREATE INDEX IF NOT EXISTS idx_suppliers_account_deleted
ON suppliers(account_id, deleted_at);

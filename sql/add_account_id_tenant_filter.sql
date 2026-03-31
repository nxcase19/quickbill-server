-- Optional: add account_id for multi-tenant filtering (additive only).
-- Run if columns are missing.

ALTER TABLE customers
ADD COLUMN IF NOT EXISTS account_id BIGINT REFERENCES accounts (id);

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS account_id BIGINT REFERENCES accounts (id);

ALTER TABLE payments
ADD COLUMN IF NOT EXISTS account_id BIGINT REFERENCES accounts (id);

ALTER TABLE products
ADD COLUMN IF NOT EXISTS account_id BIGINT REFERENCES accounts (id);

CREATE INDEX IF NOT EXISTS idx_customers_account_id ON customers (account_id);
CREATE INDEX IF NOT EXISTS idx_documents_account_id ON documents (account_id);
CREATE INDEX IF NOT EXISTS idx_payments_account_id ON payments (account_id);
CREATE INDEX IF NOT EXISTS idx_products_account_id ON products (account_id);

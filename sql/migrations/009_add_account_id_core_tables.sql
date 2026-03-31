-- Add missing account_id columns for partial multi-tenant migration.
-- Safe to re-run.

ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS account_id UUID;

ALTER TABLE purchase_order_items
  ADD COLUMN IF NOT EXISTS account_id UUID;

ALTER TABLE purchase_invoices
  ADD COLUMN IF NOT EXISTS account_id UUID;

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS account_id UUID;

ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS account_id UUID;

-- Helpful tenant indexes
CREATE INDEX IF NOT EXISTS idx_purchase_orders_account_id
  ON purchase_orders (account_id);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_account_id
  ON purchase_order_items (account_id);

CREATE INDEX IF NOT EXISTS idx_purchase_invoices_account_id
  ON purchase_invoices (account_id);

CREATE INDEX IF NOT EXISTS idx_documents_account_id
  ON documents (account_id);

CREATE INDEX IF NOT EXISTS idx_customers_account_id
  ON customers (account_id);

-- Backfill NULL account_id values using one default tenant ID.
-- IMPORTANT: replace the UUID in v_default_account_id before running in production.
DO $$
DECLARE
  v_default_account_id UUID := '00000000-0000-0000-0000-000000000000'::uuid;
BEGIN
  UPDATE purchase_orders
  SET account_id = v_default_account_id
  WHERE account_id IS NULL;

  UPDATE purchase_order_items
  SET account_id = v_default_account_id
  WHERE account_id IS NULL;

  UPDATE purchase_invoices
  SET account_id = v_default_account_id
  WHERE account_id IS NULL;

  UPDATE documents
  SET account_id = v_default_account_id
  WHERE account_id IS NULL;

  UPDATE customers
  SET account_id = v_default_account_id
  WHERE account_id IS NULL;
END $$;

-- Idempotent: aligns purchase_orders with documents-style company snapshot columns.
ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS company_name TEXT,
  ADD COLUMN IF NOT EXISTS company_address TEXT,
  ADD COLUMN IF NOT EXISTS company_tax_id TEXT,
  ADD COLUMN IF NOT EXISTS company_logo_url TEXT;

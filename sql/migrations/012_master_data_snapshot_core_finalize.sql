-- Finalize master-data + snapshot core fields.

-- Ensure customers/suppliers have updated_at.
ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE suppliers
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Ensure sales documents have customer_id snapshot reference (nullable).
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS customer_id UUID;

-- Ensure PO snapshot reference exists (nullable).
ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS supplier_id UUID;

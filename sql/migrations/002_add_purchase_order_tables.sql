-- Purchase (input VAT) invoices + purchase orders and line items
CREATE TABLE IF NOT EXISTS purchase_invoices (
  id SERIAL PRIMARY KEY,
  account_id UUID NOT NULL,
  supplier_name TEXT NOT NULL,
  tax_id TEXT,
  doc_no TEXT,
  doc_date DATE,
  subtotal NUMERIC(18, 2) DEFAULT 0,
  vat_amount NUMERIC(18, 2) DEFAULT 0,
  total NUMERIC(18, 2) DEFAULT 0,
  note TEXT,
  image_url TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE purchase_invoices
  ADD COLUMN IF NOT EXISTS source TEXT,
  ADD COLUMN IF NOT EXISTS source_id UUID;

CREATE INDEX IF NOT EXISTS idx_purchase_invoices_source ON purchase_invoices (account_id, source, source_id)
  WHERE source IS NOT NULL;

CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL,
  supplier_name TEXT NOT NULL,
  tax_id TEXT,
  doc_no TEXT,
  doc_date DATE,
  subtotal NUMERIC(18, 2) DEFAULT 0,
  vat_amount NUMERIC(18, 2) DEFAULT 0,
  total NUMERIC(18, 2) DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'approved', 'received', 'paid')),
  note TEXT,
  purchase_invoice_id INTEGER REFERENCES purchase_invoices (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_account ON purchase_orders (account_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders (account_id, status);

CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders (id) ON DELETE CASCADE,
  description TEXT NOT NULL DEFAULT '',
  quantity NUMERIC(18, 4) NOT NULL DEFAULT 1,
  unit_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  amount NUMERIC(18, 2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po ON purchase_order_items (purchase_order_id);

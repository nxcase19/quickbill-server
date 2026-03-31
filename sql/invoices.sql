-- Sales invoices (INV-YYYYMM-xxx), line items; tenant-scoped by account_id.
-- Run on Supabase / PostgreSQL after review.

CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL,
  customer_name TEXT NOT NULL,
  tax_id TEXT,
  doc_no TEXT,
  doc_date DATE,
  subtotal NUMERIC(18, 2) DEFAULT 0,
  vat_amount NUMERIC(18, 2) DEFAULT 0,
  total NUMERIC(18, 2) DEFAULT 0,
  vat_type TEXT NOT NULL DEFAULT 'none'
    CHECK (vat_type IN ('vat7', 'none')),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'issued', 'paid')),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoices_account ON invoices (account_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices (account_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_doc_no_account ON invoices (account_id, doc_no);

CREATE TABLE IF NOT EXISTS invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices (id) ON DELETE CASCADE,
  description TEXT NOT NULL DEFAULT '',
  quantity NUMERIC(18, 4) NOT NULL DEFAULT 1,
  unit_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  amount NUMERIC(18, 2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items (invoice_id);

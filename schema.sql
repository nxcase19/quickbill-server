-- Supabase PostgreSQL migrations for multi document type support

-- 1) documents: add backward-compatible VAT/doc_type columns
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS doc_type VARCHAR(10) NOT NULL DEFAULT 'INV',
  ADD COLUMN IF NOT EXISTS vat_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS vat_rate NUMERIC NOT NULL DEFAULT 0;

-- 2) running_numbers: sequence per (company_id, doc_type)
CREATE TABLE IF NOT EXISTS running_numbers (
  company_id BIGINT NOT NULL,
  doc_type VARCHAR(10) NOT NULL,
  next_no BIGINT NOT NULL DEFAULT 1,
  PRIMARY KEY (company_id, doc_type)
);

-- Optional seed for dev: ensure INV and RC rows exist for company_id=1
INSERT INTO running_numbers (company_id, doc_type, next_no)
VALUES (1, 'INV', 1)
ON CONFLICT (company_id, doc_type) DO NOTHING;

INSERT INTO running_numbers (company_id, doc_type, next_no)
VALUES (1, 'RC', 1)
ON CONFLICT (company_id, doc_type) DO NOTHING;

-- 3b) documents: optional note (shown on PDF)
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS note TEXT NOT NULL DEFAULT '';

-- 3) company_settings: per-tenant company info (UI + PDF header)
CREATE TABLE IF NOT EXISTS company_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL UNIQUE,
  name TEXT,
  company_name TEXT,
  company_name_th TEXT,
  company_name_en TEXT,
  address TEXT,
  tax_id TEXT,
  phone TEXT,
  logo_url TEXT,
  image_url TEXT,
  signature_url TEXT,
  auto_signature_enabled BOOLEAN DEFAULT true,
  language TEXT DEFAULT 'th',
  date_format TEXT DEFAULT 'thai',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_company_settings_account_id ON company_settings (account_id);

-- 4) purchase_invoices: VAT purchase tracking
CREATE TABLE IF NOT EXISTS purchase_invoices (
  id SERIAL PRIMARY KEY,
  account_id UUID NOT NULL,
  supplier_name TEXT NOT NULL,
  tax_id TEXT,
  doc_no TEXT,
  doc_date DATE,
  subtotal NUMERIC DEFAULT 0,
  vat_amount NUMERIC DEFAULT 0,
  total NUMERIC DEFAULT 0,
  note TEXT,
  image_url TEXT,
  source TEXT,
  source_id UUID,
  source_type TEXT NOT NULL DEFAULT 'manual',
  status TEXT NOT NULL DEFAULT 'active',
  document_status TEXT NOT NULL DEFAULT 'issued',
  deleted_at TIMESTAMPTZ,
  cancelled_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Purchase orders (see sql/purchase_orders.sql for full migration)
-- purchase_orders, purchase_order_items; pay() creates purchase_invoices with source='PO'

-- Sales invoices (see sql/invoices.sql): invoices, invoice_items; doc_no INV-YYYYMM-xxx

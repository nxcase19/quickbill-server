-- QuickBill SaaS v1 canonical schema (PostgreSQL / Supabase)
-- Multi-tenant by company_id with UUID primary keys for business entities.
-- This file is intended as the canonical target schema for fresh environments.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Shared helper: updated_at trigger
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 1) accounts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  password_hash TEXT,
  auth_provider TEXT NOT NULL DEFAULT 'email',
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'deleted')),
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TRIGGER trg_accounts_updated_at
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 2) companies
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_account_id UUID REFERENCES accounts (id) ON DELETE SET NULL,
  company_code TEXT UNIQUE,
  name TEXT NOT NULL,
  legal_name TEXT,
  tax_id TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_companies_owner_account_id ON companies (owner_account_id);
CREATE INDEX IF NOT EXISTS idx_companies_status ON companies (status);

CREATE TRIGGER trg_companies_updated_at
BEFORE UPDATE ON companies
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 3) company_members
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS company_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member'
    CHECK (role IN ('owner', 'admin', 'accountant', 'viewer', 'member')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'invited', 'disabled')),
  invited_by_account_id UUID REFERENCES accounts (id) ON DELETE SET NULL,
  invited_at TIMESTAMPTZ,
  joined_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, account_id)
);

CREATE INDEX IF NOT EXISTS idx_company_members_company_id ON company_members (company_id);
CREATE INDEX IF NOT EXISTS idx_company_members_company_status ON company_members (company_id, status);
CREATE INDEX IF NOT EXISTS idx_company_members_account_id ON company_members (account_id);

CREATE TRIGGER trg_company_members_updated_at
BEFORE UPDATE ON company_members
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 4) company_settings
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS company_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL UNIQUE REFERENCES companies (id) ON DELETE CASCADE,
  company_name_th TEXT,
  company_name_en TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  tax_id TEXT,
  logo_url TEXT,
  image_url TEXT,
  signature_url TEXT,
  auto_signature_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  language VARCHAR(10) NOT NULL DEFAULT 'th',
  date_format VARCHAR(20) NOT NULL DEFAULT 'thai',
  currency_code VARCHAR(10) NOT NULL DEFAULT 'THB',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_company_settings_company_id ON company_settings (company_id);

CREATE TRIGGER trg_company_settings_updated_at
BEFORE UPDATE ON company_settings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 5) customers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  customer_code TEXT,
  name TEXT NOT NULL,
  tax_id TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive')),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_customers_company_customer_code
  ON customers (company_id, customer_code)
  WHERE customer_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_customers_company_id ON customers (company_id);
CREATE INDEX IF NOT EXISTS idx_customers_company_status ON customers (company_id, status);

CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 6) suppliers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  supplier_code TEXT,
  name TEXT NOT NULL,
  tax_id TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive')),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_suppliers_company_supplier_code
  ON suppliers (company_id, supplier_code)
  WHERE supplier_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_suppliers_company_id ON suppliers (company_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_company_status ON suppliers (company_id, status);

CREATE TRIGGER trg_suppliers_updated_at
BEFORE UPDATE ON suppliers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 7) products
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  sku TEXT,
  name TEXT NOT NULL,
  description TEXT,
  unit TEXT DEFAULT 'unit',
  unit_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  vat_rate NUMERIC(6, 3) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_products_company_sku
  ON products (company_id, sku)
  WHERE sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_company_id ON products (company_id);
CREATE INDEX IF NOT EXISTS idx_products_company_status ON products (company_id, status);

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 8) documents (sales side: quotation / delivery_note / invoice / receipt)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers (id) ON DELETE SET NULL,
  doc_type TEXT NOT NULL
    CHECK (doc_type IN ('quotation', 'delivery_note', 'invoice', 'receipt')),
  doc_no TEXT NOT NULL,
  doc_date DATE NOT NULL,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'issued', 'approved', 'paid', 'cancelled')),
  document_status TEXT NOT NULL DEFAULT 'issued'
    CHECK (document_status IN ('draft', 'issued', 'cancelled')),
  subtotal NUMERIC(18, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  vat_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  vat_rate NUMERIC(6, 3) NOT NULL DEFAULT 0,
  vat_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total NUMERIC(18, 2) NOT NULL DEFAULT 0,
  paid_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  note TEXT,
  internal_note TEXT,
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_by UUID REFERENCES accounts (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, doc_type, doc_no)
);

CREATE INDEX IF NOT EXISTS idx_documents_company_id ON documents (company_id);
CREATE INDEX IF NOT EXISTS idx_documents_company_status ON documents (company_id, status);
CREATE INDEX IF NOT EXISTS idx_documents_company_doc_date ON documents (company_id, doc_date);

CREATE TRIGGER trg_documents_updated_at
BEFORE UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 9) document_items
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS document_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES documents (id) ON DELETE CASCADE,
  product_id UUID REFERENCES products (id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  quantity NUMERIC(18, 4) NOT NULL DEFAULT 1,
  unit_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  vat_rate NUMERIC(6, 3) NOT NULL DEFAULT 0,
  amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_document_items_company_id ON document_items (company_id);
CREATE INDEX IF NOT EXISTS idx_document_items_document_id ON document_items (document_id);

CREATE TRIGGER trg_document_items_updated_at
BEFORE UPDATE ON document_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 10) purchase_orders
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  supplier_id UUID REFERENCES suppliers (id) ON DELETE SET NULL,
  doc_no TEXT NOT NULL,
  doc_date DATE NOT NULL,
  expected_date DATE,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'issued', 'approved', 'paid', 'cancelled')),
  subtotal NUMERIC(18, 2) NOT NULL DEFAULT 0,
  vat_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total NUMERIC(18, 2) NOT NULL DEFAULT 0,
  note TEXT,
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_by UUID REFERENCES accounts (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, doc_no)
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_company_id ON purchase_orders (company_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_company_status ON purchase_orders (company_id, status);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_company_doc_date ON purchase_orders (company_id, doc_date);

CREATE TRIGGER trg_purchase_orders_updated_at
BEFORE UPDATE ON purchase_orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 11) purchase_order_items
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders (id) ON DELETE CASCADE,
  product_id UUID REFERENCES products (id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  quantity NUMERIC(18, 4) NOT NULL DEFAULT 1,
  unit_price NUMERIC(18, 2) NOT NULL DEFAULT 0,
  vat_rate NUMERIC(6, 3) NOT NULL DEFAULT 0,
  amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_company_id ON purchase_order_items (company_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_purchase_order_id ON purchase_order_items (purchase_order_id);

CREATE TRIGGER trg_purchase_order_items_updated_at
BEFORE UPDATE ON purchase_order_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 12) purchase_invoices (purchase flow remains separate from sales documents)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS purchase_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  supplier_id UUID REFERENCES suppliers (id) ON DELETE SET NULL,
  purchase_order_id UUID REFERENCES purchase_orders (id) ON DELETE SET NULL,
  doc_no TEXT,
  doc_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'paid', 'cancelled')),
  document_status TEXT NOT NULL DEFAULT 'issued'
    CHECK (document_status IN ('draft', 'issued', 'cancelled')),
  source TEXT,
  source_type TEXT NOT NULL DEFAULT 'manual'
    CHECK (source_type IN ('manual', 'po', 'import')),
  source_id UUID,
  subtotal NUMERIC(18, 2) NOT NULL DEFAULT 0,
  vat_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  total NUMERIC(18, 2) NOT NULL DEFAULT 0,
  note TEXT,
  image_url TEXT,
  paid_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_by UUID REFERENCES accounts (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_invoices_company_id ON purchase_invoices (company_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_company_status ON purchase_invoices (company_id, status);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_company_doc_date ON purchase_invoices (company_id, doc_date);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_purchase_order_id ON purchase_invoices (purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_source ON purchase_invoices (company_id, source_type, source_id);

CREATE TRIGGER trg_purchase_invoices_updated_at
BEFORE UPDATE ON purchase_invoices
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 13) payments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  payment_type TEXT NOT NULL
    CHECK (payment_type IN ('sales_receipt', 'purchase_payment', 'adjustment')),
  document_id UUID REFERENCES documents (id) ON DELETE SET NULL,
  purchase_invoice_id UUID REFERENCES purchase_invoices (id) ON DELETE SET NULL,
  payment_date DATE NOT NULL,
  amount NUMERIC(18, 2) NOT NULL CHECK (amount >= 0),
  method TEXT,
  reference_no TEXT,
  status TEXT NOT NULL DEFAULT 'posted'
    CHECK (status IN ('draft', 'posted', 'void')),
  note TEXT,
  created_by UUID REFERENCES accounts (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cancelled_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_payments_company_id ON payments (company_id);
CREATE INDEX IF NOT EXISTS idx_payments_company_status ON payments (company_id, status);
CREATE INDEX IF NOT EXISTS idx_payments_company_payment_date ON payments (company_id, payment_date);
CREATE INDEX IF NOT EXISTS idx_payments_document_id ON payments (document_id);
CREATE INDEX IF NOT EXISTS idx_payments_purchase_invoice_id ON payments (purchase_invoice_id);

CREATE TRIGGER trg_payments_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 14) shared_documents
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shared_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES documents (id) ON DELETE CASCADE,
  share_token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'revoked', 'expired')),
  allow_download BOOLEAN NOT NULL DEFAULT TRUE,
  view_count INTEGER NOT NULL DEFAULT 0,
  last_viewed_at TIMESTAMPTZ,
  created_by UUID REFERENCES accounts (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_shared_documents_company_id ON shared_documents (company_id);
CREATE INDEX IF NOT EXISTS idx_shared_documents_company_status ON shared_documents (company_id, status);
CREATE INDEX IF NOT EXISTS idx_shared_documents_document_id ON shared_documents (document_id);

CREATE TRIGGER trg_shared_documents_updated_at
BEFORE UPDATE ON shared_documents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 15) audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  actor_account_id UUID REFERENCES accounts (id) ON DELETE SET NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  action TEXT NOT NULL,
  old_value JSONB,
  new_value JSONB,
  ip_address INET,
  user_agent TEXT,
  request_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_company_id ON audit_logs (company_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs (company_id, entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs (company_id, actor_account_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (company_id, created_at DESC);

CREATE TRIGGER trg_audit_logs_updated_at
BEFORE UPDATE ON audit_logs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 16) document_counters
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS document_counters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies (id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL
    CHECK (doc_type IN ('quotation', 'delivery_note', 'invoice', 'receipt')),
  period_key TEXT NOT NULL, -- e.g. 2026-03
  next_no BIGINT NOT NULL DEFAULT 1 CHECK (next_no >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, doc_type, period_key)
);

CREATE INDEX IF NOT EXISTS idx_document_counters_company_id ON document_counters (company_id);
CREATE INDEX IF NOT EXISTS idx_document_counters_company_doc_type ON document_counters (company_id, doc_type);

CREATE TRIGGER trg_document_counters_updated_at
BEFORE UPDATE ON document_counters
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

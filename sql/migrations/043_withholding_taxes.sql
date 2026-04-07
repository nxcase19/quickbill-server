-- Sales invoice withholding tax (WHT). Tenant = account_id (matches invoices).
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS wht_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_amount NUMERIC(18, 2);

UPDATE invoices
SET net_amount = COALESCE(total, 0)
WHERE net_amount IS NULL;

CREATE TABLE IF NOT EXISTS withholding_taxes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL,
  invoice_id UUID NOT NULL UNIQUE REFERENCES invoices (id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  rate NUMERIC(5, 2) NOT NULL,
  base_amount NUMERIC(12, 2) NOT NULL,
  wht_amount NUMERIC(12, 2) NOT NULL,
  certificate_no TEXT,
  issued_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withholding_taxes_account_id
  ON withholding_taxes (account_id);

CREATE INDEX IF NOT EXISTS idx_withholding_taxes_invoice_id
  ON withholding_taxes (invoice_id);

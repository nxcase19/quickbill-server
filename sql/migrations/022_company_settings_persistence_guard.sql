CREATE TABLE IF NOT EXISTS company_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL UNIQUE,
  company_name TEXT,
  company_name_en TEXT,
  address TEXT,
  tax_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS company_name TEXT;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS company_name_en TEXT;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS address TEXT;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS tax_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_company_settings_account_id_unique
ON company_settings(account_id);

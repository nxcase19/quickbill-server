-- Per-account company info (run once in Supabase / psql)
-- Requires: gen_random_uuid() (pgcrypto, enabled by default on Supabase)

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

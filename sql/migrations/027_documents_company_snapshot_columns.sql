-- Idempotent: safe to re-run. Ensures sales document company snapshot columns exist.
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS company_name TEXT,
  ADD COLUMN IF NOT EXISTS company_address TEXT,
  ADD COLUMN IF NOT EXISTS company_tax_id TEXT,
  ADD COLUMN IF NOT EXISTS company_logo_url TEXT;

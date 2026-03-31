-- Production-safe multi-tenant: one company per account, canonical company_name, snapshot phone on docs/PO.

-- 1) Ensure company_settings columns exist
ALTER TABLE company_settings
  ADD COLUMN IF NOT EXISTS company_name TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS tax_id TEXT,
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS signature_url TEXT;

-- 2) UNIQUE(account_id): already enforced by 001_create_company_settings (column UNIQUE).
--    Do not add a second unique object here (would fail if one exists).

-- 3) Backfill company_name from legacy fields when empty (migration-time only)
UPDATE company_settings
SET company_name = COALESCE(
  NULLIF(TRIM(company_name), ''),
  NULLIF(TRIM(name_th), ''),
  NULLIF(TRIM(name), ''),
  NULLIF(TRIM(company_name_th), ''),
  NULLIF(TRIM(company_name_en), '')
)
WHERE company_name IS NULL OR TRIM(BOTH FROM COALESCE(company_name, '')) = '';

-- 4) Phone: leave existing values; optional trim-only normalization not required here

-- 5) Snapshot: company_phone on sales documents
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS company_phone TEXT;

-- 6) Snapshot: company_phone on purchase orders
ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS company_phone TEXT;

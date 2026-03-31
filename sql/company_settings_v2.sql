-- Upgrade company_settings to v2 (company_name, language, date_format, timestamps).
-- Run after review on Supabase / PostgreSQL.

ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS company_name TEXT;
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS company_name_en TEXT;
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS language TEXT DEFAULT 'th';
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS date_format TEXT DEFAULT 'thai';
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

UPDATE company_settings
SET company_name = name
WHERE company_name IS NULL AND name IS NOT NULL;

UPDATE company_settings
SET created_at = COALESCE(created_at, updated_at, NOW())
WHERE created_at IS NULL;

ALTER TABLE company_settings ALTER COLUMN language SET DEFAULT 'th';
ALTER TABLE company_settings ALTER COLUMN date_format SET DEFAULT 'thai';

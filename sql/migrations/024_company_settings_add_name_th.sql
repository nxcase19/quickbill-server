ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS name_th TEXT;

UPDATE company_settings
SET name_th = COALESCE(NULLIF(TRIM(company_name_th), ''), NULLIF(TRIM(company_name), ''), NULLIF(TRIM(name), ''))
WHERE name_th IS NULL OR TRIM(name_th) = '';

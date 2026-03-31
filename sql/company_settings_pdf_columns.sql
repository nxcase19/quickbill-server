-- PDF / UI: Thai display name + logo URL (run on existing DBs missing columns)
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS company_name_th TEXT;
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS signature_url TEXT;
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS auto_signature_enabled BOOLEAN DEFAULT true;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS signature_url TEXT;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS auto_signature_enabled BOOLEAN DEFAULT true;

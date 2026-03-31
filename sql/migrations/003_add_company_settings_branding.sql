ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS company_name_th TEXT;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS company_name_en TEXT;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS image_url TEXT;

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'th';

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS date_format VARCHAR(20) DEFAULT 'thai';

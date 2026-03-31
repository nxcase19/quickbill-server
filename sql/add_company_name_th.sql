-- Run once if PDF / UI fails on missing Thai company name column
ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS company_name_th TEXT;

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS company_name TEXT;

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS company_address TEXT;

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS company_tax_id TEXT;

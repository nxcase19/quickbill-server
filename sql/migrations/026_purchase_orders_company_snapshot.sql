ALTER TABLE purchase_orders
ADD COLUMN IF NOT EXISTS company_name TEXT;

ALTER TABLE purchase_orders
ADD COLUMN IF NOT EXISTS company_address TEXT;

ALTER TABLE purchase_orders
ADD COLUMN IF NOT EXISTS company_tax_id TEXT;

ALTER TABLE purchase_orders
ADD COLUMN IF NOT EXISTS company_logo_url TEXT;

ALTER TABLE purchase_invoices
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'active';

ALTER TABLE purchase_invoices
ADD COLUMN IF NOT EXISTS document_status VARCHAR(50) DEFAULT 'issued';

ALTER TABLE purchase_invoices
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL;

ALTER TABLE purchase_invoices
ADD COLUMN IF NOT EXISTS source_type VARCHAR(50) DEFAULT 'manual';

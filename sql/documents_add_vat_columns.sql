-- Run in Supabase SQL Editor (or: psql $DATABASE_URL -f sql/documents_add_vat_columns.sql)
-- Adds VAT columns (and optional subtotal) if missing — idempotent.

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS vat_enabled BOOLEAN DEFAULT false;

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS vat_rate NUMERIC DEFAULT 0;

-- Recommended: ensure subtotal exists for line totals / VAT base
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS subtotal NUMERIC DEFAULT 0;

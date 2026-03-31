-- Links multiple documents created in one POST batch (same order_id).
-- Run in Supabase SQL Editor if column is missing.

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS order_id TEXT;

CREATE INDEX IF NOT EXISTS idx_documents_order_id ON documents (order_id);

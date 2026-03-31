ALTER TABLE documents
ADD COLUMN IF NOT EXISTS order_id TEXT;

-- optional (ช่วย query เร็ว)
CREATE INDEX IF NOT EXISTS idx_documents_order_id
ON documents(order_id);

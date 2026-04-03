-- Billing / free-tier: one group_id per POST batch (QT+DN+INV+RC share same UUID).
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS group_id UUID;

CREATE INDEX IF NOT EXISTS idx_documents_account_group_created
  ON documents (account_id, group_id, created_at);

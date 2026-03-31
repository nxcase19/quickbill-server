-- Safe cancel / audit for purchase (input VAT) invoices
-- Run after purchase_invoices exists.

ALTER TABLE purchase_invoices
  ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP NULL;

UPDATE purchase_invoices
SET source_type = 'po'
WHERE source = 'PO';

CREATE INDEX IF NOT EXISTS idx_purchase_invoices_account_status
  ON purchase_invoices (account_id, status);

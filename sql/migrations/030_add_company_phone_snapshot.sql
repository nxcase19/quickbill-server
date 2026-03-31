-- Safe idempotent: company_phone snapshot on sales documents and purchase orders.

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS company_phone TEXT;

ALTER TABLE purchase_orders
  ADD COLUMN IF NOT EXISTS company_phone TEXT;

UPDATE documents d
SET company_phone = cs.phone
FROM company_settings cs
WHERE d.account_id = cs.account_id
  AND (d.company_phone IS NULL OR d.company_phone = '');

UPDATE purchase_orders p
SET company_phone = cs.phone
FROM company_settings cs
WHERE p.account_id = cs.account_id
  AND (p.company_phone IS NULL OR p.company_phone = '');

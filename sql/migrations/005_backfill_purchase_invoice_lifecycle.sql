UPDATE purchase_invoices
SET status = 'active'
WHERE status IS NULL;

UPDATE purchase_invoices
SET document_status = 'issued'
WHERE document_status IS NULL;

UPDATE purchase_invoices
SET source_type = CASE
  WHEN source = 'PO' THEN 'po'
  ELSE 'manual'
END
WHERE source_type IS NULL;

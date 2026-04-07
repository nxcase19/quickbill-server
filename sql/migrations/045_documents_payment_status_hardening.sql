-- payment_status = financial only ('paid' | 'unpaid'). Repair, default, CHECK.

UPDATE documents
SET payment_status = 'unpaid'
WHERE payment_status IS NULL
   OR TRIM(COALESCE(payment_status, '')) NOT IN ('paid', 'unpaid');

-- Legacy: rows paid before payment_status was source of truth (status was set to 'paid').
UPDATE documents
SET payment_status = 'paid'
WHERE LOWER(TRIM(COALESCE(status::text, ''))) = 'paid'
  AND payment_status = 'unpaid';

DO $$
BEGIN
  IF to_regclass('public.invoices') IS NOT NULL THEN
    UPDATE documents d
    SET payment_status = 'paid'
    FROM invoices i
    WHERE d.account_id = i.account_id
      AND i.doc_no IS NOT NULL
      AND TRIM(i.doc_no) <> ''
      AND d.doc_no = i.doc_no
      AND d.doc_type = 'INV'
      AND i.status = 'paid';
  END IF;
END $$;

ALTER TABLE documents
  ALTER COLUMN payment_status SET DEFAULT 'unpaid';

ALTER TABLE documents
  DROP CONSTRAINT IF EXISTS documents_payment_status_check;

ALTER TABLE documents
  DROP CONSTRAINT IF EXISTS payment_status_check;

ALTER TABLE documents
  ADD CONSTRAINT documents_payment_status_check
  CHECK (payment_status IN ('paid', 'unpaid'));

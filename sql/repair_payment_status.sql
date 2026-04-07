-- One-off / manual repair: run after backup if needed (also covered by migration 045).

UPDATE documents
SET payment_status = 'unpaid'
WHERE payment_status IS NULL;

UPDATE documents
SET payment_status = 'paid'
WHERE LOWER(TRIM(COALESCE(status::text, ''))) = 'paid'
  AND payment_status = 'unpaid';

-- Optional: sync paid from sales invoices (skip if `invoices` missing).
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

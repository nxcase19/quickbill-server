-- documents.payment_status follows invoices.status (invoices = source of truth).

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'unpaid';

CREATE OR REPLACE FUNCTION sync_documents_payment_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.doc_no IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE documents
  SET payment_status =
    CASE
      WHEN NEW.status = 'paid' THEN 'paid'
      ELSE 'unpaid'
    END
  WHERE account_id = NEW.account_id
    AND order_id IN (
      SELECT order_id
      FROM documents
      WHERE account_id = NEW.account_id
        AND doc_no = NEW.doc_no
    );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_payment ON invoices;

CREATE TRIGGER trg_sync_payment
AFTER UPDATE OF status ON invoices
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION sync_documents_payment_status();

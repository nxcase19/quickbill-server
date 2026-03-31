DO $$
BEGIN
  IF to_regclass('public.invoices') IS NOT NULL THEN
    ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS invoices_status_check;

    ALTER TABLE invoices
    ADD CONSTRAINT invoices_status_check
    CHECK (status IN ('draft', 'issued', 'paid', 'cancelled'));
  END IF;
END $$;

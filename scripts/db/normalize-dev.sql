-- =============================================================================
-- QuickBill — normalize dev DB after restore from production
-- Run against DEV only (npm run db:normalize:dev or db:sync:dev).
-- =============================================================================

DO $$
BEGIN
  IF to_regclass('public.documents') IS NULL THEN
    RAISE NOTICE 'Table documents not found; skipping payment normalization.';
    RETURN;
  END IF;

  -- paid_amount drives dev truth after restore; everything else unpaid
  UPDATE documents
  SET payment_status = CASE
    WHEN COALESCE(paid_amount, 0) > 0 THEN 'paid'
    ELSE 'unpaid'
  END;

  UPDATE documents
  SET payment_status = 'unpaid'
  WHERE payment_status IS NULL;

  ALTER TABLE documents
    ALTER COLUMN payment_status SET DEFAULT 'unpaid';

  ALTER TABLE documents
    DROP CONSTRAINT IF EXISTS documents_payment_status_check;

  ALTER TABLE documents
    DROP CONSTRAINT IF EXISTS payment_status_check;

  ALTER TABLE documents
    ADD CONSTRAINT documents_payment_status_check
    CHECK (payment_status IN ('paid', 'unpaid'));
END $$;

-- =============================================================================
-- Optional (manual / future): dev-only hygiene — NOT executed above
-- =============================================================================
-- Outbound integrations: rotate or blank API keys for dev so workers never hit
--   production Stripe / email / SMS accounts.
--
-- Webhooks: use dev-only webhook URLs and secrets; never reuse production
--   signing secrets in .env.local.
--
-- PII: optionally mask phone/tax_id on customers/suppliers after restore if
--   your policy requires anonymized dev copies.
-- =============================================================================

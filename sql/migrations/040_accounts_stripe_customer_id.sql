-- Stripe customer id (cus_...) for webhook resolution when subscription metadata is missing.
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_accounts_stripe_customer_id
  ON accounts (stripe_customer_id)
  WHERE stripe_customer_id IS NOT NULL AND stripe_customer_id <> '';

COMMENT ON COLUMN accounts.stripe_customer_id IS 'Stripe customer id; set on checkout / subscription sync for invoice webhooks';

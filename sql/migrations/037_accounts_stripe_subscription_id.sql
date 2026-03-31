-- Stripe subscription id for cancel-at-period-end and support flows.
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS subscription_id TEXT;

COMMENT ON COLUMN accounts.subscription_id IS 'Stripe subscription id (sub_...); set on checkout.session.completed';

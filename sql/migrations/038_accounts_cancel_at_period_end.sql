-- Track user-initiated cancel (Stripe cancel_at_period_end); plan stays paid until period ends.
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN accounts.cancel_at_period_end IS 'User requested cancel; subscription remains active until subscription_ends_at';

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

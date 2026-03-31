-- Phase auth foundation: user audit fields + account created_at (additive only).
-- Safe to re-run. Does not drop or rewrite existing data.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'owner';

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN users.role IS 'owner | admin | ... (app-validated; default owner for SaaS single-user accounts)';
COMMENT ON COLUMN users.last_login_at IS 'Set on successful password login';

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN accounts.created_at IS 'When the tenant account row was created';

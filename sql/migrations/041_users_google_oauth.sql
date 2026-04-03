-- Google Sign-In: optional password for OAuth-only users, link by google sub.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS google_sub TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google_sub
  ON users (google_sub)
  WHERE google_sub IS NOT NULL AND google_sub <> '';

ALTER TABLE users
  ALTER COLUMN password_hash DROP NOT NULL;

COMMENT ON COLUMN users.google_sub IS 'Google OIDC subject (sub); unique when set';

-- User feedback (bugs / feature requests). account_id / user_id as TEXT for UUID or legacy numeric IDs.
CREATE TABLE IF NOT EXISTS feedbacks (
  id SERIAL PRIMARY KEY,
  account_id TEXT,
  user_id TEXT,
  type TEXT NOT NULL,
  message TEXT NOT NULL,
  page TEXT,
  status TEXT NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedbacks_account_id ON feedbacks (account_id);
CREATE INDEX IF NOT EXISTS idx_feedbacks_created_at ON feedbacks (created_at DESC);

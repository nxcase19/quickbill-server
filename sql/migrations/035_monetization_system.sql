-- Phase 1 monetization: plan columns, trial, usage counters (per-tenant account_id).
-- Safe to re-run.

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS plan_type TEXT NOT NULL DEFAULT 'free';

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS trial_started_at TIMESTAMPTZ;

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ;

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS subscription_ends_at TIMESTAMPTZ;

COMMENT ON COLUMN accounts.plan_type IS 'free | basic | pro | business (validated in app)';
COMMENT ON COLUMN accounts.trial_started_at IS 'When the 7-day trial began (null = no trial window)';
COMMENT ON COLUMN accounts.trial_ends_at IS 'Trial end instant; while now < this and trial_started_at set, features match pro';

-- Monthly bucket for documents_month (last_reset_date aligns daily counter to a calendar day).
CREATE TABLE IF NOT EXISTS usage_stats (
  account_id UUID NOT NULL PRIMARY KEY REFERENCES accounts (id) ON DELETE CASCADE,
  documents_today INTEGER NOT NULL DEFAULT 0,
  documents_month INTEGER NOT NULL DEFAULT 0,
  last_reset_date DATE,
  usage_month_key TEXT NOT NULL DEFAULT (TO_CHAR(CURRENT_DATE, 'YYYY-MM'))
);

COMMENT ON TABLE usage_stats IS 'Per-account document creation counters for free-plan limits; reset daily/monthly in app layer';
COMMENT ON COLUMN usage_stats.last_reset_date IS 'Calendar date for which documents_today is counted; rollover when date changes';
COMMENT ON COLUMN usage_stats.usage_month_key IS 'YYYY-MM for which documents_month applies';

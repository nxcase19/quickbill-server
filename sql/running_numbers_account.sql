-- Per-tenant running numbers keyed by account_id (UUID).
-- Safe additive migration: does not alter legacy running_numbers (company_id bigint).
-- Run once in Supabase SQL editor or: psql $DATABASE_URL -f sql/running_numbers_account.sql

CREATE TABLE IF NOT EXISTS running_numbers_account (
  account_id UUID NOT NULL,
  doc_type VARCHAR(10) NOT NULL,
  next_no BIGINT NOT NULL DEFAULT 1,
  PRIMARY KEY (account_id, doc_type)
);

CREATE INDEX IF NOT EXISTS idx_running_numbers_account_doc_type
  ON running_numbers_account (doc_type);

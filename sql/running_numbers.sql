-- Run in Supabase SQL editor or: psql $DATABASE_URL -f sql/running_numbers.sql

CREATE TABLE IF NOT EXISTS running_numbers (
  company_id BIGINT PRIMARY KEY,
  next_no BIGINT NOT NULL DEFAULT 1
);

INSERT INTO running_numbers (company_id, next_no)
VALUES (1, 1)
ON CONFLICT (company_id) DO NOTHING;

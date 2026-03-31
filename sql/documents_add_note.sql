-- Optional note on each document (Supabase SQL editor / psql)
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS note TEXT NOT NULL DEFAULT '';

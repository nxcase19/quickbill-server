# SQL migrations (QuickBill)

Versioned, ordered schema changes for PostgreSQL. Apply against production only after review in staging.

## Rules

1. **Run in numeric order** — filenames are prefixed with `000`, `001`, … so sort order is deterministic. Never skip or reorder when bootstrapping a new environment.
2. **Idempotent statements** — prefer `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, and `CREATE INDEX IF NOT EXISTS` so re-running a file does not fail.
3. **Backfills are separate** — add columns and defaults in one migration; put `UPDATE` / data fixes in a following file (e.g. `004` schema, `005` backfill) so rollbacks and reviews stay clear.
4. **Do not edit applied migrations** — once a file has run in production, treat it as immutable. Fix forward with a new numbered file.
5. **One change set per file** — for each new schema change, add the next number (e.g. `007_add_foo.sql`).

Numbered files after `006` (e.g. `007_add_purchase_invoice_cancelled_at.sql`) extend the chain; keep running new files in order.

## Optional tracking

Run `000_migration_table.sql` first if you want a `schema_migrations` table. Your runner should insert `filename` after each successful file (implementation is not included here).

## PostgreSQL note on defaults

When you `ADD COLUMN … DEFAULT 'manual'`, PostgreSQL may backfill existing rows immediately. A later `UPDATE … WHERE source_type IS NULL` may then match no rows. If you rely on backfill logic for `source_type` (e.g. from `source = 'PO'`), add a one-off corrective `UPDATE` in a new migration after verifying data, or adjust the sequence in a **new** migration file (do not rewrite old ones after production use).

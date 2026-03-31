-- Change order_id from UUID to TEXT (backend uses Date.now().toString() etc.).
-- USING preserves every row: UUID becomes its string form; TEXT stays as-is; NULL stays NULL.
-- Does not delete or truncate data.

ALTER TABLE documents
ALTER COLUMN order_id TYPE TEXT USING order_id::text;

-- Optional: store VAT regime on documents (PDF label); safe if already applied.
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS vat_type TEXT;

UPDATE documents
SET vat_type = 'vat7'
WHERE vat_type IS NULL
  AND vat_enabled IS TRUE
  AND vat_rate IS NOT NULL
  AND ABS(vat_rate - 0.07) < 0.0001;

UPDATE documents
SET vat_type = 'none'
WHERE vat_type IS NULL;

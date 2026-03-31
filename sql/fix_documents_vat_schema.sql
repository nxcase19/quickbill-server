-- =============================================================================
-- Fix documents table: VAT columns (Supabase SQL Editor or psql)
-- If errors persist, confirm DATABASE_URL in .env points to THIS project DB.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1 — ตรวจสอบคอลัมน์ปัจจุบัน (รันก่อน)
-- ถ้าไม่เห็น vat_enabled / vat_rate แปลว่ายังไม่ได้ migrate
-- -----------------------------------------------------------------------------
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'documents'
ORDER BY ordinal_position;

-- -----------------------------------------------------------------------------
-- STEP 2 — เพิ่มคอลัมน์ (ใช้ IF NOT EXISTS เพื่อรันซ้ำได้โดยไม่ error)
-- แบบไม่ใช้ IF NOT EXISTS (สำหรับ DB ที่ยังไม่มีคอลัมน์จริงๆ เท่านั้น):
--   ALTER TABLE documents ADD COLUMN vat_enabled BOOLEAN DEFAULT false;
--   ALTER TABLE documents ADD COLUMN vat_rate NUMERIC DEFAULT 0;
-- -----------------------------------------------------------------------------
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS vat_enabled BOOLEAN DEFAULT false;

ALTER TABLE documents
ADD COLUMN IF NOT EXISTS vat_rate NUMERIC DEFAULT 0;

-- แนะนำ: ฐานราคาก่อน VAT (ถ้ายังไม่มี)
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS subtotal NUMERIC DEFAULT 0;

-- -----------------------------------------------------------------------------
-- STEP 3 — ตรวจซ้ำ (ต้องเห็น vat_enabled, vat_rate)
-- -----------------------------------------------------------------------------
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'documents'
  AND column_name IN ('vat_enabled', 'vat_rate', 'subtotal')
ORDER BY column_name;

-- จากนั้น restart server: npm run dev

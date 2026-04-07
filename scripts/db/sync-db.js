import { execSync } from 'child_process';

const PROD_DB = process.env.PROD_DB_URL;
const TARGET_DB = process.env.TARGET_DB_URL;

if (!PROD_DB || !TARGET_DB) {
  console.error('Missing DB URL');
  process.exit(1);
}

console.log('🔄 Dump production...');
execSync(`pg_dump ${PROD_DB} > dump.sql`);

console.log('🧹 Reset target DB...');
execSync(`psql ${TARGET_DB} -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"`);

console.log('📥 Import to target...');
execSync(`psql ${TARGET_DB} < dump.sql`);

console.log('🧼 Normalize data...');

execSync(`
psql ${TARGET_DB} -c "
UPDATE documents
SET payment_status = CASE
  WHEN COALESCE(paid_amount, 0) >= total THEN 'paid'
  ELSE 'unpaid'
END;
"
`);

console.log('✅ Sync done');
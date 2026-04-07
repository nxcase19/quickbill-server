import fs from 'fs'
import path from 'path'
import { execSync } from 'child_process'
import pg from 'pg'

const { Client } = pg

// ✅ ENV ใหม่
const TARGET_ENV = process.env.TARGET_ENV || 'staging'

const PROD_DB_URL = process.env.PROD_DB_URL
const STAGING_DB_URL = process.env.STAGING_DB_URL
const DEV_DB_URL = process.env.DEV_DB_URL

const SOURCE_DB_URL = PROD_DB_URL
const TARGET_DB_URL =
  TARGET_ENV === 'staging' ? STAGING_DB_URL : DEV_DB_URL

// ==============================
// ✅ VALIDATE ENV
// ==============================
if (!PROD_DB_URL) throw new Error('❌ PROD_DB_URL missing')
if (TARGET_ENV === 'staging' && !STAGING_DB_URL)
  throw new Error('❌ STAGING_DB_URL missing')
if (TARGET_ENV === 'development' && !DEV_DB_URL)
  throw new Error('❌ DEV_DB_URL missing')

if (!SOURCE_DB_URL) throw new Error('❌ SOURCE_DB_URL missing')
if (!TARGET_DB_URL) throw new Error('❌ TARGET_DB_URL missing')

// ==============================
// LOG
// ==============================
console.log('==============================')
console.log('🔄 Sync From PROD')
console.log('TARGET_ENV:', TARGET_ENV)
console.log('SOURCE:', new URL(SOURCE_DB_URL).host)
console.log('TARGET:', new URL(TARGET_DB_URL).host)
console.log('==============================')

// ==============================
// HELPERS
// ==============================
function run(cmd) {
  console.log(`$ ${cmd}`)
  execSync(cmd, { stdio: 'inherit' })
}

// ==============================
// MAIN
// ==============================
async function main() {
  const dumpFile = `tmp_dump_${Date.now()}.sql`

  // 🔥 dump
  run(`pg_dump --no-owner --no-privileges --dbname="${SOURCE_DB_URL}" > ${dumpFile}`)

  // 🔥 restore
  run(`psql "${TARGET_DB_URL}" -f ${dumpFile}`)

  // 🔥 normalize payment_status
  console.log('🧹 normalize payment_status...')

  const client = new Client({
    connectionString: TARGET_DB_URL,
    ssl: { rejectUnauthorized: false }
  })

  await client.connect()

  await client.query(`
    UPDATE documents
    SET payment_status = CASE
      WHEN COALESCE(paid_amount, 0) > 0 THEN 'paid'
      ELSE 'unpaid'
    END;
  `)

  await client.end()

  // cleanup
  fs.unlinkSync(dumpFile)

  console.log('==============================')
  console.log('✅ SYNC SUCCESS')
  console.log('==============================')
}

main().catch(err => {
  console.error('❌ Sync failed:', err.message)
  process.exit(1)
})
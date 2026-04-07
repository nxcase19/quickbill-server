#!/usr/bin/env node
/**
 * Dev DB sync CLI: dump prod → restore dev → normalize.
 * Requires pg_dump and psql on PATH. Credentials from env only.
 */
import { spawnSync } from 'node:child_process'
import { mkdirSync, readdirSync, statSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import dotenvFlow from 'dotenv-flow'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const SERVER_ROOT = path.resolve(__dirname, '../..')
const BACKUPS_DIR = path.join(__dirname, 'backups')
const NORMALIZE_SQL = path.join(__dirname, 'normalize-dev.sql')

dotenvFlow.config({
  path: SERVER_ROOT,
  default_node_env: 'development',
})

function run(cmd, args, opts = {}) {
  const r = spawnSync(cmd, args, {
    stdio: 'inherit',
    env: process.env,
    cwd: SERVER_ROOT,
    ...opts,
  })
  if (r.error) {
    console.error(`[error] spawn ${cmd}:`, r.error.message)
    process.exit(1)
  }
  if (r.status !== 0) process.exit(r.status ?? 1)
}

function parseDbUrl(raw) {
  if (!raw || typeof raw !== 'string') return null
  try {
    const normalized = raw.trim().replace(/^postgres(ql)?:/i, 'http:')
    const u = new URL(normalized)
    const database = decodeURIComponent(
      (u.pathname || '').replace(/^\//, '').split('?')[0] || '',
    )
    return {
      host: u.hostname,
      port: u.port || '5432',
      database,
    }
  } catch {
    return null
  }
}

function ensureSafeDevTarget() {
  const prod = process.env.PROD_DATABASE_URL
  const dev = process.env.DEV_DATABASE_URL
  if (!prod?.trim() || !dev?.trim()) {
    console.error(
      '[safety] Set both PROD_DATABASE_URL and DEV_DATABASE_URL before restore.',
    )
    process.exit(1)
  }
  if (prod.trim() === dev.trim()) {
    console.error(
      '[safety] FATAL: DEV_DATABASE_URL is identical to PROD_DATABASE_URL. Refusing to restore.',
    )
    process.exit(1)
  }
  const a = parseDbUrl(prod)
  const b = parseDbUrl(dev)
  if (
    a &&
    b &&
    a.host === b.host &&
    a.port === b.port &&
    a.database === b.database
  ) {
    console.error(
      '[safety] FATAL: Dev connection matches production (same host, port, and database name). Refusing to restore.',
    )
    process.exit(1)
  }
  console.log('[safety] Dev target is not the same DB as production — OK')
}

function stamp() {
  const d = new Date()
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`
}

function cmdDump() {
  const url = process.env.PROD_DATABASE_URL
  if (!url?.trim()) {
    console.error('[1/3] Missing PROD_DATABASE_URL')
    process.exit(1)
  }
  mkdirSync(BACKUPS_DIR, { recursive: true })
  const out = path.join(BACKUPS_DIR, `prod_dump_${stamp()}.sql`)
  console.log('[dump] Production →', out)
  run('pg_dump', ['--no-owner', '--no-acl', '-f', out, url.trim()])
  console.log('[dump] Success:', out)
}

function latestDumpPath() {
  let entries = []
  try {
    entries = readdirSync(BACKUPS_DIR)
  } catch {
    entries = []
  }
  const sql = entries.filter((f) => f.startsWith('prod_dump_') && f.endsWith('.sql'))
  if (!sql.length) {
    console.error('[restore] No prod_dump_*.sql files in scripts/db/backups/')
    process.exit(1)
  }
  const scored = sql.map((f) => ({
    f,
    m: statSync(path.join(BACKUPS_DIR, f)).mtimeMs,
  }))
  scored.sort((a, b) => b.m - a.m)
  return path.join(BACKUPS_DIR, scored[0].f)
}

function cmdRestore() {
  const dev = process.env.DEV_DATABASE_URL?.trim()
  if (!dev) {
    console.error('[restore] Missing DEV_DATABASE_URL')
    process.exit(1)
  }
  ensureSafeDevTarget()
  const file = latestDumpPath()
  console.log('[restore] Using dump:', file)
  console.log('[restore] Resetting schema public on DEV…')
  run('psql', [
    dev,
    '-v',
    'ON_ERROR_STOP=1',
    '-c',
    `DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;`,
  ])
  console.log('[restore] Applying dump…')
  run('psql', [dev, '-v', 'ON_ERROR_STOP=1', '-f', file])
  console.log('[restore] Success')
}

function cmdNormalize() {
  const dev = process.env.DEV_DATABASE_URL?.trim()
  if (!dev) {
    console.error('[normalize] Missing DEV_DATABASE_URL')
    process.exit(1)
  }
  console.log('[normalize] Applying', NORMALIZE_SQL)
  run('psql', [dev, '-v', 'ON_ERROR_STOP=1', '-f', NORMALIZE_SQL])
  console.log('[normalize] Success')
}

function cmdSync() {
  console.log('========== Dev data sync ==========')
  console.log('[1/3] Dump production')
  cmdDump()
  console.log('[2/3] Restore dev')
  cmdRestore()
  console.log('[3/3] Normalize dev')
  cmdNormalize()
  console.log('========== Done ==========')
}

const sub = process.argv[2]
const map = {
  dump: cmdDump,
  restore: cmdRestore,
  normalize: cmdNormalize,
  sync: cmdSync,
}
if (!sub || !map[sub]) {
  console.error('Usage: node scripts/db/db-cli.mjs <dump|restore|normalize|sync>')
  process.exit(1)
}
map[sub]()

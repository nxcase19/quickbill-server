/**
 * Free-plan document creation limits (per account_id).
 * Enforcement uses actual rows in `documents` (authoritative), not only usage_stats.
 * All document date filters use `doc_date` only (schema has no `created_at` on `documents`).
 */

import { getEffectivePlan, fetchAccountBillingRow } from './planService.js'
import { safeQuery } from './tenantQuery.js'

export const FREE_DAILY_DOC_LIMIT = 3
export const FREE_MONTHLY_DOC_LIMIT = 50

export class LimitReachedError extends Error {
  constructor(message = 'คุณใช้ครบแล้ว (Free Plan)') {
    super(message)
    this.code = 'LIMIT_REACHED'
  }
}

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 */
export async function countDocumentsCreatedToday(pool, accountId) {
  const { rows } = await safeQuery(
    pool,
    `SELECT COUNT(*)::int AS c
     FROM documents
     WHERE account_id = $1::uuid
       AND doc_date = CURRENT_DATE`,
    [accountId],
    { skipAssert: true },
  )
  return Number(rows[0]?.c ?? 0)
}

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 */
export async function countDocumentsCreatedThisMonth(pool, accountId) {
  const { rows } = await safeQuery(
    pool,
    `SELECT COUNT(*)::int AS c
     FROM documents
     WHERE account_id = $1::uuid
       AND date_trunc('month', doc_date::timestamp) = date_trunc('month', CURRENT_TIMESTAMP)`,
    [accountId],
    { skipAssert: true },
  )
  return Number(rows[0]?.c ?? 0)
}

/**
 * Block creation when free tier would exceed caps. Counts real documents for this account.
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 * @param {number} [additionalDocs] documents this request will create (e.g. length of doc_types)
 */
export async function checkDocumentLimit(pool, accountId, additionalDocs = 1) {
  const accountRow = await fetchAccountBillingRow(pool, accountId)
  const eff = accountRow ? getEffectivePlan(accountRow) : 'free'
  if (eff !== 'free') return

  const add = Number(additionalDocs)
  const n = Number.isFinite(add) && add > 0 ? Math.floor(add) : 1

  const todayCount = await countDocumentsCreatedToday(pool, accountId)
  if (todayCount + n > FREE_DAILY_DOC_LIMIT) {
    throw new LimitReachedError('คุณใช้ครบ 3 เอกสารต่อวันแล้ว')
  }

  const monthCount = await countDocumentsCreatedThisMonth(pool, accountId)
  if (monthCount + n > FREE_MONTHLY_DOC_LIMIT) {
    throw new LimitReachedError('คุณใช้ครบโควตาเอกสารต่อเดือนแล้ว')
  }
}

/**
 * Increment counters after successful document creation(s).
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 * @param {number} [delta]
 */
export async function incrementDocumentUsage(pool, accountId, delta = 1) {
  const n = Number(delta)
  if (!Number.isFinite(n) || n <= 0) return

  const accountRow = await fetchAccountBillingRow(pool, accountId)
  if (!accountRow) return
  if (getEffectivePlan(accountRow) !== 'free') return

  await pool.query(
    `INSERT INTO usage_stats (account_id, documents_today, documents_month, last_reset_date, usage_month_key)
     VALUES ($1::uuid, $2, $2, CURRENT_DATE, TO_CHAR(CURRENT_DATE, 'YYYY-MM'))
     ON CONFLICT (account_id) DO UPDATE SET
       documents_today = usage_stats.documents_today + EXCLUDED.documents_today,
       documents_month = usage_stats.documents_month + EXCLUDED.documents_month`,
    [accountId, n],
  )
}

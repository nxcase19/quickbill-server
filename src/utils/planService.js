/**
 * Billing / plan rules — effective access is driven by subscription + trial, not plan_type alone.
 * DB columns: accounts.plan_type, trial_*, subscription_id, subscription_ends_at, cancel_at_period_end.
 */

import { safeQuery } from './tenantQuery.js'
import { allowsProBasicAndTrial } from './planAccess.js'

export const PLAN_TYPES = Object.freeze(['free', 'trial', 'basic', 'pro', 'business'])

/** @typedef {'export'|'purchase_orders'|'tax_purchase'} BillingFeature */

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 * @returns {Promise<object|null>}
 */
export async function fetchAccountBillingRow(pool, accountId) {
  const { rows } = await safeQuery(
    pool,
    `SELECT id, plan_type, trial_started_at, trial_ends_at, subscription_id, subscription_ends_at, cancel_at_period_end
     FROM accounts
     WHERE id = $1::uuid`,
    [accountId],
    { skipAssert: true },
  )
  return rows[0] ?? null
}

/**
 * Paid window: non-empty subscription_id and subscription_ends_at strictly in the future.
 * @param {object|null|undefined} account
 * @returns {boolean}
 */
export function hasActiveSubscription(account) {
  if (!account) return false
  const sid = account.subscription_id
  if (sid == null || String(sid).trim() === '') return false
  const end = account.subscription_ends_at
  if (end == null) return false
  const t = new Date(end).getTime()
  if (!Number.isFinite(t)) return false
  return Date.now() < t
}

/**
 * @param {object|null|undefined} account
 * @returns {boolean}
 */
export function isTrialActive(account) {
  if (!account) return false
  const start = account.trial_started_at
  const end = account.trial_ends_at
  if (start == null || end == null) return false
  const now = Date.now()
  const t0 = new Date(start).getTime()
  const t1 = new Date(end).getTime()
  if (!Number.isFinite(t0) || !Number.isFinite(t1)) return false
  return now >= t0 && now < t1
}

function normalizePlanType(raw) {
  const p = String(raw ?? 'free').toLowerCase()
  return PLAN_TYPES.includes(p) ? p : 'free'
}

/**
 * Raw stored plan_type (labels / watermark); does not imply paid access.
 * @param {object|null|undefined} account
 * @returns {'free'|'trial'|'basic'|'pro'|'business'}
 */
export function getStoredPlan(account) {
  if (!account) return 'free'
  return normalizePlanType(account.plan_type)
}

function paidTierWhileSubscribed(account) {
  const stored = normalizePlanType(account.plan_type)
  if (stored === 'basic' || stored === 'pro' || stored === 'business') return stored
  return 'basic'
}

/**
 * Effective tier for UI + features.
 * - Active subscription → paid tier from plan_type (basic/pro/business), or basic if plan_type is inconsistent (never auto-upgrade).
 * - Else trial active → trial.
 * - Else → free.
 * plan_type alone never grants paid; subscription_id + subscription_ends_at do.
 * @param {object|null|undefined} account
 * @returns {'free'|'trial'|'basic'|'pro'}
 */
export function getEffectivePlan(account) {
  let eff
  if (!account) {
    eff = 'free'
  } else if (hasActiveSubscription(account)) {
    eff = paidTierWhileSubscribed(account)
  } else if (isTrialActive(account)) {
    eff = 'trial'
  } else {
    eff = 'free'
  }

  let normalized = String(eff || '').toLowerCase()
  if (normalized.startsWith('pro')) normalized = 'pro'
  else if (normalized.startsWith('business')) normalized = 'pro'
  else if (normalized.startsWith('basic')) normalized = 'basic'
  else if (normalized === 'trial') normalized = 'trial'
  else normalized = 'free'

  console.log('EFFECTIVE PLAN RAW:', eff)
  console.log('EFFECTIVE PLAN NORMALIZED:', normalized)

  return normalized
}

/**
 * @param {object|null|undefined} account
 * @param {BillingFeature} feature
 * @returns {boolean}
 */
export function canUseFeature(account, feature) {
  const eff = getEffectivePlan(account)
  if (feature === 'export' || feature === 'purchase_orders' || feature === 'tax_purchase') {
    return allowsProBasicAndTrial(eff)
  }
  return false
}

/**
 * Free + trial ended → PDF watermark (stored plan free).
 * @param {object|null|undefined} account
 */
export function shouldWatermarkFreePdf(account) {
  if (!account) return false
  if (isTrialActive(account)) return false
  return getStoredPlan(account) === 'free'
}

export const FREE_PLAN_PDF_WATERMARK = 'สร้างด้วย QuickBill (Free Plan)'

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 * @returns {Promise<string>}
 */
export async function getPdfWatermarkText(pool, accountId) {
  const row = await fetchAccountBillingRow(pool, accountId)
  return shouldWatermarkFreePdf(row) ? FREE_PLAN_PDF_WATERMARK : ''
}

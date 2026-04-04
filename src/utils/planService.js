/**
 * Billing / plan rules — trial window + subscription_ends_at for paid access (subscription_id not required).
 * DB columns: accounts.plan_type, trial_*, subscription_ends_at, cancel_at_period_end.
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
 * @param {object|null|undefined} account
 * @returns {boolean}
 */
export function isTrialActive(account) {
  if (!account) return false
  const now = new Date()
  if (String(account.plan_type ?? '').toLowerCase() !== 'trial') return false
  if (!account.trial_ends_at) return false
  const end = new Date(account.trial_ends_at)
  if (Number.isNaN(end.getTime())) return false
  return end > now
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

function normalizePaidEffectivePlan(raw) {
  const p = String(raw || 'pro').toLowerCase()
  if (p === 'basic') return 'basic'
  return 'pro'
}

/**
 * Effective tier: trial → paid if subscription_ends_at in future → legacy pro/business by plan_type → free.
 * @param {object|null|undefined} row
 * @returns {'free'|'trial'|'basic'|'pro'}
 */
export function getEffectivePlan(row) {
  if (!row) {
    console.log('[PLAN CHECK]', { effective: 'free', reason: 'no row' })
    return 'free'
  }

  const now = new Date()
  const planTypeRaw = String(row.plan_type ?? '').toLowerCase()

  // 1. Trial
  if (planTypeRaw === 'trial' && row.trial_ends_at) {
    const trialEnd = new Date(row.trial_ends_at)
    if (!Number.isNaN(trialEnd.getTime()) && trialEnd > now) {
      console.log('[PLAN CHECK]', { ...row, effective: 'trial' })
      return 'trial'
    }
  }

  // 2. Paid by subscription_ends_at ONLY (ignore subscription_id)
  if (row.subscription_ends_at) {
    const subEnd = new Date(row.subscription_ends_at)
    if (!Number.isNaN(subEnd.getTime()) && subEnd > now) {
      const paid = normalizePaidEffectivePlan(row.plan_type || 'pro')
      console.log('[PLAN CHECK]', { ...row, effective: paid, reason: 'subscription_ends_at' })
      return paid
    }
  }

  // 3. Fallback: plan_type = pro (for legacy / broken stripe)
  if (planTypeRaw === 'pro' || planTypeRaw === 'business') {
    console.log('[PLAN CHECK]', { ...row, effective: 'pro', reason: 'fallback plan_type' })
    return 'pro'
  }

  console.log('[PLAN CHECK]', { ...row, effective: 'free' })
  return 'free'
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
  return getEffectivePlan(account) === 'free'
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

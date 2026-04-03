/**
 * Pro-only features (not Basic): paid Pro + active trial — never block `trial`.
 * @param {string} [plan] effective tier (`req.user.plan` / `getEffectivePlan`, business → `pro`)
 */
export function allowsProAndTrialOnly(plan) {
  const p = String(plan ?? 'free').toLowerCase()
  return p === 'pro' || p === 'trial'
}

/**
 * Pro + Basic + trial (export, PO, tax purchase in this app) — only `free` is blocked.
 * @param {string} [plan]
 */
export function allowsProBasicAndTrial(plan) {
  const p = String(plan ?? 'free').toLowerCase()
  return p === 'pro' || p === 'basic' || p === 'trial' || p === 'business'
}

/**
 * Central plan → flags for limits and feature gates (aligned with product rules).
 * @param {string} [plan]
 */
export function getPlanAccess(plan) {
  const p = String(plan || 'free').toLowerCase()

  return {
    isFree: p === 'free',
    isTrial: p === 'trial',
    isBasic: p === 'basic',
    isPro: p === 'pro',
    isBusiness: p === 'business',

    limitDocuments: p === 'free',

    canExport: allowsProBasicAndTrial(p),
    canUsePO: allowsProBasicAndTrial(p),
    canRemoveWatermark: allowsProBasicAndTrial(p),
    canUseAdvancedTax: allowsProBasicAndTrial(p),

    isUnlimited: ['trial', 'basic', 'pro', 'business'].includes(p),
  }
}

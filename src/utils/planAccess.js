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

    canExport: p !== 'free',
    canUsePO: p !== 'free',
    canRemoveWatermark: p !== 'free',
    canUseAdvancedTax: p !== 'free',

    isUnlimited: ['trial', 'basic', 'pro', 'business'].includes(p),
  }
}

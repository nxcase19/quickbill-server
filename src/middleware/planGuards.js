/**
 * Express middleware — plan / usage enforcement (Phase 1 monetization).
 */

import { pool } from '../db.js'
import { requireAccountId } from '../utils/tenantQuery.js'
import { fetchAccountBillingRow, getEffectivePlan } from '../utils/planService.js'
import { getPlanAccess } from '../utils/planAccess.js'
import { checkDocumentLimit, LimitReachedError } from '../utils/usageService.js'

const MSG_UPGRADE = 'อัปเกรดเพื่อใช้งานฟีเจอร์นี้'

function pendingDocumentCountFromBody(req) {
  const types = req.body?.doc_types
  if (Array.isArray(types) && types.length > 0) return types.length
  if (req.body?.doc_type != null && String(req.body.doc_type).trim() !== '') return 1
  return 1
}

function sendUpgrade(res, feature) {
  return res.status(403).json({
    success: false,
    error: 'UPGRADE_REQUIRED',
    message: MSG_UPGRADE,
    feature,
  })
}

export async function assertCanCreateDocument(req, res, next) {
  try {
    let accountId
    try {
      accountId = requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    await checkDocumentLimit(pool, accountId, pendingDocumentCountFromBody(req))
    next()
  } catch (err) {
    if (err instanceof LimitReachedError || err?.code === 'LIMIT_REACHED') {
      return res.status(403).json({
        success: false,
        code: 'LIMIT_REACHED',
        error: 'LIMIT_REACHED',
        message: err.message || 'คุณใช้ครบแล้ว (Free Plan)',
      })
    }
    console.error('assertCanCreateDocument:', err)
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' })
  }
}

export async function assertCanExport(req, res, next) {
  try {
    let accountId
    try {
      accountId = requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    const row = await fetchAccountBillingRow(pool, accountId)
    if (!row) {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    const eff = getEffectivePlan(row)
    console.log('CHECK PLAN:', eff)
    if (!getPlanAccess(eff).canExport) {
      return sendUpgrade(res, 'export')
    }
    next()
  } catch (err) {
    console.error('assertCanExport:', err)
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' })
  }
}

export async function assertCanUsePO(req, res, next) {
  try {
    const accountId = requireAccountId(req)
    const row = await fetchAccountBillingRow(pool, accountId)
    if (!row) {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    const eff = getEffectivePlan(row)
    console.log('CHECK PLAN:', eff)
    if (!getPlanAccess(eff).canUsePO) {
      return sendUpgrade(res, 'purchase_orders')
    }
    next()
  } catch (err) {
    console.error('assertCanUsePO:', err)
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' })
  }
}

export async function assertCanUseTaxPurchase(req, res, next) {
  try {
    let accountId
    try {
      accountId = requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    const row = await fetchAccountBillingRow(pool, accountId)
    if (!row) {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    const eff = getEffectivePlan(row)
    console.log('CHECK PLAN:', eff)
    if (!getPlanAccess(eff).canUseAdvancedTax) {
      return sendUpgrade(res, 'tax_purchase')
    }
    next()
  } catch (err) {
    console.error('assertCanUseTaxPurchase:', err)
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' })
  }
}

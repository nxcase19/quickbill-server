import { pool } from '../db.js'
import { verifyAuthToken } from '../utils/authToken.js'
import { fetchAccountBillingRow, getEffectivePlan } from '../utils/planService.js'

/**
 * Server-side plan (never trust JWT/localStorage): trial | free | basic | pro
 * Paid plan wins over trial window (same rules as getEffectivePlan).
 */
async function resolveRequestPlan(accountId) {
  const row = await fetchAccountBillingRow(pool, accountId)
  let plan = 'free'
  let is_trial_active = false
  let trial_ends_at = null

  if (row) {
    trial_ends_at = row.trial_ends_at ?? null
    const eff = getEffectivePlan(row)
    if (eff === 'basic') plan = 'basic'
    else if (eff === 'pro' || eff === 'business') plan = 'pro'
    else if (eff === 'trial') {
      plan = 'trial'
      is_trial_active = true
    } else plan = 'free'
  }

  return { plan, is_trial_active, trial_ends_at }
}

export async function authMiddleware(req, res, next) {
  console.log('[AUTH] start', req.path)

  try {
    const authHeader = req.headers.authorization
    const hasBearer =
      typeof authHeader === 'string' && authHeader.startsWith('Bearer ')

    // DEV-ONLY: when no Bearer token, inject a fixed tenant so local UI works.
    // Never runs in production (NODE_ENV !== 'development').
    if (process.env.NODE_ENV === 'development' && !hasBearer) {
      const devAccountId =
        process.env.DEV_ACCOUNT_ID || '6466b94b-6852-4797-9378-7ae617809699'
      req.account_id = devAccountId
      let resolved
      try {
        resolved = await resolveRequestPlan(devAccountId)
      } catch (planErr) {
        console.error('[AUTH] resolveRequestPlan (dev):', planErr)
        return res.status(500).json({
          success: false,
          error: 'Auth service unavailable',
        })
      }
      req.user = {
        account_id: devAccountId,
        role: 'owner',
        dev_anonymous: true,
        plan: resolved.plan,
        is_trial_active: resolved.is_trial_active,
        trial_ends_at: resolved.trial_ends_at,
      }
      console.log('[AUTH] user ok', req.user.user_id ?? req.user.account_id)
      return next()
    }

    // GET /api/documents/:id/pdf?token=… — JWT verified in route (LINE in-app browser has no Bearer header)
    const rawQ = req.query?.token
    const tokenFromQuery =
      rawQ != null && String(rawQ).trim() !== '' ? String(rawQ).trim() : ''
    if (!hasBearer && tokenFromQuery) {
      const isDocumentsPdf =
        req.method === 'GET' &&
        typeof req.path === 'string' &&
        /\/pdf\/?$/i.test(req.path)
      if (isDocumentsPdf) {
        return next()
      }
    }

    if (!hasBearer) {
      console.log('[AUTH] unauthorized')
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Missing token',
      })
    }

    const token = authHeader.split(' ')[1]
    if (!token || String(token).trim() === '') {
      console.log('[AUTH] unauthorized')
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Missing token',
      })
    }

    let decoded
    try {
      decoded = verifyAuthToken(token)
    } catch {
      console.log('[AUTH] unauthorized')
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Invalid or expired token',
      })
    }

    const accountId = decoded?.account_id
    if (!accountId) {
      console.log('[AUTH] unauthorized')
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Invalid token',
      })
    }

    let resolved
    try {
      resolved = await resolveRequestPlan(accountId)
    } catch (planErr) {
      console.error('[AUTH] resolveRequestPlan:', planErr)
      return res.status(500).json({
        success: false,
        error: 'Auth service unavailable',
      })
    }

    req.account_id = accountId
    req.user = {
      user_id: decoded.user_id,
      account_id: accountId,
      email: decoded.email,
      role: decoded.role != null && String(decoded.role).trim() !== '' ? decoded.role : 'owner',
      plan: resolved.plan,
      is_trial_active: resolved.is_trial_active,
      trial_ends_at: resolved.trial_ends_at,
    }
    console.log('[AUTH] user ok', req.user.user_id ?? req.user.account_id)
    return next()
  } catch (err) {
    console.error('AUTH ERROR:', err)
    if (res.headersSent) {
      return next(err)
    }
    return res.status(500).json({
      success: false,
      error: 'Auth middleware error',
    })
  }
}

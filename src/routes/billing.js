import { Router } from 'express'
import { pool } from '../db.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import { requireAccountId } from '../utils/tenantQuery.js'
import {
  fetchAccountBillingRow,
  getEffectivePlan,
  getStoredPlan,
  isTrialActive,
} from '../utils/planService.js'
import {
  getPriceIdForPlan,
  getStripeClient,
  normalizePaidPlanType,
  resolvePlanFromPriceAndMetadata,
} from '../utils/stripeBilling.js'

const router = Router()

function isNonEmptyString(v) {
  return typeof v === 'string' && v.trim() !== ''
}

function normalizeString(v) {
  return isNonEmptyString(v) ? v.trim() : ''
}

function isUuidLike(s) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    String(s ?? ''),
  )
}

/**
 * @param {number|unknown} seconds
 * @param {number} [fallbackDays]
 * @returns {Date}
 */
function safeDateFromUnixSeconds(seconds, fallbackDays = 30) {
  const n = Number(seconds)
  if (Number.isFinite(n) && n > 0) {
    const d = new Date(n * 1000)
    if (!Number.isNaN(d.getTime())) return d
  }
  return new Date(Date.now() + fallbackDays * 24 * 60 * 60 * 1000)
}

/**
 * @param {import('stripe').Stripe.Subscription} subscription
 * @param {import('pg').Pool} db
 * @returns {Promise<{ accountId: string | null, subscriptionId: string, source: 'metadata' | 'subscription_id' | 'none' }>}
 */
async function resolveAccountIdFromSubscriptionRecord(subscription, db) {
  const subscriptionId = normalizeString(subscription?.id)
  const meta =
    subscription?.metadata && typeof subscription.metadata === 'object' ? subscription.metadata : {}
  const fromMeta = normalizeString(meta.account_id)
  if (fromMeta && isUuidLike(fromMeta)) {
    return { accountId: fromMeta, subscriptionId, source: 'metadata' }
  }

  if (subscriptionId) {
    try {
      const { rows } = await db.query(
        `SELECT id::text AS id
         FROM accounts
         WHERE subscription_id = $1::text
         LIMIT 1`,
        [subscriptionId],
      )
      const id = rows[0]?.id
      if (id && isUuidLike(id)) {
        return { accountId: String(id).trim(), subscriptionId, source: 'subscription_id' }
      }
    } catch (e) {
      console.warn('[stripe] resolveAccountIdFromSubscriptionRecord: lookup failed', {
        subscription_id: subscriptionId,
        message: e instanceof Error ? e.message : String(e),
      })
    }
  }

  return { accountId: null, subscriptionId, source: 'none' }
}

/**
 * @param {import('stripe').Stripe.Subscription} sub
 * @returns {string|null}
 */
function stripeCustomerIdFromSubscription(sub) {
  const c = sub?.customer
  if (typeof c === 'string' && normalizeString(c)) return normalizeString(c)
  if (c && typeof c === 'object' && c != null && 'id' in c) {
    return normalizeString(/** @type {{ id?: string }} */ (c).id)
  }
  return null
}

/**
 * @param {import('pg').Pool} db
 * @param {unknown} customerId
 * @returns {Promise<{ id: string } | null>}
 */
async function findAccountByCustomerId(db, customerId) {
  let raw = ''
  if (typeof customerId === 'string') {
    raw = customerId
  } else if (customerId && typeof customerId === 'object' && 'id' in customerId) {
    raw = String(/** @type {{ id?: unknown }} */ (customerId).id ?? '')
  } else if (customerId != null) {
    raw = String(customerId)
  }
  const id = normalizeString(raw)
  if (!id) return null
  const { rows } = await db.query(
    `SELECT id::text AS id
     FROM accounts
     WHERE stripe_customer_id = $1::text
     LIMIT 1`,
    [id],
  )
  const row = rows[0]
  const aid = row?.id && normalizeString(row.id)
  return aid ? { id: aid } : null
}

/**
 * @param {import('pg').Pool} db
 * @param {string} accountId
 * @returns {Promise<{ rowCount: number }>}
 */
async function downgradeAccountAfterSubscriptionRemoved(db, accountId) {
  // Never downgrade historical/free-only accounts without a real subscription.
  const result = await db.query(
    `UPDATE accounts
     SET
       plan_type = 'free',
       subscription_id = NULL,
       subscription_ends_at = NULL,
       cancel_at_period_end = false
     WHERE id::text = $1
       AND plan_type != 'free'
       AND subscription_id IS NOT NULL`,
    [accountId],
  )
  if (result.rowCount === 0) {
    console.log('[stripe] already free, skip downgrade', { account_id: accountId })
  }
  return { rowCount: result.rowCount }
}

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 * @param {import('stripe').Stripe.Subscription} subscription
 * @returns {Promise<{ applied: boolean, downgraded?: boolean, effectivePlan?: string, storedPlan?: string, reason?: string }>}
 */
async function applyStripeSubscriptionToAccount(pool, accountId, subscription) {
  if (!subscription || !subscription.status) {
    console.warn('INVALID SUBSCRIPTION — skip update', { account_id: accountId })
    return { applied: false, reason: 'invalid_subscription' }
  }

  try {
    const subscriptionIdStr = normalizeString(subscription.id)
    const priceId = normalizeString(subscription.items?.data?.[0]?.price?.id)
    const metaPlan = normalizeString(subscription.metadata?.plan_type)
    let planType = resolvePlanFromPriceAndMetadata(priceId, metaPlan || undefined)
    if (!planType) {
      const envBasic = normalizeString(process.env.STRIPE_PRICE_BASIC)
      const envPro = normalizeString(process.env.STRIPE_PRICE_PRO)
      const envBusiness = normalizeString(process.env.STRIPE_PRICE_BUSINESS)
      if (priceId && envBasic && priceId === envBasic) planType = 'basic'
      if (priceId && envPro && priceId === envPro) planType = 'pro'
      if (priceId && envBusiness && priceId === envBusiness) planType = 'business'
    }

    const status = String(subscription.status || '').toLowerCase()
    // Authoritative Stripe state: subscription ended — safe to align DB (not an API "error").
    if (status === 'canceled' || status === 'incomplete_expired') {
      await downgradeAccountAfterSubscriptionRemoved(pool, accountId)
      const row = await fetchAccountBillingRow(pool, accountId)
      return {
        applied: true,
        downgraded: true,
        effectivePlan: getEffectivePlan(row),
        storedPlan: getStoredPlan(row),
      }
    }

    if (!planType) {
      return { applied: false, reason: 'unknown_price' }
    }

    if (!['active', 'trialing', 'past_due'].includes(status)) {
      return { applied: false, reason: 'inactive_subscription' }
    }

    const currentPeriodEnd = safeDateFromUnixSeconds(subscription.current_period_end, 30)
    const cancelAtEnd = subscription.cancel_at_period_end === true
    const stripeCust = stripeCustomerIdFromSubscription(subscription)

    await pool.query(
      `UPDATE accounts
       SET plan_type = $1::text,
           subscription_id = $2::text,
           subscription_ends_at = $3::timestamptz,
           trial_ends_at = NOW(),
           cancel_at_period_end = $4,
           stripe_customer_id = COALESCE(NULLIF(TRIM($6::text), ''), stripe_customer_id)
       WHERE id::text = $5`,
      [planType, subscriptionIdStr, currentPeriodEnd, cancelAtEnd, accountId, stripeCust ?? ''],
    )

    const row = await fetchAccountBillingRow(pool, accountId)
    return {
      applied: true,
      effectivePlan: getEffectivePlan(row),
      storedPlan: planType,
    }
  } catch (err) {
    console.error('STRIPE SYNC FAILED (applyStripeSubscriptionToAccount):', err)
    return { applied: false, reason: 'apply_error' }
  }
}

/**
 * Pure read: DB row + getEffectivePlan only. No Stripe, no writes, no usage queries.
 * Single try/catch — always sends JSON (never hang or exit without response).
 */
router.get('/plan', async (req, res) => {
  try {
    const accountId = requireAccountId(req)

    const row = await fetchAccountBillingRow(pool, accountId)
    const effective = getEffectivePlan(row)

    const raw = row?.plan_type ?? 'free'
    const lower = String(raw).toLowerCase()

    let stored = 'free'
    if (lower.startsWith('pro') || lower.startsWith('business')) stored = 'pro'
    else if (lower.startsWith('basic')) stored = 'basic'
    else if (lower === 'trial') stored = 'trial'

    console.log('[PLAN API OK]', { accountId, stored, effective })

    return res.status(200).json({
      success: true,
      data: {
        plan: stored,
        planType: stored,
        effectivePlan: effective,
        trialActive: effective === 'trial',
        trialEndsAt: row?.trial_ends_at ?? null,
        subscriptionEndsAt: row?.subscription_ends_at ?? null,
        cancelAtPeriodEnd: row?.cancel_at_period_end === true,
        features: {},
        limits: {},
      },
    })
  } catch (err) {
    console.error('[PLAN API ERROR]', err)
    if (res.headersSent) return
    const msg = err instanceof Error ? err.message : String(err)
    if (msg === 'Missing account_id') {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    return res.status(500).json({
      success: false,
      error: 'Plan fetch failed',
    })
  }
})

router.get('/info', async (req, res) => {
  try {
    let accountId
    try {
      accountId = requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }

    logTenantAccess('GET /api/billing/info', req)

    const row = await fetchAccountBillingRow(pool, accountId)
    if (!row) {
      return res.status(404).json({ success: false, error: 'Account not found' })
    }

    return res.json({
      success: true,
      data: {
        planType: getStoredPlan(row),
        effectivePlan: getEffectivePlan(row),
        trialActive: isTrialActive(row),
        trialEndsAt: row.trial_ends_at ?? null,
        subscriptionEndsAt: row.subscription_ends_at ?? null,
        cancelAtPeriodEnd: row.cancel_at_period_end === true,
      },
    })
  } catch (err) {
    console.error('GET /billing/info:', err)
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' })
  }
})

router.get('/trial-status', async (req, res) => {
  try {
    try {
      requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }

    const trialEnds = req.user?.trial_ends_at ?? null
    const now = Date.now()
    let daysLeft = null
    if (trialEnds) {
      const end = new Date(trialEnds)
      if (!Number.isNaN(end.getTime())) {
        daysLeft = Math.ceil((end.getTime() - now) / (1000 * 60 * 60 * 24))
      }
    }

    const plan = String(req.user?.plan || 'free').toLowerCase()

    return res.json({
      success: true,
      data: {
        plan,
        trialEnds,
        daysLeft,
        isTrialActive: req.user?.is_trial_active === true,
      },
    })
  } catch (err) {
    console.error('GET /billing/trial-status:', err)
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' })
  }
})

/**
 * Disabled: subscription/plan rows are updated only by Stripe webhooks (signed events).
 */
router.get('/sync-plan', async (req, res) => {
  try {
    try {
      requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    return res.status(403).json({
      success: false,
      error: 'Plan updates are applied only via Stripe webhooks; manual sync is disabled.',
    })
  } catch (err) {
    console.error('SYNC PLAN ERROR:', err)
    return res.status(500).json({ success: false, error: 'sync failed' })
  }
})

router.post('/create-checkout-session', async (req, res) => {
  try {
    let accountId
    try {
      accountId = requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }

    if (req.user?.dev_anonymous) {
      return res.status(400).json({
        success: false,
        error: 'Checkout requires a logged-in account (not dev anonymous)',
      })
    }

    const planType = normalizePaidPlanType(req.body?.plan_type)
    if (!planType) {
      return res.status(400).json({
        success: false,
        error: 'Invalid plan_type (expected basic, pro, or business)',
      })
    }

    const priceId = getPriceIdForPlan(planType)
    const stripe = getStripeClient()
    if (!stripe || !priceId) {
      return res.status(503).json({
        success: false,
        error: 'Billing is not configured (Stripe keys or price IDs)',
      })
    }

    const email = normalizeString(req.user?.email)
    if (!email) {
      return res.status(400).json({ success: false, error: 'Missing user email for checkout' })
    }

    const frontend = String(process.env.FRONTEND_URL || 'http://localhost:5173').replace(/\/$/, '')

    logTenantAccess('POST /api/billing/create-checkout-session', req)

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      mode: 'subscription',
      customer_email: email,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${frontend}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${frontend}/pricing`,
      client_reference_id: accountId,
      metadata: {
        account_id: String(accountId),
        plan_type: String(planType),
      },
      subscription_data: {
        metadata: {
          account_id: String(accountId),
          plan_type: String(planType),
        },
      },
    })

    if (!session.url) {
      return res.status(500).json({ success: false, error: 'Checkout session missing URL' })
    }

    return res.json({ success: true, url: session.url })
  } catch (err) {
    console.error('POST /create-checkout-session:', err)
    return res.status(500).json({ success: false, error: err.message || 'Checkout failed' })
  }
})

router.post('/cancel-subscription', async (req, res) => {
  try {
    const accountId = requireAccountId(req)

    if (req.user?.dev_anonymous) {
      return res.status(400).json({
        success: false,
        error: 'Cancel subscription requires a logged-in account',
      })
    }

    const stripe = getStripeClient()
    if (!stripe) {
      return res.status(503).json({ success: false, error: 'Billing is not configured' })
    }

    logTenantAccess('POST /api/billing/cancel-subscription', req)

    const { rows } = await pool.query(
      `SELECT subscription_id
       FROM accounts
       WHERE id = $1::uuid`,
      [accountId],
    )
    const subscriptionId = normalizeString(rows[0]?.subscription_id)

    console.log('[stripe] cancel-subscription', {
      account_id: accountId,
      subscription_id: subscriptionId || null,
    })

    if (!subscriptionId) {
      return res.status(400).json({
        success: false,
        error: 'ไม่พบแพ็กเกจที่กำลังใช้งาน',
      })
    }

    await stripe.subscriptions.update(subscriptionId, { cancel_at_period_end: true })

    await pool.query(
      `UPDATE accounts SET cancel_at_period_end = true WHERE id = $1::uuid`,
      [accountId],
    )

    return res.json({
      success: true,
      message: 'Subscription will cancel at period end',
      cancelAtPeriodEnd: true,
    })
  } catch (err) {
    console.error('POST /cancel-subscription:', err)
    return res.status(500).json({
      success: false,
      error: err.message || 'Cancel subscription failed',
    })
  }
})

export default router

/**
 * Raw body + signature verification only. Mounted in app.js before express.json().
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 */
export async function handleStripeWebhook(req, res) {
  const secret = process.env.STRIPE_WEBHOOK_SECRET
  const stripe = getStripeClient()
  if (!secret || !stripe) {
    console.error('[stripe] webhook: missing STRIPE_WEBHOOK_SECRET or STRIPE_SECRET_KEY')
    return res.status(503).send('Billing not configured')
  }

  const sig = req.headers['stripe-signature']
  if (typeof sig !== 'string') {
    return res.status(400).send('Missing stripe-signature')
  }

  let event
  try {
    const rawBody = req.body
    if (!Buffer.isBuffer(rawBody)) {
      return res.status(400).send('Webhook requires raw body')
    }
    event = stripe.webhooks.constructEvent(rawBody, sig, secret)
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error('[stripe] webhook signature:', msg)
    return res.status(400).send(`Webhook Error: ${msg}`)
  }

  console.log('[STRIPE WEBHOOK RECEIVED]', { type: event.type, id: event.id })

  try {
    if (event.type === 'checkout.session.completed') {
      const session = /** @type {import('stripe').Stripe.Checkout.Session} */ (event.data.object)
      const sessionId = session.id != null ? String(session.id) : null

      console.log('[stripe] webhook checkout.session.completed received', {
        session_id: sessionId,
      })

      const accountId =
        normalizeString(session.metadata?.account_id) ||
        normalizeString(session.client_reference_id) ||
        null

      if (!accountId) {
        console.warn('[stripe] checkout.session.completed: missing account_id (no metadata.account_id or client_reference_id)', {
          session_id: sessionId,
          session_metadata: session.metadata ?? null,
          session_client_reference_id: session.client_reference_id ?? null,
        })
        return res.status(200).json({ received: true })
      }

      const rawSub = session.subscription
      const subscriptionId =
        typeof rawSub === 'string'
          ? rawSub
          : rawSub && typeof rawSub === 'object' && rawSub != null && 'id' in rawSub
            ? String(/** @type {{ id: string }} */ (rawSub).id)
            : ''
      const subscriptionIdStr = normalizeString(subscriptionId)

      if (!subscriptionIdStr) {
        console.warn('[stripe] checkout.session.completed: missing subscription_id', {
          session_id: sessionId,
          account_id: accountId,
          session_metadata: session.metadata ?? null,
          session_client_reference_id: session.client_reference_id ?? null,
        })
        return res.status(200).json({ received: true })
      }

      const subscription = await stripe.subscriptions.retrieve(subscriptionIdStr)
      const priceId = normalizeString(subscription.items?.data?.[0]?.price?.id)

      const envBasic = normalizeString(process.env.STRIPE_PRICE_BASIC)
      const envPro = normalizeString(process.env.STRIPE_PRICE_PRO)
      const envBusiness = normalizeString(process.env.STRIPE_PRICE_BUSINESS)

      let planType = null
      if (priceId && envBasic && priceId === envBasic) planType = 'basic'
      if (priceId && envPro && priceId === envPro) planType = 'pro'
      if (priceId && envBusiness && priceId === envBusiness) planType = 'business'

      const currentPeriodEnd = safeDateFromUnixSeconds(subscription.current_period_end, 30)
      const stripeCustomerId = stripeCustomerIdFromSubscription(subscription)

      console.log('[stripe] checkout.session.completed detail', {
        session_id: sessionId,
        session_metadata: session.metadata ?? null,
        session_client_reference_id: session.client_reference_id ?? null,
        subscription_id: subscriptionIdStr,
        price_id: priceId || null,
        mapped_plan_type: planType || null,
        current_period_end: currentPeriodEnd.toISOString(),
      })

      if (!planType) {
        console.warn('[stripe] checkout.session.completed: unknown price id', {
          session_id: sessionId,
          account_id: accountId,
          subscription_id: subscriptionIdStr,
          price_id: priceId || null,
        })
        console.log('[stripe] checkout.session.completed FINAL', {
          session_id: sessionId,
          account_id: accountId,
          subscription_id: subscriptionIdStr,
          plan_type: null,
          updated_rows: 0,
        })
        return res.status(200).json({ received: true })
      }

      const updateCheckoutAccountSql = `UPDATE accounts
         SET
           plan_type = $1::text,
           subscription_id = $2::text,
           subscription_ends_at = $3::timestamptz,
           trial_ends_at = NOW(),
           cancel_at_period_end = false,
           stripe_customer_id = COALESCE(NULLIF(TRIM($5::text), ''), stripe_customer_id)
         WHERE id::text = $4`

      const result = await pool.query(updateCheckoutAccountSql, [
        planType,
        subscriptionIdStr,
        currentPeriodEnd,
        accountId,
        stripeCustomerId ?? '',
      ])

      console.log('[stripe] checkout.session.completed UPDATE primary', {
        session_id: sessionId,
        account_id: accountId,
        subscription_id: subscriptionIdStr,
        price_id: priceId || null,
        mapped_plan_type: planType,
        current_period_end: currentPeriodEnd.toISOString(),
        result_row_count: result.rowCount,
      })

      let fallbackBySubRowCount = 0
      if (result.rowCount === 0) {
        console.warn('[stripe] primary update failed, try fallback by subscription_id')
        const fallback = await pool.query(
          `UPDATE accounts
           SET
             plan_type = $1::text,
             subscription_id = $2::text,
             subscription_ends_at = $3::timestamptz,
             trial_ends_at = NOW(),
             cancel_at_period_end = false,
             stripe_customer_id = COALESCE(NULLIF(TRIM($4::text), ''), stripe_customer_id)
           WHERE subscription_id = $2::text`,
          [planType, subscriptionIdStr, currentPeriodEnd, stripeCustomerId ?? ''],
        )
        fallbackBySubRowCount = fallback.rowCount
        console.log('[stripe] fallback update result', {
          updated_rows: fallback.rowCount,
        })
      }

      console.log('[stripe] FINAL UPDATE RESULT', {
        account_id: accountId,
        subscription_id: subscriptionIdStr,
        plan_type: planType,
        primary_updated: result.rowCount,
      })

      let finalAccountId = accountId
      let updatedRows = result.rowCount > 0 ? result.rowCount : fallbackBySubRowCount
      if (result.rowCount === 0 && fallbackBySubRowCount > 0) {
        try {
          const { rows: idRows } = await pool.query(
            `SELECT id::text AS id
             FROM accounts
             WHERE subscription_id = $1::text
             LIMIT 1`,
            [subscriptionIdStr],
          )
          const resolved = normalizeString(idRows[0]?.id)
          if (resolved) finalAccountId = resolved
        } catch {
          /* keep accountId */
        }
      }

      if (result.rowCount === 0 && fallbackBySubRowCount === 0) {
        console.warn('[stripe] checkout.session.completed: primary and subscription_id UPDATE rowCount=0, trying legacy SELECT + UPDATE by id', {
          session_id: sessionId,
          attempted_account_id: accountId,
          subscription_id: subscriptionIdStr,
        })
        try {
          const { rows: bySub } = await pool.query(
            `SELECT id::text AS id
             FROM accounts
             WHERE subscription_id = $1::text
             LIMIT 1`,
            [subscriptionIdStr],
          )
          const altId = normalizeString(bySub[0]?.id)
          if (altId) {
            const resultFb = await pool.query(updateCheckoutAccountSql, [
              planType,
              subscriptionIdStr,
              currentPeriodEnd,
              altId,
              stripeCustomerId ?? '',
            ])
            updatedRows = resultFb.rowCount
            finalAccountId = altId
            console.log('[stripe] checkout.session.completed fallback by subscription_id', {
              session_id: sessionId,
              ok: resultFb.rowCount > 0,
              account_id: altId,
              updated_rows: resultFb.rowCount,
            })
          } else {
            console.warn('[stripe] checkout.session.completed: fallback by subscription_id found no row', {
              session_id: sessionId,
              subscription_id: subscriptionIdStr,
            })
          }
        } catch (fbErr) {
          console.warn('[stripe] checkout.session.completed: fallback by subscription_id failed', {
            session_id: sessionId,
            subscription_id: subscriptionIdStr,
            message: fbErr instanceof Error ? fbErr.message : String(fbErr),
          })
        }
      }

      console.log('[stripe] checkout.session.completed FINAL', {
        session_id: sessionId,
        account_id: finalAccountId,
        subscription_id: subscriptionIdStr,
        plan_type: planType,
        updated_rows: updatedRows,
      })

      if (updatedRows > 0) {
        console.log('[PLAN UPDATED FROM STRIPE]', {
          event: 'checkout.session.completed',
          account_id: finalAccountId,
          plan_type: planType,
          subscription_id: subscriptionIdStr,
          stripe_status: String(subscription.status || ''),
        })
      }

      return res.status(200).json({ received: true })
    }

    if (event.type === 'customer.subscription.updated') {
      const sub = /** @type {import('stripe').Stripe.Subscription} */ (event.data.object)
      const status = String(sub.status || '').toLowerCase()
      const cancelAtEnd = sub.cancel_at_period_end === true

      const { accountId, subscriptionId, source } = await resolveAccountIdFromSubscriptionRecord(
        sub,
        pool,
      )

      console.log('[PLAN UPDATED FROM STRIPE]', {
        event: 'customer.subscription.updated',
        account_id: accountId,
        cancel_at_period_end: cancelAtEnd,
        subscription_id: subscriptionId || null,
      })

      console.log('[stripe] customer.subscription.updated', {
        account_id: accountId,
        subscription_id: subscriptionId || null,
        status,
        cancel_at_period_end: cancelAtEnd,
        resolution: source,
      })

      if (accountId && cancelAtEnd) {
        console.log('[INFO] subscription will cancel at period end', { account_id: accountId })
      }

      if (!accountId) {
        console.warn('[stripe] customer.subscription.updated: missing account_id', {
          subscription_id: subscriptionId || null,
        })
        return res.status(200).json({ received: true })
      }

      if (status === 'canceled' || status === 'incomplete_expired') {
        const down = await downgradeAccountAfterSubscriptionRemoved(pool, accountId)
        console.log('[stripe] customer.subscription.updated: downgraded', {
          account_id: accountId,
          subscription_id: subscriptionId || null,
          status,
          updated_rows: down.rowCount,
        })
        console.log('[SUBSCRIPTION CANCELLED]', {
          event: 'customer.subscription.updated',
          account_id: accountId,
          subscription_id: subscriptionId || null,
          status,
          updated_rows: down.rowCount,
        })
        return res.status(200).json({ received: true })
      }

      const end = safeDateFromUnixSeconds(sub.current_period_end, 30)
      const result = await pool.query(
        `UPDATE accounts
         SET
           subscription_ends_at = $2::timestamptz,
           cancel_at_period_end = $3
         WHERE id::text = $1`,
        [accountId, end, cancelAtEnd],
      )

      console.log('[stripe] customer.subscription.updated: db updated', {
        account_id: accountId,
        subscription_id: subscriptionId || null,
        computed_current_period_end: end.toISOString(),
        updated_rows: result.rowCount,
      })

      return res.status(200).json({ received: true })
    }

    if (event.type === 'customer.subscription.deleted') {
      const sub = /** @type {import('stripe').Stripe.Subscription} */ (event.data.object)
      const { accountId, subscriptionId, source } = await resolveAccountIdFromSubscriptionRecord(
        sub,
        pool,
      )

      console.log('[stripe] customer.subscription.deleted', {
        account_id: accountId,
        subscription_id: subscriptionId || null,
        resolution: source,
      })

      if (!accountId) {
        console.warn('[stripe] customer.subscription.deleted: missing account_id', {
          subscription_id: subscriptionId || null,
        })
        return res.status(200).json({ received: true })
      }

      const down = await downgradeAccountAfterSubscriptionRemoved(pool, accountId)
      console.log('[stripe] customer.subscription.deleted: downgraded', {
        account_id: accountId,
        subscription_id: subscriptionId || null,
        updated_rows: down.rowCount,
      })
      console.log('[SUBSCRIPTION CANCELLED]', {
        event: 'customer.subscription.deleted',
        account_id: accountId,
        subscription_id: subscriptionId || null,
        updated_rows: down.rowCount,
      })
      console.log('[DOWNGRADE] subscription canceled → FREE:', accountId)

      return res.status(200).json({ received: true })
    }

    if (event.type === 'invoice.payment_succeeded') {
      const invoice = /** @type {import('stripe').Stripe.Invoice} */ (event.data.object)
      const rawSub = invoice.subscription
      const subscriptionId =
        typeof rawSub === 'string'
          ? rawSub
          : rawSub && typeof rawSub === 'object' && rawSub != null && 'id' in rawSub
            ? String(/** @type {{ id: string }} */ (rawSub).id)
            : ''
      const subscriptionIdStr = normalizeString(subscriptionId)
      if (!subscriptionIdStr) {
        return res.status(200).json({ received: true })
      }

      const subscription = await stripe.subscriptions.retrieve(subscriptionIdStr)
      let { accountId, subscriptionId: subIdFromRecord, source } =
        await resolveAccountIdFromSubscriptionRecord(subscription, pool)

      const invCustomerId = stripeCustomerIdFromSubscription({
        customer: invoice.customer,
      })
      const subCustomerId = stripeCustomerIdFromSubscription(subscription)
      if (!accountId && invCustomerId && subCustomerId === invCustomerId) {
        const acct = await findAccountByCustomerId(pool, invCustomerId)
        if (acct) {
          accountId = acct.id
          source = 'stripe_customer_id'
        }
      }

      console.log('[stripe] invoice.payment_succeeded', {
        account_id: accountId,
        subscription_id: subscriptionIdStr,
        resolution: source,
      })

      if (!accountId) {
        console.warn('[stripe] invoice.payment_succeeded: missing account_id', {
          subscription_id: subscriptionIdStr,
        })
        return res.status(200).json({ received: true })
      }

      const applied = await applyStripeSubscriptionToAccount(pool, accountId, subscription)
      if (applied.applied && !applied.downgraded) {
        console.log('[PLAN UPDATED FROM STRIPE]', {
          event: 'invoice.payment_succeeded',
          account_id: accountId,
          plan_type: applied.storedPlan ?? null,
          subscription_id: subscriptionIdStr,
          stripe_status: String(subscription.status || ''),
        })
        console.log('[RENEWAL] payment success → keep paid tier:', accountId, applied.storedPlan)
      } else if (applied.applied && applied.downgraded) {
        console.log('[SUBSCRIPTION CANCELLED]', {
          event: 'invoice.payment_succeeded',
          account_id: accountId,
          subscription_id: subIdFromRecord || subscriptionIdStr,
          reason: 'subscription_inactive_in_stripe',
        })
      } else if (!applied.applied && applied.reason === 'unknown_price') {
        const end = safeDateFromUnixSeconds(subscription.current_period_end, 30)
        const stripeCust = stripeCustomerIdFromSubscription(subscription)
        const result = await pool.query(
          `UPDATE accounts
           SET subscription_ends_at = $2::timestamptz,
               stripe_customer_id = COALESCE(NULLIF(TRIM($3::text), ''), stripe_customer_id)
           WHERE id::text = $1`,
          [accountId, end, stripeCust ?? ''],
        )
        console.log('[stripe] invoice.payment_succeeded: extended period only (unknown price)', {
          account_id: accountId,
          subscription_id: subIdFromRecord || subscriptionIdStr,
          computed_current_period_end: end.toISOString(),
          updated_rows: result.rowCount,
        })
        if (result.rowCount > 0) {
          console.log('[PLAN UPDATED FROM STRIPE]', {
            event: 'invoice.payment_succeeded',
            account_id: accountId,
            detail: 'subscription_ends_extended_unknown_price',
            subscription_id: subIdFromRecord || subscriptionIdStr,
          })
        }
      }

      return res.status(200).json({ received: true })
    }

    if (event.type === 'invoice.payment_failed') {
      const invoice = /** @type {import('stripe').Stripe.Invoice} */ (event.data.object)
      const rawSub = invoice.subscription
      const subscriptionId =
        typeof rawSub === 'string'
          ? rawSub
          : rawSub && typeof rawSub === 'object' && rawSub != null && 'id' in rawSub
            ? String(/** @type {{ id: string }} */ (rawSub).id)
            : ''
      const subscriptionIdStr = normalizeString(subscriptionId)

      try {
        let accountId = null
        if (subscriptionIdStr) {
          const subscription = await stripe.subscriptions.retrieve(subscriptionIdStr)
          accountId = (await resolveAccountIdFromSubscriptionRecord(subscription, pool)).accountId
          const invCust = stripeCustomerIdFromSubscription({ customer: invoice.customer })
          const subCust = stripeCustomerIdFromSubscription(subscription)
          if (!accountId && invCust && subCust === invCust) {
            const acct = await findAccountByCustomerId(pool, invCust)
            if (acct) accountId = acct.id
          }
        } else {
          const invCust = stripeCustomerIdFromSubscription({ customer: invoice.customer })
          if (invCust) {
            const acct = await findAccountByCustomerId(pool, invCust)
            if (acct) accountId = acct.id
          }
        }

        if (accountId) {
          const down = await downgradeAccountAfterSubscriptionRemoved(pool, accountId)
          console.log('[SUBSCRIPTION CANCELLED]', {
            event: 'invoice.payment_failed',
            account_id: accountId,
            subscription_id: subscriptionIdStr || null,
            invoice_id: invoice.id,
            updated_rows: down.rowCount,
          })
          console.log('[DOWNGRADE] payment failed → FREE:', accountId, {
            invoice_id: invoice.id,
            subscription_id: subscriptionIdStr || null,
            attempt_count: invoice.attempt_count,
            updated_rows: down.rowCount,
          })
        } else {
          console.warn('[stripe] invoice.payment_failed: could not resolve account', {
            invoice_id: invoice.id,
            subscription_id: subscriptionIdStr || null,
            attempt_count: invoice.attempt_count,
          })
        }
      } catch (e) {
        console.error('[stripe] invoice.payment_failed handler', {
          message: e instanceof Error ? e.message : String(e),
          invoice_id: invoice.id,
        })
      }

      return res.status(200).json({ received: true })
    }

    return res.status(200).json({ received: true })
  } catch (err) {
    console.error('[stripe] webhook handler error:', err)
    return res.status(500).json({ success: false, error: 'Webhook processing failed' })
  }
}

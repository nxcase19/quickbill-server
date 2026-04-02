import { Router } from 'express'
import { pool } from '../db.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import { requireAccountId } from '../utils/tenantQuery.js'
import {
  fetchAccountBillingRow,
  getEffectivePlan,
  getStoredPlan,
  isTrialActive,
  canUseFeature,
} from '../utils/planService.js'
import {
  FREE_DAILY_DOC_LIMIT,
  FREE_MONTHLY_DOC_LIMIT,
  countDocumentsCreatedToday,
} from '../utils/usageService.js'
import {
  getPriceIdForPlan,
  getStripeClient,
  normalizePaidPlanType,
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
 * @param {import('pg').Pool} db
 * @param {string} accountId
 * @returns {Promise<{ rowCount: number }>}
 */
async function downgradeAccountAfterSubscriptionRemoved(db, accountId) {
  const result = await db.query(
    `UPDATE accounts
     SET
       plan_type = 'free',
       subscription_id = NULL,
       subscription_ends_at = NULL,
       cancel_at_period_end = false
     WHERE id::text = $1
       AND plan_type != 'free'`,
    [accountId],
  )
  if (result.rowCount === 0) {
    console.log('[stripe] already free, skip downgrade', { account_id: accountId })
  }
  return { rowCount: result.rowCount }
}

/**
 * @param {import('pg').Pool} db
 * @param {string} accountId
 */
async function buildBillingPlanData(db, accountId) {
  const row = await fetchAccountBillingRow(db, accountId)
  if (!row) return null

  const effectivePlan = getEffectivePlan(row)
  const trialActive = isTrialActive(row)

  let documentsCreatedToday = null
  if (effectivePlan === 'free') {
    documentsCreatedToday = await countDocumentsCreatedToday(db, accountId)
  }

  return {
    planType: getStoredPlan(row),
    effectivePlan,
    trialActive,
    trialEndsAt: row.trial_ends_at ?? null,
    subscriptionEndsAt: row.subscription_ends_at ?? null,
    cancelAtPeriodEnd: row.cancel_at_period_end === true,
    features: {
      export: canUseFeature(row, 'export'),
      purchase_orders: canUseFeature(row, 'purchase_orders'),
      tax_purchase: canUseFeature(row, 'tax_purchase'),
    },
    limits: {
      freeDocumentsPerDay: FREE_DAILY_DOC_LIMIT,
      freeDocumentsPerMonth: FREE_MONTHLY_DOC_LIMIT,
    },
    documentsCreatedToday,
  }
}

router.get('/plan', async (req, res) => {
  try {
    let accountId
    try {
      accountId = requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }

    logTenantAccess('GET /api/billing/plan', req)

    const data = await buildBillingPlanData(pool, accountId)
    if (!data) {
      return res.status(404).json({ success: false, error: 'Account not found' })
    }

    return res.json({ success: true, data })
  } catch (err) {
    console.error('GET /billing/plan:', err)
    return res.status(500).json({ success: false, error: err.message || 'Internal server error' })
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
      success_url: `${frontend}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
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
      return res.status(400).json({ success: false, error: 'No subscription_id for this account' })
    }

    await stripe.subscriptions.update(subscriptionId, { cancel_at_period_end: true })

    await pool.query(
      `UPDATE accounts
       SET cancel_at_period_end = true
       WHERE id = $1::uuid`,
      [accountId],
    )

    return res.json({
      success: true,
      message: 'Subscription will cancel at period end',
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

  console.log('[stripe] event:', event.type)

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
           cancel_at_period_end = false
         WHERE id::text = $4`

      const result = await pool.query(updateCheckoutAccountSql, [
        planType,
        subscriptionIdStr,
        currentPeriodEnd,
        accountId,
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

      let finalAccountId = accountId
      let updatedRows = result.rowCount

      if (result.rowCount === 0) {
        console.warn('[stripe] checkout.session.completed: primary UPDATE rowCount=0, trying fallback by subscription_id', {
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

      console.log('[stripe] customer.subscription.updated', {
        account_id: accountId,
        subscription_id: subscriptionId || null,
        status,
        cancel_at_period_end: cancelAtEnd,
        resolution: source,
      })

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
      const { accountId, subscriptionId: subIdFromRecord, source } =
        await resolveAccountIdFromSubscriptionRecord(subscription, pool)

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

      const end = safeDateFromUnixSeconds(subscription.current_period_end, 30)
      const result = await pool.query(
        `UPDATE accounts
         SET subscription_ends_at = $2::timestamptz
         WHERE id::text = $1`,
        [accountId, end],
      )

      console.log('[stripe] invoice.payment_succeeded: db updated', {
        account_id: accountId,
        subscription_id: subIdFromRecord || subscriptionIdStr,
        computed_current_period_end: end.toISOString(),
        updated_rows: result.rowCount,
      })

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
      console.warn('[stripe] invoice.payment_failed (no immediate downgrade)', {
        invoice_id: invoice.id,
        subscription_id: normalizeString(subscriptionId) || null,
        attempt_count: invoice.attempt_count,
      })
      return res.status(200).json({ received: true })
    }

    return res.status(200).json({ received: true })
  } catch (err) {
    console.error('[stripe] webhook handler error:', err)
    return res.status(500).json({ success: false, error: 'Webhook processing failed' })
  }
}

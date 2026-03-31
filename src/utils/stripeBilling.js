/**
 * Stripe subscription mapping — single place for price ↔ plan (env-driven).
 * Webhook updates DB; never trust client plan_type without verifying Stripe price id.
 */

import Stripe from 'stripe'

const PAID_PLANS = Object.freeze(['basic', 'pro', 'business'])

/** @returns {Record<string, string>} */
export function stripePriceIdMap() {
  return {
    basic: String(process.env.STRIPE_PRICE_BASIC || '').trim(),
    pro: String(process.env.STRIPE_PRICE_PRO || '').trim(),
    business: String(process.env.STRIPE_PRICE_BUSINESS || '').trim(),
  }
}

/**
 * @param {unknown} raw
 * @returns {'basic'|'pro'|'business'|null}
 */
export function normalizePaidPlanType(raw) {
  const p = String(raw ?? '').toLowerCase().trim()
  return PAID_PLANS.includes(p) ? /** @type {'basic'|'pro'|'business'} */ (p) : null
}

/**
 * @param {'basic'|'pro'|'business'} planType
 * @returns {string|null}
 */
export function getPriceIdForPlan(planType) {
  const id = stripePriceIdMap()[planType]
  return id || null
}

/**
 * @param {string|null|undefined} priceId
 * @returns {'basic'|'pro'|'business'|null}
 */
export function getPlanForStripePriceId(priceId) {
  if (!priceId) return null
  const map = stripePriceIdMap()
  for (const plan of PAID_PLANS) {
    if (map[plan] === priceId) return plan
  }
  return null
}

/** @returns {Stripe|null} */
export function getStripeClient() {
  const key = process.env.STRIPE_SECRET_KEY
  if (!key || !String(key).trim()) return null
  return new Stripe(key)
}

function isUuid(s) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    String(s),
  )
}

/**
 * @param {import('pg').Pool} pool
 * @param {string} email
 * @returns {Promise<string|null>}
 */
export async function findAccountIdByUserEmail(pool, email) {
  const e = String(email ?? '').trim().toLowerCase()
  if (!e) return null
  const { rows } = await pool.query(
    `SELECT account_id::text AS account_id
     FROM users
     WHERE LOWER(TRIM(email)) = $1
     LIMIT 1`,
    [e],
  )
  const id = rows[0]?.account_id
  return id && isUuid(id) ? id : null
}

/**
 * @param {import('stripe').Stripe.Checkout.Session} session
 * @param {import('pg').Pool} pool
 * @returns {Promise<string|null>}
 */
export async function resolveAccountIdFromCheckoutSession(session, pool) {
  const meta = session.metadata && typeof session.metadata === 'object' ? session.metadata : {}
  const fromMeta = meta.account_id || session.client_reference_id
  if (fromMeta && isUuid(String(fromMeta))) return String(fromMeta)

  const email =
    session.customer_details?.email ||
    session.customer_email ||
    (typeof session.customer === 'object' && session.customer && 'email' in session.customer
      ? /** @type {{ email?: string }} */ (session.customer).email
      : null)
  if (email) {
    const byEmail = await findAccountIdByUserEmail(pool, email)
    if (byEmail) return byEmail
  }
  return null
}

/**
 * @param {import('stripe').Stripe.Subscription} subscription
 * @returns {string|null}
 */
export function primaryPriceIdFromSubscription(subscription) {
  const item = subscription.items?.data?.[0]
  const id = item?.price?.id
  return id ? String(id) : null
}

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 * @param {'basic'|'pro'|'business'} planType
 * @param {Date} subscriptionEndsAt
 */
export async function setAccountSubscription(pool, accountId, planType, subscriptionEndsAt) {
  await pool.query(
    `UPDATE accounts
     SET plan_type = $1::text,
         subscription_ends_at = $2::timestamptz
     WHERE id = $3::uuid`,
    [planType, subscriptionEndsAt.toISOString(), accountId],
  )
}

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 */
export async function downgradeAccountToFree(pool, accountId) {
  await pool.query(
    `UPDATE accounts
     SET plan_type = 'free',
         subscription_ends_at = NULL,
         subscription_id = NULL,
         cancel_at_period_end = false
     WHERE id = $1::uuid`,
    [accountId],
  )
}

/**
 * @param {import('pg').Pool} pool
 * @param {string} accountId
 * @param {Date} subscriptionEndsAt
 */
export async function extendAccountSubscriptionEnd(pool, accountId, subscriptionEndsAt) {
  return pool.query(
    `UPDATE accounts
     SET subscription_ends_at = $1::timestamptz
     WHERE id = $2::uuid`,
    [subscriptionEndsAt.toISOString(), accountId],
  )
}

/**
 * Resolve paid plan from Stripe price id, optional metadata hint (must match price map).
 * @param {string|null} priceId
 * @param {string|undefined} metadataPlanHint
 * @returns {'basic'|'pro'|'business'|null}
 */
export function resolvePlanFromPriceAndMetadata(priceId, metadataPlanHint) {
  const fromPrice = getPlanForStripePriceId(priceId)
  const hint = normalizePaidPlanType(metadataPlanHint)
  if (fromPrice && hint && fromPrice !== hint) {
    console.warn('[stripe] plan_type metadata does not match price id; using price map', {
      fromPrice,
      hint,
      priceId,
    })
  }
  if (fromPrice) return fromPrice
  return hint
}

/**
 * Checkout completion: metadata + Stripe subscription period → accounts row.
 * @param {import('stripe').Stripe.Event} event
 * @param {import('pg').Pool} db
 */
export async function handleStripeWebhook(event, db) {
  if (event.type !== 'checkout.session.completed') {
    return
  }

  const stripe = getStripeClient()
  if (!stripe) {
    console.error('[stripe] handleStripeWebhook: STRIPE_SECRET_KEY missing')
    return
  }

  const session = /** @type {import('stripe').Stripe.Checkout.Session} */ (event.data.object)

  const accountId = session.metadata?.account_id
  const planType = session.metadata?.plan_type
  const rawSub = session.subscription
  const subscriptionId =
    typeof rawSub === 'string'
      ? rawSub
      : rawSub && typeof rawSub === 'object' && rawSub != null && 'id' in rawSub
        ? String(/** @type {{ id: string }} */ (rawSub).id)
        : ''

  console.log('🔥 WEBHOOK HIT')
  console.log('accountId:', accountId)
  console.log('planType:', planType)
  console.log('subscriptionId:', subscriptionId)

  if (!accountId || !subscriptionId) {
    console.log('❌ missing data')
    return
  }

  const subscription = await stripe.subscriptions.retrieve(subscriptionId)

  const periodEnd = subscription.current_period_end
  if (typeof periodEnd !== 'number') {
    console.error('❌ checkout.session.completed: missing current_period_end on subscription')
    return
  }
  const currentPeriodEnd = new Date(periodEnd * 1000)

  const result = await db.query(
    `UPDATE accounts
     SET plan_type = $1::text,
         subscription_ends_at = $2::timestamptz,
         updated_at = NOW()
     WHERE id = $3::uuid`,
    [planType || 'pro', currentPeriodEnd, accountId],
  )

  console.log('✅ UPDATED ROWS:', result.rowCount)
}

/**
 * @param {import('stripe').Stripe.Event} event
 * @param {import('pg').Pool} pool
 */
export async function processStripeWebhookEvent(event, pool) {
  const stripe = getStripeClient()
  if (!stripe) {
    console.error('[stripe] STRIPE_SECRET_KEY missing; webhook skipped')
    return
  }

  switch (event.type) {
    case 'checkout.session.completed': {
      await handleStripeWebhook(event, pool)
      break
    }
    case 'invoice.payment_succeeded': {
      const invoice = /** @type {import('stripe').Stripe.Invoice} */ (event.data.object)
      const subId =
        typeof invoice.subscription === 'string'
          ? invoice.subscription
          : invoice.subscription && typeof invoice.subscription === 'object'
            ? invoice.subscription.id
            : null
      if (!subId) {
        console.warn('[stripe] invoice.payment_succeeded: no subscription on invoice', {
          invoice_id: invoice.id,
        })
        break
      }
      const subscription = await stripe.subscriptions.retrieve(subId)
      const meta =
        subscription.metadata && typeof subscription.metadata === 'object'
          ? subscription.metadata
          : {}
      const accountId = meta.account_id && isUuid(String(meta.account_id)) ? String(meta.account_id) : null
      if (!accountId) {
        console.warn('[stripe] invoice.payment_succeeded: missing subscription.metadata.account_id', {
          invoice_id: invoice.id,
        })
        break
      }
      const periodEnd = subscription.current_period_end
      if (typeof periodEnd !== 'number' || !Number.isFinite(periodEnd)) {
        console.warn('[stripe] invoice.payment_succeeded: invalid current_period_end', {
          account_id: accountId,
          invoice_id: invoice.id,
        })
        break
      }
      const computedEnd = new Date(periodEnd * 1000)
      const result = await extendAccountSubscriptionEnd(pool, accountId, computedEnd)
      console.log('[stripe] invoice.payment_succeeded', {
        account_id: accountId,
        invoice_id: invoice.id,
        computed_current_period_end: computedEnd.toISOString(),
        updated_rows: result.rowCount,
      })
      break
    }
    case 'invoice.payment_failed': {
      const invoice = /** @type {import('stripe').Stripe.Invoice} */ (event.data.object)
      console.warn('[stripe] invoice.payment_failed (no immediate downgrade)', {
        invoice_id: invoice.id,
        customer: typeof invoice.customer === 'string' ? invoice.customer : invoice.customer?.id,
        subscription:
          typeof invoice.subscription === 'string'
            ? invoice.subscription
            : invoice.subscription && typeof invoice.subscription === 'object'
              ? invoice.subscription.id
              : null,
        attempt_count: invoice.attempt_count,
      })
      break
    }
    default:
      break
  }
}

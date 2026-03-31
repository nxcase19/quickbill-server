import { Router } from 'express'
import bcrypt from 'bcrypt'
import { pool } from '../db.js'
import { safeQuery } from '../utils/tenantQuery.js'
import { signAuthToken, verifyAuthToken } from '../utils/authToken.js'
import {
  fetchAccountBillingRow,
  getEffectivePlan,
  isTrialActive,
} from '../utils/planService.js'

const router = Router()

const SALT_ROUNDS = 10

/** Placeholder until user fills company_settings (not shown as real company name in PDF if empty snapshot). */
const REGISTER_PLACEHOLDER_NAME = '-'

function mapUserRow(row) {
  if (!row) return null
  return {
    id: row.id,
    email: row.email != null ? String(row.email) : '',
    account_id: row.account_id,
    company_id: row.company_id,
    role: row.role != null ? String(row.role) : 'owner',
    created_at: row.created_at ?? null,
  }
}

function mapAccountRow(row) {
  if (!row) return null
  return {
    id: row.id,
    plan_type: row.plan_type != null ? String(row.plan_type) : 'free',
    trial_started_at: row.trial_started_at ?? null,
    trial_ends_at: row.trial_ends_at ?? null,
    subscription_ends_at: row.subscription_ends_at ?? null,
    created_at: row.created_at ?? null,
  }
}

/**
 * UI plan: trial | free | basic | pro — from DB only (never JWT).
 * Aligns with getEffectivePlan (paid > trial > free).
 */
function mapAccountRowWithPlan(row) {
  if (!row) return null
  const base = mapAccountRow(row)
  if (!base) return null
  const eff = getEffectivePlan(row)

  let plan = 'free'
  if (eff === 'basic') plan = 'basic'
  else if (eff === 'pro' || eff === 'business') plan = 'pro'
  else if (eff === 'trial') plan = 'trial'
  else plan = 'free'
  return { ...base, plan }
}

router.get('/me', async (req, res) => {
  const authHeader = req.headers.authorization
  const hasBearer =
    typeof authHeader === 'string' && authHeader.startsWith('Bearer ')
  if (!hasBearer) {
    return res.status(401).json({ success: false, error: 'Unauthorized' })
  }
  const token = authHeader.split(' ')[1]
  let decoded
  try {
    decoded = verifyAuthToken(token)
  } catch {
    return res.status(401).json({ success: false, error: 'Invalid token' })
  }
  const accountId = decoded?.account_id
  if (!accountId) {
    return res.status(401).json({ success: false, error: 'Invalid token' })
  }
  try {
    const row = await fetchAccountBillingRow(pool, accountId)
    if (!row) {
      return res.status(404).json({ success: false, error: 'Account not found' })
    }
    const account = mapAccountRowWithPlan(row)
    return res.json({
      success: true,
      data: {
        ...account,
        is_trial_active: isTrialActive(row),
        user_id: decoded.user_id,
        email: decoded.email != null ? String(decoded.email) : '',
      },
    })
  } catch (err) {
    console.error('GET /auth/me error:', err)
    return res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

router.post('/register', async (req, res) => {
  console.log('REGISTER HIT:', req.body)

  const email =
    req.body.email != null ? String(req.body.email).trim().toLowerCase() : ''
  const password = req.body.password != null ? String(req.body.password) : ''

  if (!email) {
    return res.status(400).json({ success: false, error: 'email is required' })
  }
  if (!password || password.length < 6) {
    return res
      .status(400)
      .json({ success: false, error: 'password is required (min 6 characters)' })
  }

  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS)

    const { rows: accRows } = await client.query(
      `INSERT INTO accounts (name, plan_type, trial_started_at, trial_ends_at)
       VALUES ($1, 'free', NOW(), NOW() + INTERVAL '7 days')
       RETURNING id`,
      [REGISTER_PLACEHOLDER_NAME],
    )
    const accountId = accRows[0].id

    const { rows: compRows } = await client.query(
      `INSERT INTO companies (account_id, name) VALUES ($1, $2) RETURNING id`,
      [accountId, REGISTER_PLACEHOLDER_NAME],
    )
    const companyId = compRows[0].id

    const { rows: userRows } = await client.query(
      `INSERT INTO users (account_id, company_id, email, password_hash)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, account_id, company_id`,
      [accountId, companyId, email, passwordHash],
    )
    const userRow = userRows[0]

    const { rows: accountRows } = await client.query(
      `SELECT id, plan_type, trial_started_at, trial_ends_at, subscription_ends_at
       FROM accounts
       WHERE id = $1`,
      [accountId],
    )

    await client.query('COMMIT')

    const account = mapAccountRowWithPlan(accountRows[0])
    const user = mapUserRow({ ...userRow, role: 'owner' })
    const token = signAuthToken({
      userId: userRow.id,
      companyId,
      accountId,
      email: userRow.email,
      role: 'owner',
    })

    return res.status(201).json({
      success: true,
      data: {
        token,
        user,
        account,
      },
    })
  } catch (err) {
    await client.query('ROLLBACK')
    if (err.code === '23505') {
      return res.status(409).json({ success: false, error: 'Email already registered' })
    }
    console.error('REGISTER ERROR:', err)
    return res.status(500).json({ success: false, error: 'Internal server error' })
  } finally {
    client.release()
  }
})

router.post('/login', async (req, res) => {
  const email =
    req.body.email != null ? String(req.body.email).trim().toLowerCase() : ''
  const password = req.body.password != null ? String(req.body.password) : ''

  if (!email || !password) {
    return res.status(400).json({ success: false, error: 'email and password are required' })
  }

  try {
    const { rows } = await safeQuery(
      pool,
      `SELECT id, account_id, company_id, email, password_hash
       FROM users
       WHERE email = $1`,
      [email],
      { skipAssert: true },
    )
    if (rows.length === 0) {
      return res.status(401).json({ success: false, error: 'Invalid email or password' })
    }
    const row = rows[0]
    const ok = await bcrypt.compare(password, row.password_hash)
    if (!ok) {
      return res.status(401).json({ success: false, error: 'Invalid email or password' })
    }

    try {
      await pool.query(`UPDATE users SET last_login_at = NOW() WHERE id = $1`, [row.id])
    } catch (e) {
      if (e && e.code === '42703') {
        /* last_login_at added in 036_auth_system_foundation.sql */
      } else {
        throw e
      }
    }

    const { rows: accountRows } = await safeQuery(
      pool,
      `SELECT id, plan_type, trial_started_at, trial_ends_at, subscription_ends_at
       FROM accounts
       WHERE id = $1`,
      [row.account_id],
      { skipAssert: true },
    )

    const token = signAuthToken({
      userId: row.id,
      companyId: row.company_id,
      accountId: row.account_id,
      email: row.email,
      role: 'owner',
    })

    return res.json({
      success: true,
      data: {
        token,
        user: mapUserRow({ ...row, role: 'owner' }),
        account: mapAccountRowWithPlan(accountRows[0]),
      },
    })
  } catch (err) {
    console.error('POST /login error:', err)
    return res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

export default router

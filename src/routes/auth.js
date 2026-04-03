import { Router } from 'express'
import bcrypt from 'bcrypt'
import { OAuth2Client } from 'google-auth-library'
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

/**
 * @param {import('pg').PoolClient} client
 * @param {string} email normalized
 * @param {string|null} passwordHash bcrypt hash or null for Google-only
 * @param {string|null} googleSub Google `sub` or null
 * @param {{ newAccountPlan?: 'free' | 'trial' }} [opts] Register uses `free` (default). New Google user uses `trial`.
 */
async function insertNewTenantWithUser(client, email, passwordHash, googleSub, opts = {}) {
  const planType = opts.newAccountPlan === 'trial' ? 'trial' : 'free'
  const { rows: accRows } = await client.query(
    `INSERT INTO accounts (name, plan_type, trial_started_at, trial_ends_at)
     VALUES ($1, $2::text, NOW(), NOW() + INTERVAL '7 days')
     RETURNING id`,
    [REGISTER_PLACEHOLDER_NAME, planType],
  )
  const accountId = accRows[0].id

  const { rows: compRows } = await client.query(
    `INSERT INTO companies (account_id, name) VALUES ($1, $2) RETURNING id`,
    [accountId, REGISTER_PLACEHOLDER_NAME],
  )
  const companyId = compRows[0].id

  const { rows: userRows } = await client.query(
    `INSERT INTO users (account_id, company_id, email, password_hash, google_sub)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, email, account_id, company_id`,
    [accountId, companyId, email, passwordHash, googleSub],
  )
  const userRow = userRows[0]

  const { rows: accountRows } = await client.query(
    `SELECT id, plan_type, trial_started_at, trial_ends_at, subscription_ends_at
     FROM accounts
     WHERE id = $1`,
    [accountId],
  )

  return { userRow, companyId, accountRows }
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
    const { rows: userRows } = await safeQuery(
      pool,
      `SELECT id, email FROM users WHERE id = $1`,
      [decoded.user_id],
      { skipAssert: true },
    )
    const dbUser = userRows[0] ?? null
    if (dbUser) {
      console.log('AUTH USER:', dbUser)
    }
    const account = mapAccountRowWithPlan(row)
    return res.json({
      success: true,
      data: {
        ...account,
        is_trial_active: isTrialActive(row),
        user_id: decoded.user_id,
        email: decoded.email != null ? String(decoded.email) : '',
        user: dbUser,
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

    const { userRow, companyId, accountRows } = await insertNewTenantWithUser(
      client,
      email,
      passwordHash,
      null,
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
    if (row.password_hash == null || String(row.password_hash).trim() === '') {
      return res.status(401).json({
        success: false,
        error: 'บัญชีนี้เข้าสู่ระบบด้วย Google — กรุณาใช้ปุ่มเข้าสู่ระบบด้วย Google',
      })
    }
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

router.post('/google', async (req, res) => {
  try {
    console.log('Google login request received')

    const idTokenRaw = req.body?.token ?? req.body?.credential
    const idToken = idTokenRaw != null ? String(idTokenRaw).trim() : ''
    if (!idToken) {
      return res.status(400).json({ success: false, error: 'token is required' })
    }

    const googleClientId = String(process.env.GOOGLE_CLIENT_ID || '').trim()
    if (!googleClientId) {
      console.error(
        'GOOGLE_CLIENT_ID is missing — add it in Railway / server environment (same value as Google OAuth Web client ID)',
      )
      return res.status(503).json({
        success: false,
        error:
          'Google sign-in is not configured (GOOGLE_CLIENT_ID missing on server). Set GOOGLE_CLIENT_ID in deployment env.',
      })
    }

    const oAuth = new OAuth2Client(googleClientId)
    let payload
    try {
      const ticket = await oAuth.verifyIdToken({
        idToken,
        audience: googleClientId,
      })
      payload = ticket.getPayload()
    } catch (verifyErr) {
      console.error('POST /auth/google verify:', verifyErr)
      return res.status(401).json({ success: false, error: 'Invalid Google token' })
    }

    if (!payload) {
      return res.status(401).json({ success: false, error: 'Invalid Google token' })
    }

    const email =
      payload.email != null ? String(payload.email).trim().toLowerCase() : ''
    const sub = payload.sub != null ? String(payload.sub).trim() : ''
    const name =
      payload.name != null ? String(payload.name).trim() : ''
    if (!email || !sub) {
      return res.status(401).json({ success: false, error: 'Invalid Google profile' })
    }
    if (payload.email_verified === false) {
      return res.status(401).json({ success: false, error: 'Google email is not verified' })
    }

    console.log('Google user verified:', email, name || '')

    // STEP 1: existing Google link
    const { rows: bySubRows } = await safeQuery(
      pool,
      `SELECT id, account_id, company_id, email, password_hash, google_sub
       FROM users
       WHERE google_sub = $1`,
      [sub],
      { skipAssert: true },
    )
    let row = bySubRows[0] ?? null

    // STEP 2: same email (e.g. registered with password first) — link google_sub, never change plan_type
    if (!row) {
      const { rows: byEmailRows } = await safeQuery(
        pool,
        `SELECT id, account_id, company_id, email, password_hash, google_sub
         FROM users
         WHERE LOWER(TRIM(email)) = $1`,
        [email],
        { skipAssert: true },
      )
      row = byEmailRows[0] ?? null
    }

    if (row) {
      const existingSub = row.google_sub != null ? String(row.google_sub).trim() : ''
      if (existingSub !== '' && existingSub !== sub) {
        return res.status(409).json({
          success: false,
          error: 'อีเมลนี้ผูกกับ Google อีกบัญชีแล้ว',
        })
      }
      if (existingSub === '') {
        await pool.query(
          `UPDATE users SET google_sub = $1 WHERE LOWER(TRIM(email)) = $2`,
          [sub, email],
        )
      }
      try {
        await pool.query(`UPDATE users SET last_login_at = NOW() WHERE id = $1`, [row.id])
      } catch (e) {
        if (e && e.code !== '42703') {
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

      console.log('LOGIN USER PLAN:', accountRows[0]?.plan_type)

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
    }

    const dbClient = await pool.connect()
    try {
      await dbClient.query('BEGIN')
      console.log('NEW USER → START TRIAL 7 DAYS')
      const { userRow, companyId, accountRows } = await insertNewTenantWithUser(
        dbClient,
        email,
        null,
        sub,
        { newAccountPlan: 'trial' },
      )
      await dbClient.query('COMMIT')

      console.log('LOGIN USER PLAN:', accountRows[0]?.plan_type)

      const token = signAuthToken({
        userId: userRow.id,
        companyId,
        accountId: userRow.account_id,
        email: userRow.email,
        role: 'owner',
      })

      return res.status(201).json({
        success: true,
        data: {
          token,
          user: mapUserRow({ ...userRow, role: 'owner' }),
          account: mapAccountRowWithPlan(accountRows[0]),
        },
      })
    } catch (signupErr) {
      try {
        await dbClient.query('ROLLBACK')
      } catch {
        /* ignore */
      }
      if (signupErr.code === '23505') {
        return res.status(409).json({ success: false, error: 'Email already registered' })
      }
      throw signupErr
    } finally {
      dbClient.release()
    }
  } catch (err) {
    console.error('GOOGLE LOGIN ERROR:', err)
    if (res.headersSent) {
      return
    }
    if (err && err.code === '42703') {
      return res.status(500).json({
        success: false,
        error:
          'Database missing Google columns (run migration 041_users_google_oauth.sql on the database)',
      })
    }
    return res.status(500).json({
      success: false,
      error: 'Google auth failed',
    })
  }
})

export default router

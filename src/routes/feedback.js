import nodemailer from 'nodemailer'
import { Router } from 'express'
import { pool } from '../db.js'

const router = Router()

/** In-memory rate limit per user (or account fallback). */
const feedbackRateLimit = new Map()

const FEEDBACK_PAGE_MAX = 2000

let smtpTransporter = null
let smtpTransporterChecked = false

function getFeedbackMailer() {
  if (smtpTransporterChecked) return smtpTransporter
  smtpTransporterChecked = true
  const host = process.env.SMTP_HOST
  const user = process.env.SMTP_USER
  const pass = process.env.SMTP_PASS
  if (!host || !user || !pass) {
    smtpTransporter = null
    return null
  }
  try {
    const port = Number(process.env.SMTP_PORT || 465)
    smtpTransporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    })
  } catch {
    smtpTransporter = null
  }
  return smtpTransporter
}

router.post('/', async (req, res) => {
  try {
    const typeRaw = req.body?.type
    const messageRaw = req.body?.message
    const pageRaw = req.body?.page

    const typeSafe = String(typeRaw ?? '').trim()
    const messageSafe = String(messageRaw ?? '').trim()
    const pageSafe = String(pageRaw ?? '').trim()

    if (!['bug', 'feature'].includes(typeSafe)) {
      return res.status(400).json({ error: 'invalid type' })
    }

    if (!messageSafe) {
      return res.status(400).json({ error: 'message required' })
    }

    if (messageSafe.length > 1000) {
      return res.status(400).json({ error: 'message too long' })
    }

    const pageForDb =
      pageSafe.length > 0 ? pageSafe.slice(0, FEEDBACK_PAGE_MAX) : null

    const userId = req.user?.user_id || null
    const accountId = req.user?.account_id || null

    if (!accountId) {
      return res.status(401).json({ error: 'unauthorized' })
    }

    const rateKey = String(req.user?.user_id ?? accountId ?? '')
    const now = Date.now()
    const windowMs = 60 * 1000
    const maxReq = 10

    let entry = feedbackRateLimit.get(rateKey)
    if (!entry) {
      entry = { count: 0, start: now }
    }

    if (now - entry.start > windowMs) {
      entry.count = 0
      entry.start = now
    }

    entry.count += 1
    feedbackRateLimit.set(rateKey, entry)

    if (entry.count > maxReq) {
      return res.status(429).json({ error: 'too many requests' })
    }

    console.log('[feedback]', {
      type: typeSafe,
      user: req.user?.user_id,
      page: pageForDb || pageSafe || '',
    })

    console.log('[feedback-debug]', {
      user: req.user,
    })

    try {
      await pool.query(
        `INSERT INTO feedbacks (account_id, user_id, type, message, page, status)
         VALUES ($1::text, $2::text, $3::text, $4::text, $5::text, 'open')`,
        [
          String(accountId),
          userId != null && userId !== '' ? String(userId) : null,
          typeSafe,
          messageSafe,
          pageForDb,
        ],
      )
    } catch (err) {
      console.error('[feedback-insert-error]', err.message)
      return res.status(500).json({ error: 'failed to save feedback' })
    }

    res.json({ success: true })

    setImmediate(() => {
      try {
        const transporter = getFeedbackMailer()
        if (!transporter) return

        const fromAddr = process.env.SMTP_USER
        const subject = `[QuickBill] New Feedback (${typeSafe})`
        const text =
          `New feedback received\n\n` +
          `Type: ${typeSafe}\n` +
          `User: ${req.user?.user_id ?? ''}\n` +
          `Account: ${req.user?.account_id ?? ''}\n` +
          `Page: ${pageSafe}\n\n` +
          `Message:\n${messageSafe}\n`

        transporter
          .sendMail({
            from: `"QuickBill" <${fromAddr}>`,
            to: 'support@quickbill.dev',
            subject,
            text,
          })
          .catch(() => {})
      } catch {
        /* ignore */
      }
    })
  } catch (e) {
    console.error('[feedback]', String(e?.message || e).slice(0, 200))
    res.status(500).json({
      success: false,
      error: 'Failed to save feedback',
      message: 'Please try again later',
    })
  }
})

export default router

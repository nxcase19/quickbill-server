import { Router } from 'express'
import { pool } from '../db.js'
import { requireAccountId, safeQuery } from '../utils/tenantQuery.js'
import { assertDocumentNotLocked } from '../utils/lockGuards.js'

const router = Router()

/**
 * POST /api/orders/:orderId/cancel
 * Cancels the sales batch: all documents with same order_id (no deletes).
 */
router.post('/:orderId/cancel', async (req, res) => {
  let accountId
  try {
    accountId = requireAccountId(req)
  } catch {
    return res.status(401).json({ success: false, error: 'Missing account_id' })
  }

  const orderId =
    req.params.orderId != null && String(req.params.orderId).trim() !== ''
      ? String(req.params.orderId).trim()
      : ''

  if (!orderId) {
    return res.status(400).json({ success: false, error: 'order_id is required' })
  }

  const client = await pool.connect()
  try {
    await client.query('BEGIN')

    const { rows: existsRows } = await safeQuery(
      client,
      `SELECT 1 FROM documents d
       WHERE d.order_id = $1 AND d.account_id = $2::uuid
       LIMIT 1`,
      [orderId, accountId],
    )
    if (existsRows.length === 0) {
      await client.query('ROLLBACK')
      return res.status(404).json({ success: false, error: 'Not found' })
    }

    const { rows: docCancelled } = await safeQuery(
      client,
      `SELECT id, status, is_locked FROM documents d
       WHERE d.order_id = $1 AND d.account_id = $2::uuid
         AND (
           d.status = 'cancelled'
           OR d.is_locked = TRUE
         )
       LIMIT 1`,
      [orderId, accountId],
    )
    if (docCancelled.length > 0) {
      const doc0 = docCancelled[0]
      if (String(doc0.status || '').toLowerCase() === 'cancelled') {
        await client.query('ROLLBACK')
        console.log('CANCEL BLOCKED ACTION: documents already cancelled', {
          orderId,
          accountId,
        })
        return res.status(400).json({ success: false, error: 'ออเดอร์ถูกยกเลิกแล้ว' })
      }
      try {
        assertDocumentNotLocked(doc0)
      } catch (err) {
        await client.query('ROLLBACK')
        console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, id: doc0.id })
        return res.status(400).json({ success: false, error: err.message })
      }
    }

    console.log('DOCUMENT STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      orderId,
      status: docCancelled[0]?.status ?? null,
      is_locked: docCancelled[0]?.is_locked ?? false,
    })

    const { rows: updatedDocs } = await safeQuery(
      client,
      `UPDATE documents d
       SET status = 'cancelled',
           is_locked = TRUE
       WHERE d.order_id = $1 AND d.account_id = $2::uuid
       RETURNING id`,
      [orderId, accountId],
    )

    const affectedDocs = updatedDocs.length
    console.log('CANCEL ORDER:', {
      orderId,
      accountId,
      affectedDocs,
    })
    console.log('DOCUMENT LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      orderId,
      is_locked: true,
      affectedDocs,
    })

    await client.query('COMMIT')
    return res.json({ success: true, data: { affected_documents: affectedDocs } })
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ success: false, error: 'Missing account_id' })
    }
    console.error('POST /orders/:orderId/cancel error:', err)
    return res.status(500).json({ success: false, error: err.message })
  } finally {
    client.release()
  }
})

export default router

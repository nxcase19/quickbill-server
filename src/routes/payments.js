import { Router } from 'express'
import { pool } from '../db.js'
import { buildTenantWhereClause } from '../utils/tenant.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import { requireAccountId, safeQuery } from '../utils/tenantQuery.js'
import { assertSalesNotCancelled } from '../utils/cancelGuards.js'
import { assertDocumentNotLocked } from '../utils/lockGuards.js'

export const paymentsRouter = Router()

paymentsRouter.post('/group', async (req, res) => {
  let accountId
  try {
    accountId = requireAccountId(req)
  } catch {
    return res.status(401).json({ success: false, error: 'Missing account_id' })
  }
  logTenantAccess('POST /api/payments/group', req, { order_id: req.body?.order_id })

  const { order_id, amount } = req.body

  if (!order_id) {
    return res.status(400).json({ success: false, error: 'order_id is required' })
  }

  const client = await pool.connect()

  try {
    await client.query('BEGIN')

    const tw = buildTenantWhereClause(req, 'd', 2)
    let docSql = `SELECT id, total, paid_amount, doc_type, status, is_locked
       FROM documents d
       WHERE d.order_id = $1 AND ${tw.clause}`
    const docParams = [order_id, tw.param]
    const { rows: docs } = await safeQuery(client, docSql, docParams)

    if (docs.length === 0) {
      await client.query('ROLLBACK')
      return res.status(404).json({ success: false, error: 'Documents not found' })
    }

    for (const d of docs) {
      try {
        assertSalesNotCancelled(d)
        assertDocumentNotLocked(d)
      } catch (err) {
        await client.query('ROLLBACK')
        console.log('LOCK BLOCKED ACTION:', {
          route: req.originalUrl,
          id: d.id,
        })
        return res.status(400).json({ success: false, error: err.message })
      }
    }

    const totalAmount = docs.reduce(
      (sum, d) => sum + Number(d.total || 0),
      0,
    )

    await safeQuery(
      client,
      `INSERT INTO payments (account_id, amount, order_id)
         VALUES ($1, $2, $3)`,
      [accountId, amount || totalAmount, order_id],
    )

    let updSql = `UPDATE documents d
       SET
         paid_amount = total,
         status = 'paid',
         is_locked = TRUE
       WHERE d.order_id = $1 AND ${tw.clause}`
    const updParams = [order_id, tw.param]
    await safeQuery(client, updSql, updParams)
    console.log('DOCUMENT LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      order_id,
      is_locked: true,
    })
    console.log('GROUP PAYMENT SUCCESS order_id:', order_id)

    await client.query('COMMIT')

    return res.json({
      success: true,
      data: {
        order_id,
        total: totalAmount,
      },
    })
  } catch (err) {
    await client.query('ROLLBACK')
    console.error('GROUP PAYMENT ERROR:', err)
    return res.status(500).json({ success: false, error: err.message })
  } finally {
    client.release()
  }
})

paymentsRouter.post('/', async (req, res) => {
  let accountId
  try {
    accountId = requireAccountId(req)
  } catch {
    return res.status(401).json({ success: false, error: 'Missing account_id' })
  }
  logTenantAccess('POST /api/payments/', req, {
    document_id: req.body?.document_id ?? req.body?.documentId,
  })

  const documentId =
    req.body.document_id != null
      ? req.body.document_id
      : req.body.documentId

  if (documentId == null || documentId === '') {
    return res.status(400).json({ success: false, error: 'document_id is required' })
  }

  const docId = Number(documentId)
  if (!Number.isFinite(docId)) {
    return res.status(400).json({ success: false, error: 'Invalid document_id' })
  }

  try {
    const tw = buildTenantWhereClause(req, 'd', 2)
    let selSql = `SELECT id, order_id, status, is_locked FROM documents d WHERE d.id = $1 AND ${tw.clause}`
    const selParams = [docId, tw.param]
    const { rows } = await safeQuery(pool, selSql, selParams)

    const orderId = rows[0]?.order_id
    const row0 = rows[0]
    try {
      assertSalesNotCancelled(row0)
      assertDocumentNotLocked(row0)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', {
        route: req.originalUrl,
        id: docId,
      })
      return res.status(400).json({ success: false, error: err.message })
    }
    console.log('DOCUMENT STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      id: docId,
      status: row0?.status ?? null,
      is_locked: row0?.is_locked ?? null,
    })

    if (orderId == null || orderId === '') {
      return res.status(404).json({ success: false, error: 'Not found' })
    }

    let updSql = `UPDATE documents d
       SET paid_amount = total, status = 'paid', is_locked = TRUE
       WHERE d.order_id = $1 AND ${tw.clause}`
    const updParams = [orderId, tw.param]
    await safeQuery(pool, updSql, updParams)
    console.log('DOCUMENT LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      order_id: orderId,
      is_locked: true,
    })

    return res.json({ success: true, data: { order_id: orderId } })
  } catch (err) {
    console.error('payments POST error:', err)
    return res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

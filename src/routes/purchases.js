import fs from 'node:fs'
import path from 'node:path'
import { Router } from 'express'
import { pool } from '../db.js'
import { buildTenantWhereClause } from '../utils/tenant.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import { requireAccountId, safeQuery } from '../utils/tenantQuery.js'
import { uploadPurchaseInvoice } from '../middleware/upload.js'
import { assertCanUseTaxPurchase } from '../middleware/planGuards.js'

const router = Router()
router.use(assertCanUseTaxPurchase)

const PO_CANCEL_BLOCKED_EN = 'Cannot cancel invoice generated from PO'

function purchaseInvoiceIsFromPo(row) {
  if (!row) return false
  if (String(row.source_type || '').toLowerCase() === 'po') return true
  return String(row.source || '').toUpperCase() === 'PO'
}

function unlinkPurchaseImage(imageUrl) {
  if (!imageUrl || typeof imageUrl !== 'string') return
  const rel = imageUrl.replace(/^\/+/, '')
  if (!rel.startsWith('uploads/purchases/')) return
  const abs = path.join(process.cwd(), rel)
  fs.unlink(abs, () => {})
}

function handlePurchaseImageUpload(req, res, next) {
  uploadPurchaseInvoice.single('image')(req, res, (err) => {
    if (err) {
      return res.status(400).json({ error: err.message || 'Upload failed' })
    }
    next()
  })
}

// GET list (optional ?from=&to=; ?include_cancelled=true to list cancelled rows)
router.get('/', async (req, res) => {
  try {
    logTenantAccess('GET /api/purchases', req)
    const tw = buildTenantWhereClause(req, '', 1)
    const { from, to } = req.query
    const includeCancelled =
      String(req.query.include_cancelled || '').toLowerCase() === 'true'
    let sql = `SELECT * FROM purchase_invoices WHERE ${tw.clause}`
    const params = [tw.param]
    if (from && to) {
      sql += ` AND doc_date >= $${params.length + 1} AND doc_date <= $${params.length + 2}`
      params.push(String(from).slice(0, 10), String(to).slice(0, 10))
    } else if (from) {
      sql += ` AND doc_date >= $${params.length + 1}`
      params.push(String(from).slice(0, 10))
    } else if (to) {
      sql += ` AND doc_date <= $${params.length + 1}`
      params.push(String(to).slice(0, 10))
    }
    if (!includeCancelled) {
      sql += ` AND (COALESCE(status, 'active') = 'active')`
    }
    sql += ` ORDER BY doc_date DESC NULLS LAST, id DESC`
    const { rows } = await safeQuery(pool, sql, params)

    res.json(rows)
  } catch (err) {
    console.error('GET purchases error:', err)
    res.status(500).json({ error: err.message })
  }
})

// CREATE
router.post('/', async (req, res) => {
  try {
    const accountId = req.user?.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id in token' })
    }

    logTenantAccess('POST /api/purchases', req)

    const {
      supplier_name,
      tax_id,
      doc_no,
      doc_date,
      subtotal,
      vat_amount,
      total,
      note,
      image_url,
    } = req.body

    const { rows } = await safeQuery(
      pool,
      `INSERT INTO purchase_invoices
      (account_id, supplier_name, tax_id, doc_no, doc_date, subtotal, vat_amount, total, note, image_url)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
      RETURNING *`,
      [
        accountId,
        supplier_name,
        tax_id,
        doc_no,
        doc_date,
        subtotal,
        vat_amount,
        total,
        note,
        image_url != null && String(image_url).trim() !== ''
          ? String(image_url).trim()
          : null,
      ],
    )

    res.json(rows[0])
  } catch (err) {
    console.error('CREATE purchase error:', err)
    res.status(500).json({ error: err.message })
  }
})

// POST image for existing row (must be before PUT /:id pattern-wise for clarity)
router.post('/:id/image', handlePurchaseImageUpload, async (req, res) => {
  try {
    const id = Number(req.params.id)
    if (!Number.isFinite(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' })
    }

    logTenantAccess('POST /api/purchases/:id/image', req, { id })

    const tw = buildTenantWhereClause(req, '', 2)
    const { rows: existing } = await safeQuery(
      pool,
      `SELECT image_url FROM purchase_invoices WHERE id = $1 AND ${tw.clause}
         AND (COALESCE(status, 'active') = 'active')`,
      [id, tw.param],
    )

    if (existing.length === 0) {
      unlinkPurchaseImage(`/uploads/purchases/${req.file.filename}`)
      return res.status(404).json({ error: 'Not found' })
    }

    if (existing[0].image_url) {
      unlinkPurchaseImage(existing[0].image_url)
    }

    const relUrl = `/uploads/purchases/${req.file.filename}`

    const { rows } = await safeQuery(
      pool,
      `UPDATE purchase_invoices SET image_url = $3
       WHERE id = $1 AND ${tw.clause}
         AND (COALESCE(status, 'active') = 'active')
       RETURNING *`,
      [id, tw.param, relUrl],
    )

    res.json(rows[0])
  } catch (err) {
    console.error('POST purchase image error:', err)
    res.status(500).json({ error: err.message })
  }
})

// Soft cancel (no row delete). Idempotent if already cancelled.
router.put('/:id/cancel', async (req, res) => {
  try {
    const accountId = requireAccountId(req)

    const id = Number(req.params.id)
    if (!Number.isFinite(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('PUT /api/purchase-invoices/:id/cancel', req, { id })

    const { rows: prev } = await safeQuery(
      pool,
      `SELECT source_type, status, source
       FROM purchase_invoices WHERE id = $1 AND account_id = $2::uuid`,
      [id, accountId],
    )

    if (prev.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }

    const row = prev[0]
    if (String(row.status || '').toLowerCase() === 'cancelled') {
      return res.json({ success: true, status: 'cancelled', idempotent: true })
    }

    if (purchaseInvoiceIsFromPo(row)) {
      return res.status(400).json({ error: PO_CANCEL_BLOCKED_EN })
    }

    const result = await safeQuery(
      pool,
      `UPDATE purchase_invoices
       SET status = 'cancelled'
       WHERE id = $1 AND account_id = $2::uuid
         AND (COALESCE(status, 'active') = 'active')
       RETURNING id, status`,
      [id, accountId],
    )

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }

    res.json({
      success: true,
      status: result.rows[0].status,
    })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('PUT purchase cancel error:', err)
    res.status(500).json({ error: err.message })
  }
})

// UPDATE — tenant via buildTenantWhereClause (account_id)
router.put('/:id', async (req, res) => {
  try {
    requireAccountId(req)

    const id = Number(req.params.id)
    if (!Number.isFinite(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('PUT /api/purchases/:id', req, { id })

    const {
      supplier_name,
      tax_id,
      doc_no,
      doc_date,
      subtotal,
      vat_amount,
      total,
      note,
      image_url,
    } = req.body

    const baseParams = [
      supplier_name,
      tax_id ?? '',
      doc_no ?? '',
      doc_date ?? null,
      subtotal ?? 0,
      vat_amount ?? 0,
      total ?? 0,
      note ?? '',
    ]

    let sql = `
      UPDATE purchase_invoices
      SET
        supplier_name = $1,
        tax_id = $2,
        doc_no = $3,
        doc_date = $4,
        subtotal = $5,
        vat_amount = $6,
        total = $7,
        note = $8`

    const params = [...baseParams]

    if (image_url !== undefined) {
      const img =
        image_url != null && String(image_url).trim() !== ''
          ? String(image_url).trim()
          : null
      sql += `,\n        image_url = $9`
      params.push(img)
    }

    const idParam = params.length + 1
    const tw = buildTenantWhereClause(req, '', idParam + 1)

    sql += `
      WHERE id = $${idParam}
        AND ${tw.clause}
        AND (COALESCE(status, 'active') = 'active')
      RETURNING *`

    params.push(id, tw.param)

    const result = await safeQuery(pool, sql, params)

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }

    res.json(result.rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('UPDATE purchase error:', err)
    res.status(500).json({ error: err.message })
  }
})

// Legacy: same as PUT cancel (soft cancel only; never DELETE FROM)
router.delete('/:id', async (req, res) => {
  try {
    const accountId = requireAccountId(req)

    const id = Number(req.params.id)
    if (!Number.isFinite(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('DELETE /api/purchases/:id (cancel)', req, { id })

    const { rows: prev } = await safeQuery(
      pool,
      `SELECT source_type, status, source
       FROM purchase_invoices WHERE id = $1 AND account_id = $2::uuid`,
      [id, accountId],
    )

    if (prev.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }

    const row = prev[0]
    if (String(row.status || '').toLowerCase() === 'cancelled') {
      return res.json({ success: true, status: 'cancelled', idempotent: true })
    }

    if (purchaseInvoiceIsFromPo(row)) {
      return res.status(400).json({ error: PO_CANCEL_BLOCKED_EN })
    }

    const result = await safeQuery(
      pool,
      `UPDATE purchase_invoices
       SET status = 'cancelled'
       WHERE id = $1 AND account_id = $2::uuid
         AND (COALESCE(status, 'active') = 'active')
       RETURNING id`,
      [id, accountId],
    )

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }

    res.json({ success: true, status: 'cancelled' })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('Cancel purchase error:', err)
    res.status(500).json({ error: err.message })
  }
})

export default router

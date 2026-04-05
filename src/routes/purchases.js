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

/**
 * Whitelist of purchase_invoices columns allowed on INSERT (POST create).
 * IMPORTANT:
 * This list must match the DB schema for this deployment.
 * Do NOT add frontend-only fields (e.g. image_url) here without a migration.
 * If the table schema changes, update this array first, then deploy.
 */
const PURCHASE_ALLOWED_COLUMNS = [
  'supplier_name',
  'tax_id',
  'doc_no',
  'doc_date',
  'subtotal',
  'vat_amount',
  'total',
  'note',
  'status',
]

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

function isPgUndefinedColumn(err) {
  return Boolean(err && String(err.code) === '42703')
}

/**
 * IMPORTANT:
 * This INSERT path is schema-safe.
 * Only fields listed in PURCHASE_ALLOWED_COLUMNS are taken from the request body.
 * Do NOT pass req.body (or spread body) directly into SQL.
 * Unknown / future JSON fields are ignored and cannot cause 42703 from extra columns.
 */
function buildPurchaseInvoiceInsertRow(accountId, body) {
  const b = body && typeof body === 'object' ? body : {}
  const data = {}

  for (const key of PURCHASE_ALLOWED_COLUMNS) {
    if (b[key] !== undefined) {
      data[key] = b[key]
    }
  }

  if (data.doc_no === undefined && b.document_no !== undefined) {
    data.doc_no = b.document_no
  }

  if (data.doc_no != null && String(data.doc_no).trim() === '') {
    data.doc_no = null
  } else if (data.doc_no != null && typeof data.doc_no === 'string') {
    data.doc_no = String(data.doc_no).trim()
  }

  // IMPORTANT:
  // Normalize numeric and string inputs to prevent invalid data (NaN, string numbers)
  // Do not trust frontend values for financial fields
  // Total will be auto-corrected from subtotal + vat_amount if inconsistent

  if (data.subtotal !== undefined) {
    const n = Number(data.subtotal)
    data.subtotal = Number.isNaN(n) ? 0 : n
  }

  if (data.vat_amount !== undefined) {
    const n = Number(data.vat_amount)
    data.vat_amount = Number.isNaN(n) ? 0 : n
  }

  if (data.total !== undefined) {
    const n = Number(data.total)
    data.total = Number.isNaN(n) ? 0 : n
  }

  if (data.subtotal != null && data.vat_amount != null) {
    const expectedTotal = data.subtotal + data.vat_amount
    if (
      data.total == null ||
      Math.abs(Number(data.total) - expectedTotal) > 0.01
    ) {
      data.total = expectedTotal
    }
  }

  if (data.supplier_name !== undefined) {
    data.supplier_name = String(data.supplier_name).trim()
  }

  if (data.tax_id !== undefined) {
    data.tax_id = String(data.tax_id).trim()
  }

  if (data.note !== undefined) {
    data.note = String(data.note).trim()
  }

  data.account_id = accountId
  return data
}

function buildPurchaseInvoiceInsertQuery(data) {
  const columns = Object.keys(data)
  const values = Object.values(data)
  const placeholders = columns.map((_, i) => `$${i + 1}`)
  const sql = `INSERT INTO purchase_invoices (${columns.join(', ')})
      VALUES (${placeholders.join(', ')})
      RETURNING *`
  return { sql, params: values }
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

    const row = buildPurchaseInvoiceInsertRow(accountId, req.body)
    const { sql, params } = buildPurchaseInvoiceInsertQuery(row)

    const { rows } = await safeQuery(pool, sql, params)

    res.json(rows[0])
  } catch (err) {
    if (isPgUndefinedColumn(err)) {
      console.error('[purchases/create] schema mismatch:', String(err.message).slice(0, 200))
    } else {
      console.error('[purchases/create]', String(err?.message || err).slice(0, 200))
    }
    res.status(500).json({ error: 'Failed to create purchase invoice' })
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
    let existing
    try {
      const r = await safeQuery(
        pool,
        `SELECT id, image_url FROM purchase_invoices WHERE id = $1 AND ${tw.clause}
         AND (COALESCE(status, 'active') = 'active')`,
        [id, tw.param],
      )
      existing = r.rows
    } catch (selErr) {
      if (isPgUndefinedColumn(selErr)) {
        unlinkPurchaseImage(`/uploads/purchases/${req.file.filename}`)
        return res.status(503).json({
          error: 'Invoice images are not supported in this environment',
        })
      }
      throw selErr
    }

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
    if (req.file?.filename) {
      unlinkPurchaseImage(`/uploads/purchases/${req.file.filename}`)
    }
    if (isPgUndefinedColumn(err)) {
      console.error('[purchases/image] schema mismatch:', String(err.message).slice(0, 200))
    } else {
      console.error('[purchases/image]', String(err?.message || err).slice(0, 200))
    }
    res.status(500).json({ error: 'Failed to save invoice image' })
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
      document_no,
      doc_date,
      subtotal,
      vat_amount,
      total,
      note,
    } = req.body

    const docNoRaw = doc_no != null ? doc_no : document_no
    const docNoNorm =
      docNoRaw != null && String(docNoRaw).trim() !== ''
        ? String(docNoRaw).trim()
        : ''

    const baseParams = [
      supplier_name,
      tax_id ?? '',
      docNoNorm,
      doc_date ?? null,
      subtotal ?? 0,
      vat_amount ?? 0,
      total ?? 0,
      note ?? '',
    ]

    // Do not SET image_url here; some deployments have no image_url column on purchase_invoices.
    const tw = buildTenantWhereClause(req, '', 10)
    const sql = `
      UPDATE purchase_invoices
      SET
        supplier_name = $1,
        tax_id = $2,
        doc_no = $3,
        doc_date = $4,
        subtotal = $5,
        vat_amount = $6,
        total = $7,
        note = $8
      WHERE id = $9
        AND ${tw.clause}
        AND (COALESCE(status, 'active') = 'active')
      RETURNING *`

    const params = [...baseParams, id, tw.param]

    const result = await safeQuery(pool, sql, params)

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }

    res.json(result.rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    if (isPgUndefinedColumn(err)) {
      console.error('[purchases/update] schema mismatch:', String(err.message).slice(0, 200))
      return res.status(500).json({ error: 'Failed to update purchase invoice' })
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

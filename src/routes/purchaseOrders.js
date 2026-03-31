import { Router } from 'express'
import puppeteer from 'puppeteer'
import { pool } from '../db.js'
import { buildTenantWhereClause } from '../utils/tenant.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import {
  requireAccountId,
  safeQuery,
} from '../utils/tenantQuery.js'
import { renderDocument } from '../utils/documentTemplate.js'
import { getCompany } from '../services/companyService.js'
import { applyPdfLogoBaseUrl, buildCompanyForPdf } from '../utils/buildCompanyForPdf.js'
import { assertPoNotCancelled, isPoCancelled } from '../utils/cancelGuards.js'
import { assertPurchaseOrderNotLocked } from '../utils/lockGuards.js'
import { assertCanUsePO } from '../middleware/planGuards.js'
import { getPdfWatermarkText } from '../utils/planService.js'

const router = Router()
router.use(assertCanUsePO)
const LOCKED_ERROR = 'Document is locked and cannot be modified'

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function isUuid(s) {
  return typeof s === 'string' && UUID_RE.test(s.trim())
}

const PO_ALLOWED_STATUSES = new Set(['draft', 'approved', 'received', 'paid', 'cancelled'])

const PO_ALLOWED_TRANSITIONS = {
  draft: new Set(['approved', 'cancelled']),
  approved: new Set(['received', 'cancelled']),
  received: new Set([]),
  cancelled: new Set([]),
}

function normalizeItems(raw) {
  if (!Array.isArray(raw)) return []
  return raw.map((row, idx) => {
    const q = Number(row.quantity ?? row.qty ?? 1) || 0
    const up = Number(row.unit_price ?? 0) || 0
    const amount =
      row.amount != null
        ? Number(row.amount) || 0
        : row.line_total != null
          ? Number(row.line_total) || 0
          : Math.round(q * up * 100) / 100
    return {
      line_no: Number(row.line_no ?? idx + 1) || idx + 1,
      description: row.description != null ? String(row.description) : '',
      quantity: q,
      qty: q,
      unit_price: up,
      amount,
      line_total: amount,
    }
  })
}

async function getPoForTenant(poId, accountId) {
  const { rows } = await safeQuery(
    pool,
    `SELECT po.* FROM purchase_orders po
     WHERE po.id = $1::uuid AND po.account_id = $2::uuid`,
    [poId, accountId],
  )
  return rows[0] ?? null
}

router.get('/', async (req, res) => {
  try {
    requireAccountId(req)
    logTenantAccess('GET /api/po', req)

    const tw = buildTenantWhereClause(req, 'po', 1)
    const { rows } = await safeQuery(
      pool,
      `SELECT
         po.*,
         pi.id AS invoice_id
       FROM purchase_orders po
       LEFT JOIN purchase_invoices pi
         ON pi.source = 'PO'
        AND pi.source_id = po.id
        AND pi.account_id = po.account_id
       WHERE ${tw.clause}
       ORDER BY po.created_at DESC NULLS LAST, po.id DESC`,
      [tw.param],
    )

    res.json(rows)
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('GET /po error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/suppliers/list', async (req, res) => {
  try {
    const accountId = requireAccountId(req)
    const { rows } = await safeQuery(
      pool,
      `SELECT id, name, address, phone, tax_id
       FROM suppliers
       WHERE account_id = $1::uuid
         AND deleted_at IS NULL
       ORDER BY name ASC`,
      [accountId],
    )
    res.json(rows)
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('GET /api/po/suppliers/list error:', err)
    res.status(500).json({ error: err.message })
  }
})

async function cancelPurchaseOrder(req, res) {
  const client = await pool.connect()
  try {
    const accountId = requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    await client.query('BEGIN')

    const { rows: lockRows } = await client.query(
      `SELECT * FROM purchase_orders
       WHERE id = $1::uuid AND account_id = $2::uuid
       FOR UPDATE`,
      [id, accountId],
    )
    const po = lockRows[0]
    if (!po) {
      await client.query('ROLLBACK')
      return res.status(404).json({ error: 'Not found' })
    }
    if (isPoCancelled(po)) {
      await client.query('ROLLBACK')
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: 'ใบสั่งซื้อถูกยกเลิกแล้ว' })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      await client.query('ROLLBACK')
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    if (String(po.status || '').toLowerCase() === 'paid') {
      await client.query('ROLLBACK')
      return res.status(400).json({ error: LOCKED_ERROR })
    }
    console.log('PO STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      poId: id,
      status: po.status ?? null,
      is_locked: po.is_locked ?? null,
    })

    console.log('CANCEL PO:', { poId: id, accountId })

    const { rows } = await client.query(
      `UPDATE purchase_orders
       SET status = 'cancelled',
           is_locked = TRUE,
           updated_at = NOW()
       WHERE id = $1::uuid AND account_id = $2::uuid
       RETURNING *`,
      [id, accountId],
    )
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: rows[0]?.status ?? 'cancelled',
      is_locked: rows[0]?.is_locked ?? true,
    })

    await client.query('COMMIT')
    return res.json({ success: true })
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('cancelPurchaseOrder error:', err)
    return res.status(500).json({ error: err.message })
  } finally {
    client.release()
  }
}

router.post('/:id/cancel', cancelPurchaseOrder)
router.patch('/:id/cancel', cancelPurchaseOrder)

router.get('/:id/pdf', async (req, res) => {
  let accountId
  try {
    accountId = requireAccountId(req)
  } catch {
    return res.status(401).json({ error: 'Unauthorized' })
  }

  const client = await pool.connect()
  try {
    const { rows } = await client.query(
      `SELECT po.*
       FROM purchase_orders po
       WHERE po.id = $1 AND po.account_id = $2`,
      [req.params.id, accountId],
    )

    if (!rows.length) {
      return res.status(404).send('Not found')
    }

    const po = rows[0]

    const { rows: items } = await client.query(
      `SELECT * FROM purchase_order_items
       WHERE purchase_order_id = $1::uuid AND account_id = $2::uuid
       ORDER BY id ASC`,
      [po.id, accountId],
    )

    const fallbackCompany = await getCompany(pool, accountId)
    const doc = po
    const company = buildCompanyForPdf(doc, fallbackCompany)
    applyPdfLogoBaseUrl(company)
    console.log('PDF FINAL COMPANY:', company)

    const lineItems = normalizeItems(items)
    const showVatLine = po.vat_type === 'vat7'

    const watermarkText = await getPdfWatermarkText(pool, accountId)

    const html = renderDocument({
      type: 'po',
      data: {
        doc_no: po.doc_no,
        doc_date: po.issue_date || po.doc_date || po.created_at,
        party_name: po.supplier_name,
        party_address: po.supplier_address || '-',
        party_phone: po.supplier_phone || '-',
        party_tax: po.supplier_tax_id || po.tax_id || '-',
        items: lineItems,
        subtotal: po.subtotal,
        vat_amount: po.vat_amount,
        total: po.total,
        show_vat_line: showVatLine,
        vat_type: po.vat_type === 'vat7' ? 'vat7' : 'none',
      },
      company,
      lang: 'th',
      watermarkText,
    })

    const browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    })
    const page = await browser.newPage()

    await page.setContent(html, { waitUntil: 'networkidle0' })

    const pdfBuffer = await page.pdf({
      format: 'A4',
      printBackground: true,
    })

    await browser.close()

    res.setHeader('Content-Type', 'application/pdf')
    res.setHeader('Content-Disposition', 'inline; filename="document.pdf"')

    return res.end(pdfBuffer)
  } catch (err) {
    console.error(err)
    if (!res.headersSent) {
      return res.status(500).json({ error: err.message || 'PDF generation failed' })
    }
  } finally {
    client.release()
  }
})

router.post('/', async (req, res) => {
  const client = await pool.connect()
  try {
    const accountId = requireAccountId(req)
    logTenantAccess('POST /api/po', req)

    const {
      supplier_id,
      supplier_name,
      supplier_address,
      supplier_phone,
      supplier_tax_id,
      tax_id,
      issue_date,
      vat_enabled,
      vat_rate,
      vat_type,
      doc_date,
      note,
      items: rawItems,
    } = req.body

    let supplierSnapshot = {
      supplier_name: supplier_name != null ? String(supplier_name).trim() : '',
      supplier_address: supplier_address != null ? String(supplier_address) : '',
      supplier_phone: supplier_phone != null ? String(supplier_phone) : '',
      supplier_tax_id: supplier_tax_id != null ? String(supplier_tax_id) : '',
    }
    if (supplier_id != null && String(supplier_id).trim() !== '') {
      const { rows: sRows } = await safeQuery(
        client,
        `SELECT name, address, phone, tax_id
         FROM suppliers
         WHERE id = $1::uuid AND account_id = $2::uuid AND deleted_at IS NULL
         LIMIT 1`,
        [supplier_id, accountId],
      )
      if (sRows.length > 0) {
        const s = sRows[0]
        supplierSnapshot = {
          supplier_name: String(s.name ?? '').trim(),
          supplier_address: String(s.address ?? ''),
          supplier_phone: String(s.phone ?? ''),
          supplier_tax_id: String(s.tax_id ?? ''),
        }
      }
    }
    if (!supplierSnapshot.supplier_name) {
      return res.status(400).json({ error: 'supplier_name is required' })
    }

    const company = await getCompany(pool, accountId)
    console.log('PO SNAPSHOT COMPANY:', company)

    const snapshotName = company.name_th
    const snapshotAddress = company.address != null ? String(company.address) : ''
    const snapshotPhone = company.phone != null ? String(company.phone) : ''
    const snapshotTaxId = company.tax_id != null ? String(company.tax_id) : ''
    const snapshotLogo =
      company.logo_url && String(company.logo_url).trim() !== ''
        ? String(company.logo_url).trim()
        : null
    console.log('FINAL SNAPSHOT:', {
      name: snapshotName,
      address: snapshotAddress,
      phone: snapshotPhone,
      logo: snapshotLogo,
    })

    const items = normalizeItems(rawItems)

    const round2 = (n) => Math.round(Number(n || 0) * 100) / 100

    if (!items || !items.length) {
      return res.status(400).json({ error: 'items required' })
    }

    const computedItems = items.map((it) => {
      const quantity = Number(it.quantity || 0)
      const unitPrice = Number(it.unit_price || 0)
      const amount = round2(quantity * unitPrice)
      return { ...it, quantity, unit_price: unitPrice, amount }
    })

    const computedSubtotal = round2(
      computedItems.reduce((sum, it) => sum + it.amount, 0),
    )

    const vatEnabled = vat_enabled === true || vat_enabled === 'true' || vat_type === 'vat7'
    const resolvedVatRate = vatEnabled ? Number(vat_rate ?? (vat_type === 'vat7' ? 0.07 : 0.07)) || 0 : 0
    const normalizedVatType = vatEnabled ? 'vat7' : 'none'
    const computedVatAmount = vatEnabled ? round2(computedSubtotal * resolvedVatRate) : 0

    const computedTotal = round2(
      computedSubtotal + computedVatAmount,
    )

    const { rows: nowRows } = await client.query(
      `SELECT TO_CHAR(NOW(), 'YYYYMM') as yyyymm`,
    )
    const yyyymm = nowRows[0].yyyymm
    const likePrefix = `PO-${yyyymm}-`

    let po
    let attempts = 0
    while (attempts < 2) {
      attempts += 1
      await client.query('BEGIN')
      try {
        // Concurrency guard (covers "no previous rows" case too).
        // Keep the required FOR UPDATE query below as well.
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtext($1))`,
          [`po_doc_no:${accountId}:${yyyymm}`],
        )

        const { rows: lastRows } = await client.query(
          `SELECT doc_no
           FROM purchase_orders
           WHERE account_id = $1
             AND doc_no LIKE $2
           ORDER BY doc_no DESC
           LIMIT 1
           FOR UPDATE`,
          [accountId, `${likePrefix}%`],
        )

        let running = 1
        const lastDocNo = lastRows[0]?.doc_no
        if (lastDocNo) {
          const m = String(lastDocNo).match(/-(\d{3})$/)
          const lastRunning = m ? Number(m[1]) : 0
          running = Number.isFinite(lastRunning) && lastRunning > 0 ? lastRunning + 1 : 1
        }

        const generatedDocNo = `PO-${yyyymm}-${String(running).padStart(3, '0')}`

        const { rows: poRows } = await client.query(
          // company_logo_url: null when no logo (PDF applies default); company_name always set
          `INSERT INTO purchase_orders (
            account_id, company_name, company_address, company_phone, company_tax_id, company_logo_url,
            supplier_name, supplier_address, supplier_phone, supplier_tax_id, tax_id, doc_no, doc_date, issue_date,
            subtotal, vat_amount, total, vat_type, note, is_locked
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,COALESCE($13::date, CURRENT_DATE),$14,$15,$16,$17,$18,$19,FALSE)
          RETURNING *`,
          [
            accountId,
            snapshotName,
            snapshotAddress,
            snapshotPhone,
            snapshotTaxId,
            snapshotLogo,
            supplierSnapshot.supplier_name,
            supplierSnapshot.supplier_address,
            supplierSnapshot.supplier_phone,
            supplierSnapshot.supplier_tax_id,
            tax_id != null ? String(tax_id) : '',
            generatedDocNo,
            doc_date || issue_date || null,
            issue_date || doc_date || null,
            computedSubtotal,
            computedVatAmount,
            computedTotal,
            normalizedVatType,
            note != null ? String(note) : '',
          ],
        )

        po = poRows[0]
        console.log('DB RESULT:', po)
        console.log('PO CREATED WITH COMPANY SNAPSHOT:', {
          name: po.company_name,
          logo: po.company_logo_url,
        })

        for (const it of computedItems) {
          await client.query(
            `INSERT INTO purchase_order_items (
              purchase_order_id, account_id, description, quantity, unit_price, amount
            ) VALUES ($1::uuid,$2::uuid,$3,$4,$5,$6)`,
            [po.id, accountId, it.description, it.quantity, it.unit_price, it.amount],
          )
        }

        await client.query('COMMIT')
        break
      } catch (err) {
        try {
          await client.query('ROLLBACK')
        } catch {
          /* ignore */
        }

        // Retry once on unique violation (requires unique constraint on (account_id, doc_no))
        if (err?.code === '23505' && attempts < 2) {
          continue
        }
        throw err
      }
    }

    res.status(201).json(po)
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('POST /po error:', err)
    res.status(500).json({ error: err.message })
  } finally {
    client.release()
  }
})

router.get('/:id', async (req, res) => {
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('GET /api/po/:id', req, { id })

    const po = await getPoForTenant(id, accountId)
    if (!po) {
      return res.status(404).json({ error: 'Not found' })
    }

    const { rows: items } = await safeQuery(
      pool,
      `SELECT id, purchase_order_id, description, quantity, unit_price, amount
       FROM purchase_order_items
       WHERE purchase_order_id = $1::uuid AND account_id = $2::uuid
       ORDER BY id ASC`,
      [id, accountId],
    )

    res.json({ ...po, items })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('GET /po/:id error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.put('/:id', async (req, res) => {
  const client = await pool.connect()
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('PUT /api/po/:id', req, { id })

    const existing = await getPoForTenant(id, accountId)
    if (!existing) {
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(existing)
    } catch (err) {
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(existing)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    if (existing.status !== 'draft') {
      return res.status(400).json({ error: LOCKED_ERROR })
    }

    const { doc_no, doc_date, issue_date, subtotal, vat_amount, total, note, items: rawItems } = req.body

    const items = normalizeItems(rawItems)

    await client.query('BEGIN')

    const { rows } = await client.query(
      `UPDATE purchase_orders SET
        doc_no = $1,
        doc_date = $2,
        issue_date = COALESCE($3::date, issue_date),
        subtotal = $4,
        vat_amount = $5,
        total = $6,
        note = $7,
        is_locked = FALSE,
        updated_at = NOW()
      WHERE id = $8::uuid AND account_id = $9::uuid
      RETURNING *`,
      [
        doc_no != null ? String(doc_no) : '',
        doc_date || issue_date || null,
        issue_date || doc_date || null,
        subtotal != null ? Number(subtotal) : 0,
        vat_amount != null ? Number(vat_amount) : 0,
        total != null ? Number(total) : 0,
        note != null ? String(note) : '',
        id,
        accountId,
      ],
    )

    if (rows.length === 0) {
      await client.query('ROLLBACK')
      return res.status(404).json({ error: 'Not found' })
    }

    await client.query(
      `DELETE FROM purchase_order_items
       WHERE purchase_order_id = $1::uuid AND account_id = $2::uuid`,
      [id, accountId],
    )

    for (const it of items) {
      await client.query(
        `INSERT INTO purchase_order_items (
          purchase_order_id, account_id, description, quantity, unit_price, amount
        ) VALUES ($1::uuid,$2::uuid,$3,$4,$5,$6)`,
        [id, accountId, it.description, it.quantity, it.unit_price, it.amount],
      )
    }

    await client.query('COMMIT')
    res.json(rows[0])
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('PUT /po/:id error:', err)
    res.status(500).json({ error: err.message })
  } finally {
    client.release()
  }
})

router.delete('/:id', async (req, res) => {
  try {
    const accountId = requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    const po = await getPoForTenant(id, accountId)
    if (!po) {
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(po)
    } catch (err) {
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    if (po.status !== 'draft') {
      return res.status(400).json({ error: LOCKED_ERROR })
    }

    const { rows } = await safeQuery(
      pool,
      `UPDATE purchase_orders
       SET status = 'cancelled', is_locked = TRUE, updated_at = NOW()
       WHERE id = $1::uuid AND account_id = $2::uuid
       RETURNING id, status, is_locked`,
      [id, accountId],
    )
    if (!rows.length) {
      return res.status(404).json({ error: 'Not found' })
    }
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: rows[0].status,
      is_locked: rows[0].is_locked,
    })
    res.json({ success: true, status: rows[0].status })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('DELETE /po/:id error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.put('/:id/status', async (req, res) => {
  try {
    console.log('REQ PARAM ID:', req.params.id)
    console.log('REQ BODY:', req.body)
    console.log('ACCOUNT:', req.account_id)

    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    const newStatus = String(req.body?.status ?? '').trim().toLowerCase()
    if (!PO_ALLOWED_STATUSES.has(newStatus)) {
      return res.status(400).json({ error: 'Invalid status' })
    }

    logTenantAccess('PUT /api/po/:id/status', req, { id, status: newStatus })

    const po = await getPoForTenant(id, accountId)
    if (!po) {
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(po)
    } catch (err) {
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }

    const currentStatus = String(po.status || 'draft').toLowerCase()
    if (currentStatus === 'received' || currentStatus === 'paid') {
      return res.status(400).json({ error: 'Cannot change status after received' })
    }

    if (currentStatus === newStatus) {
      return res.json({ success: true, data: po })
    }

    const allowedFromCurrent = PO_ALLOWED_TRANSITIONS[currentStatus]
    if (!allowedFromCurrent || !allowedFromCurrent.has(newStatus)) {
      return res.status(400).json({ error: `Invalid status transition: ${currentStatus} -> ${newStatus}` })
    }

    console.log('Updating PO status:', id, newStatus)

    const result = await pool.query(
      `UPDATE purchase_orders
       SET status = $1,
           is_locked = CASE WHEN $1 IN ('paid', 'cancelled') THEN TRUE ELSE FALSE END
       WHERE id = $2
       AND account_id = $3
       RETURNING *`,
      [newStatus, id, accountId],
    )

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: result.rows[0]?.status ?? newStatus,
      is_locked: result.rows[0]?.is_locked ?? (newStatus !== 'draft'),
    })

    res.json({ success: true, data: result.rows[0] })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('PUT /po/:id/status error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.post('/:id/approve', async (req, res) => {
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('POST /api/po/:id/approve', req, { id })

    const po = await getPoForTenant(id, accountId)
    if (!po) {
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(po)
    } catch (err) {
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    console.log('PO STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      poId: id,
      status: po.status ?? null,
      is_locked: po.is_locked ?? null,
    })
    if (po.status !== 'draft') {
      return res.status(400).json({ error: 'Invalid status: expected draft' })
    }

    const { rows } = await safeQuery(
      pool,
      `UPDATE purchase_orders SET status = 'approved', is_locked = FALSE, updated_at = NOW()
       WHERE id = $1::uuid AND account_id = $2::uuid
       RETURNING *`,
      [id, accountId],
    )

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: rows[0].status,
      is_locked: rows[0].is_locked,
    })
    res.json(rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('POST /po/:id/approve error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.post('/:id/receive', async (req, res) => {
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('POST /api/po/:id/receive', req, { id })

    const po = await getPoForTenant(id, accountId)
    if (!po) {
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(po)
    } catch (err) {
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    console.log('PO STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      poId: id,
      status: po.status ?? null,
      is_locked: po.is_locked ?? null,
    })
    if (po.status !== 'approved') {
      return res.status(400).json({ error: 'Invalid status: expected approved' })
    }

    const { rows } = await safeQuery(
      pool,
      `UPDATE purchase_orders SET status = 'received', is_locked = FALSE, updated_at = NOW()
       WHERE id = $1::uuid AND account_id = $2::uuid
       RETURNING *`,
      [id, accountId],
    )

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: rows[0].status,
      is_locked: rows[0].is_locked,
    })
    res.json(rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('POST /po/:id/receive error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.put('/:id/receive', async (req, res) => {
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }

    const { id } = req.params
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    const po = await getPoForTenant(id, accountId)
    if (!po) {
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(po)
    } catch (err) {
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    console.log('PO STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      poId: id,
      status: po.status ?? null,
      is_locked: po.is_locked ?? null,
    })
    if (po.status !== 'approved') {
      return res.status(400).json({ error: 'Invalid status: expected approved' })
    }

    const result = await pool.query(
      `UPDATE purchase_orders
       SET status = 'received',
           is_locked = FALSE
       WHERE id = $1
       AND account_id = $2
       RETURNING *`,
      [id, accountId],
    )

    if (!result.rowCount) {
      return res.status(404).json({ error: 'Not found' })
    }
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: result.rows[0]?.status ?? 'received',
      is_locked: result.rows[0]?.is_locked ?? true,
    })

    res.json({ success: true, data: result.rows[0] })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Failed to receive PO' })
  }
})

router.put('/:id/pay', async (req, res) => {
  const { id } = req.params
  const client = await pool.connect()
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    const po = await getPoForTenant(id, accountId)
    if (!po) {
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(po)
    } catch (err) {
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    console.log('PO STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      poId: id,
      status: po.status ?? null,
      is_locked: po.is_locked ?? null,
    })
    if (po.status !== 'received') {
      return res.status(400).json({ error: 'Invalid status: expected received' })
    }

    await client.query('BEGIN')

    const updateResult = await client.query(
      `UPDATE purchase_orders
       SET status = 'paid',
           is_locked = TRUE
       WHERE id = $1
       AND account_id = $2
       RETURNING *`,
      [id, accountId],
    )

    if (!updateResult.rowCount) {
      await client.query('ROLLBACK')
      return res.status(404).json({ error: 'Not found' })
    }

    const { rows: existingInvoice } = await client.query(
      `SELECT 1
       FROM purchase_invoices
       WHERE source = 'PO' AND source_id = $1::uuid AND account_id = $2::uuid
       LIMIT 1`,
      [id, accountId],
    )

    if (existingInvoice.length === 0) {
      await client.query(
        `INSERT INTO purchase_invoices (
          account_id,
          supplier_name,
          tax_id,
          doc_no,
          doc_date,
          subtotal,
          vat_amount,
          total,
          source,
          source_id,
          created_at
        )
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'PO',$9,NOW())`,
        [
          po.account_id,
          po.supplier_name,
          po.tax_id,
          po.doc_no,
          po.issue_date || po.doc_date || po.created_at,
          po.subtotal,
          po.vat_amount,
          po.total,
          po.id,
        ],
      )
    }

    await client.query('COMMIT')
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: updateResult.rows[0]?.status ?? 'paid',
      is_locked: updateResult.rows[0]?.is_locked ?? true,
    })
    res.json({ success: true, data: updateResult.rows[0] })
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    console.error(err)
    res.status(500).json({ error: 'Failed to pay PO' })
  } finally {
    client.release()
  }
})

router.post('/:id/pay', async (req, res) => {
  const client = await pool.connect()
  try {
    const accountId = requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('POST /api/po/:id/pay', req, { id })

    await client.query('BEGIN')

    const { rows: lockRows } = await client.query(
      `SELECT * FROM purchase_orders
       WHERE id = $1::uuid AND account_id = $2
       FOR UPDATE`,
      [id, accountId],
    )

    const po = lockRows[0]
    if (!po) {
      await client.query('ROLLBACK')
      return res.status(404).json({ error: 'Not found' })
    }
    try {
      assertPoNotCancelled(po)
    } catch (err) {
      await client.query('ROLLBACK')
      console.log('CANCEL BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    try {
      assertPurchaseOrderNotLocked(po)
    } catch (err) {
      await client.query('ROLLBACK')
      console.log('LOCK BLOCKED ACTION:', { route: req.originalUrl, poId: id })
      return res.status(400).json({ error: err.message })
    }
    console.log('PO STATUS BEFORE LOCK:', {
      route: req.originalUrl,
      poId: id,
      status: po.status ?? null,
      is_locked: po.is_locked ?? null,
    })

    if (po.status !== 'received') {
      await client.query('ROLLBACK')
      return res.status(400).json({ error: 'Status must be received before pay' })
    }

    if (po.purchase_invoice_id != null) {
      await client.query('ROLLBACK')
      return res.status(400).json({ error: 'Purchase order already paid' })
    }

    console.log('[PO pay] before insert', { poId: id, accountId })

    const { rows: invRows } = await client.query(
      `INSERT INTO purchase_invoices (
        account_id, supplier_name, tax_id, doc_no, doc_date,
        subtotal, vat_amount, total, source, source_id, source_type
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::uuid,'po')
      RETURNING id`,
      [
        accountId,
        po.supplier_name,
        po.tax_id ?? '',
        po.doc_no ?? '',
        po.issue_date || po.doc_date || po.created_at,
        po.subtotal ?? 0,
        po.vat_amount ?? 0,
        po.total ?? 0,
        'PO',
        id,
      ],
    )

    const insertedId = invRows[0]?.id
    console.log('[PO pay] after insert', { purchase_invoice_id: insertedId, rowsInserted: invRows?.length })

    if (insertedId == null) {
      await client.query('ROLLBACK')
      return res.status(500).json({ error: 'Failed to create purchase invoice' })
    }

    console.log('PO ID:', id)
    console.log('ACCOUNT ID:', accountId)
    console.log('[PO pay] before update', { poId: id, accountId, purchase_invoice_id: insertedId })

    const updateResult = await client.query(
      `UPDATE purchase_orders
      SET
        status = 'paid',
        is_locked = TRUE,
        purchase_invoice_id = $1,
        updated_at = NOW()
      WHERE id = $2::uuid AND account_id = $3
      RETURNING *`,
      [insertedId, id, accountId],
    )

    const rowCount = updateResult.rowCount
    console.log('[PO pay] after update', { rowCount, rows: updateResult.rows?.length })

    if (!rowCount || rowCount === 0) {
      await client.query('ROLLBACK')
      throw new Error('PO update failed')
    }

    await client.query('COMMIT')
    console.log('PO LOCKED AFTER TRANSITION:', {
      route: req.originalUrl,
      poId: id,
      status: updateResult.rows[0]?.status ?? 'paid',
      is_locked: updateResult.rows[0]?.is_locked ?? true,
    })
    res.json({ success: true, purchase_invoice_id: insertedId })
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('POST /po/:id/pay error:', err)
    res.status(500).json({ error: err.message })
  } finally {
    client.release()
  }
})

export default router

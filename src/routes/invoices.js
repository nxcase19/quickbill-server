import { Router } from 'express'
import jwt from 'jsonwebtoken'
import puppeteer from 'puppeteer'
import { pool } from '../db.js'
import { jwtSecret } from '../config.js'
import { buildTenantWhereClause } from '../utils/tenant.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import {
  requireAccountId,
  safeQuery,
} from '../utils/tenantQuery.js'
import { renderDocument } from '../utils/documentTemplate.js'
import { getPdfWatermarkText } from '../utils/planService.js'
import { getCompany } from '../services/companyService.js'
import { applyPdfLogoBaseUrl, buildCompanyForPdf } from '../utils/buildCompanyForPdf.js'

const router = Router()
const LOCKED_ERROR = 'Document is locked and cannot be modified'

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function isUuid(s) {
  return typeof s === 'string' && UUID_RE.test(s.trim())
}

function normalizeItems(raw) {
  if (!Array.isArray(raw)) return []
  return raw.map((row) => {
    const q = Number(row.quantity ?? 1) || 0
    const up = Number(row.unit_price ?? 0) || 0
    const amount = Math.round(q * up * 100) / 100
    return {
      description: row.description != null ? String(row.description) : '',
      quantity: q,
      unit_price: up,
      amount,
    }
  })
}

async function getInvoiceForTenant(req, invoiceId) {
  const tw = buildTenantWhereClause(req, 'inv', 2)
  const { rows } = await safeQuery(
    pool,
    `SELECT inv.* FROM invoices inv WHERE inv.id = $1::uuid AND ${tw.clause}`,
    [invoiceId, tw.param],
  )
  return rows[0] ?? null
}

router.get('/', async (req, res) => {
  try {
    requireAccountId(req)
    logTenantAccess('GET /api/invoices', req)

    const tw = buildTenantWhereClause(req, 'inv', 1)
    const { rows } = await safeQuery(
      pool,
      `SELECT inv.*
       FROM invoices inv
       WHERE ${tw.clause}
       ORDER BY inv.created_at DESC NULLS LAST, inv.id DESC`,
      [tw.param],
    )

    res.json(rows)
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('GET /invoices error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/:id/pdf', async (req, res) => {
  const rawToken =
    req.query.token ||
    (req.headers.authorization && req.headers.authorization.split(' ')[1])

  console.log('🔥 SALES PDF TOKEN:', rawToken)

  if (!rawToken) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized: Missing token',
    })
  }

  let payload
  try {
    payload = jwt.verify(rawToken, jwtSecret)
  } catch {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized: Invalid token',
    })
  }

  const accountId =
    payload.accountId ||
    payload.account_id ||
    payload.id ||
    payload.userId ||
    null

  console.log('🔥 SALES ACCOUNT ID:', accountId)

  if (!accountId) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized: Invalid token payload',
    })
  }

  const accountIdStr = String(accountId)

  const client = await pool.connect()
  try {
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    const qLang = req.query.lang
    const pdfLangOverride =
      qLang === 'en' || qLang === 'th' ? qLang : null

    const { rows } = await client.query(
      `SELECT inv.*
       FROM invoices inv
       WHERE inv.id = $1 AND inv.account_id = $2`,
      [id, accountIdStr],
    )

    if (!rows.length) {
      return res.status(404).send('Not found')
    }

    const inv = rows[0]

    const { rows: items } = await client.query(
      `SELECT * FROM invoice_items WHERE invoice_id = $1 ORDER BY id ASC`,
      [inv.id],
    )

    const fallbackCompany = await getCompany(pool, accountIdStr)
    const doc = inv
    const company = buildCompanyForPdf(doc, fallbackCompany)
    applyPdfLogoBaseUrl(company)
    console.log('PDF FINAL COMPANY:', company)

    const effectiveLang = pdfLangOverride ?? 'th'
    const showVatLine = inv.vat_type === 'vat7'

    const watermarkText = await getPdfWatermarkText(pool, accountIdStr)

    const html = renderDocument({
      type: 'invoice',
      data: {
        doc_no: inv.doc_no,
        date: inv.doc_date,
        party_name: inv.customer_name,
        party_address: inv.customer_address || '-',
        party_phone: inv.customer_phone || '-',
        party_tax: inv.customer_tax_id || inv.tax_id || '-',
        items: normalizeItems(items),
        subtotal: inv.subtotal,
        vat: inv.vat_amount,
        total: inv.total,
        show_vat_line: showVatLine,
        vat_type: inv.vat_type === 'vat7' ? 'vat7' : 'none',
      },
      company,
      lang: effectiveLang,
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
    res.status(500).send(err.message)
  } finally {
    client.release()
  }
})

router.get('/:id', async (req, res) => {
  try {
    requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('GET /api/invoices/:id', req, { id })

    const inv = await getInvoiceForTenant(req, id)
    if (!inv) {
      return res.status(404).json({ error: 'Not found' })
    }

    const { rows: items } = await safeQuery(
      pool,
      `SELECT id, invoice_id, description, quantity, unit_price, amount
       FROM invoice_items
       WHERE invoice_id = $1::uuid
       ORDER BY id ASC`,
      [id],
    )

    res.json({ ...inv, items })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('GET /invoices/:id error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.post('/', async (req, res) => {
  console.log('CREATE INVOICE:', req.body)

  const client = await pool.connect()
  try {
    const accountId = requireAccountId(req)
    logTenantAccess('POST /api/invoices', req)

    const {
      customer_id,
      customer_name,
      customer_address,
      customer_phone,
      customer_tax_id,
      tax_id,
      vat_type,
      doc_date,
      note,
      items: rawItems,
      total,
    } = req.body

    if (!customer_name || String(customer_name).trim() === '') {
      return res.status(400).json({ message: 'customer is required' })
    }

    const items = normalizeItems(rawItems)

    if (!items || !items.length) {
      return res.status(400).json({ message: 'items required' })
    }

    const round2 = (n) => Math.round(Number(n || 0) * 100) / 100

    const computedItems = items.map((it) => {
      const quantity = Number(it.quantity || 0)
      const unitPrice = Number(it.unit_price || 0)
      const amount = round2(quantity * unitPrice)
      return { ...it, quantity, unit_price: unitPrice, amount }
    })

    const computedSubtotal = round2(
      computedItems.reduce((sum, it) => sum + it.amount, 0),
    )

    const normalizedVatType = vat_type === 'vat7' ? 'vat7' : 'none'

    const computedVatAmount =
      normalizedVatType === 'vat7'
        ? round2(computedSubtotal * 0.07)
        : 0

    const computedTotal = round2(
      computedSubtotal + computedVatAmount,
    )

    if (total == null || Number(total) <= 0) {
      return res.status(400).json({ message: 'total is required' })
    }

    const { rows: nowRows } = await client.query(
      `SELECT TO_CHAR(NOW(), 'YYYYMM') as yyyymm`,
    )
    const yyyymm = nowRows[0].yyyymm
    const likePrefix = `INV-${yyyymm}-`

    let inv
    let attempts = 0
    while (attempts < 2) {
      attempts += 1
      await client.query('BEGIN')
      try {
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtext($1))`,
          [`inv_doc_no:${accountId}:${yyyymm}`],
        )

        const { rows: lastRows } = await client.query(
          `SELECT doc_no
           FROM invoices
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

        const generatedDocNo = `INV-${yyyymm}-${String(running).padStart(3, '0')}`

        const { rows: invRows } = await client.query(
          `INSERT INTO invoices (
            account_id, customer_id, customer_name, customer_address, customer_phone, customer_tax_id, tax_id, doc_no, doc_date,
            subtotal, vat_amount, total, vat_type, note
          ) VALUES ($1,$2::uuid,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
          RETURNING *`,
          [
            accountId,
            customer_id || null,
            String(customer_name).trim(),
            customer_address != null ? String(customer_address) : '',
            customer_phone != null ? String(customer_phone) : '',
            customer_tax_id != null ? String(customer_tax_id) : '',
            tax_id != null ? String(tax_id) : '',
            generatedDocNo,
            doc_date || null,
            computedSubtotal,
            computedVatAmount,
            computedTotal,
            normalizedVatType,
            note != null ? String(note) : '',
          ],
        )

        inv = invRows[0]

        for (const it of computedItems) {
          await client.query(
            `INSERT INTO invoice_items (
              invoice_id, description, quantity, unit_price, amount
            ) VALUES ($1::uuid,$2,$3,$4,$5)`,
            [inv.id, it.description, it.quantity, it.unit_price, it.amount],
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

        if (err?.code === '23505' && attempts < 2) {
          continue
        }
        throw err
      }
    }

    return res.status(201).json(inv)
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('CREATE INVOICE ERROR:', err)
    return res.status(500).json({
      message: 'Create invoice failed',
      error: err.message,
    })
  } finally {
    client.release()
  }
})

router.put('/:id', async (req, res) => {
  const client = await pool.connect()
  try {
    requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('PUT /api/invoices/:id', req, { id })

    const existing = await getInvoiceForTenant(req, id)
    if (!existing) {
      return res.status(404).json({ error: 'Not found' })
    }
    if (existing.status !== 'draft') {
      return res.status(400).json({ error: LOCKED_ERROR })
    }

    const {
      customer_id,
      customer_name,
      customer_address,
      customer_phone,
      customer_tax_id,
      tax_id,
      vat_type,
      doc_date,
      note,
      items: rawItems,
    } = req.body

    if (!customer_name || String(customer_name).trim() === '') {
      return res.status(400).json({ error: 'customer_name is required' })
    }

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
    const normalizedVatType = vat_type === 'vat7' ? 'vat7' : 'none'
    const computedVatAmount =
      normalizedVatType === 'vat7'
        ? round2(computedSubtotal * 0.07)
        : 0
    const computedTotal = round2(computedSubtotal + computedVatAmount)

    const tw = buildTenantWhereClause(req, '', 10)

    await client.query('BEGIN')

    const { rows } = await client.query(
      `UPDATE invoices SET
        customer_id = $1::uuid,
        customer_name = $2,
        customer_address = $3,
        customer_phone = $4,
        customer_tax_id = $5,
        tax_id = $6,
        doc_date = $7,
        subtotal = $8,
        vat_amount = $9,
        total = $10,
        vat_type = $11,
        note = $12,
        updated_at = NOW()
      WHERE id = $13::uuid AND ${tw.clause}
      RETURNING *`,
      [
        customer_id || null,
        String(customer_name).trim(),
        customer_address != null ? String(customer_address) : '',
        customer_phone != null ? String(customer_phone) : '',
        customer_tax_id != null ? String(customer_tax_id) : '',
        tax_id != null ? String(tax_id) : '',
        doc_date || null,
        computedSubtotal,
        computedVatAmount,
        computedTotal,
        normalizedVatType,
        note != null ? String(note) : '',
        id,
        tw.param,
      ],
    )

    if (rows.length === 0) {
      await client.query('ROLLBACK')
      return res.status(404).json({ error: 'Not found' })
    }

    await client.query(`DELETE FROM invoice_items WHERE invoice_id = $1::uuid`, [id])

    for (const it of computedItems) {
      await client.query(
        `INSERT INTO invoice_items (
          invoice_id, description, quantity, unit_price, amount
        ) VALUES ($1::uuid,$2,$3,$4,$5)`,
        [id, it.description, it.quantity, it.unit_price, it.amount],
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
    console.error('PUT /invoices/:id error:', err)
    res.status(500).json({ error: err.message })
  } finally {
    client.release()
  }
})

router.post('/:id/issue', async (req, res) => {
  try {
    requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('POST /api/invoices/:id/issue', req, { id })

    const inv = await getInvoiceForTenant(req, id)
    if (!inv) {
      return res.status(404).json({ error: 'Not found' })
    }
    if (inv.status !== 'draft') {
      return res.status(400).json({ error: 'Invalid status: expected draft' })
    }

    const tw = buildTenantWhereClause(req, '', 2)
    const { rows } = await safeQuery(
      pool,
      `UPDATE invoices SET status = 'issued', updated_at = NOW()
       WHERE id = $1::uuid AND ${tw.clause}
       RETURNING *`,
      [id, tw.param],
    )

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    res.json(rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('POST /invoices/:id/issue error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.post('/:id/pay', async (req, res) => {
  try {
    requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('POST /api/invoices/:id/pay', req, { id })

    const inv = await getInvoiceForTenant(req, id)
    if (!inv) {
      return res.status(404).json({ error: 'Not found' })
    }
    if (inv.status !== 'issued') {
      return res.status(400).json({ error: 'Invalid status: expected issued' })
    }

    const tw = buildTenantWhereClause(req, '', 2)
    const { rows } = await safeQuery(
      pool,
      `UPDATE invoices SET status = 'paid', updated_at = NOW()
       WHERE id = $1::uuid AND ${tw.clause}
       RETURNING *`,
      [id, tw.param],
    )

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    res.json(rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('POST /invoices/:id/pay error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.delete('/:id', async (req, res) => {
  try {
    requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    logTenantAccess('DELETE /api/invoices/:id', req, { id })

    const inv = await getInvoiceForTenant(req, id)
    if (!inv) {
      return res.status(404).json({ error: 'Not found' })
    }
    if (inv.status !== 'draft') {
      return res.status(400).json({ error: LOCKED_ERROR })
    }

    const tw = buildTenantWhereClause(req, '', 2)
    const { rows } = await safeQuery(
      pool,
      `UPDATE invoices
       SET status = 'cancelled', updated_at = NOW()
       WHERE id = $1::uuid AND ${tw.clause}
       RETURNING id, status`,
      [id, tw.param],
    )

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    res.json({ success: true, status: rows[0].status })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('DELETE /invoices/:id error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.patch('/:id/cancel', async (req, res) => {
  try {
    requireAccountId(req)
    const id = req.params.id
    if (!isUuid(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    const inv = await getInvoiceForTenant(req, id)
    if (!inv) {
      return res.status(404).json({ error: 'Not found' })
    }
    if (inv.status === 'paid') {
      return res.status(400).json({ error: LOCKED_ERROR })
    }
    if (inv.status === 'cancelled') {
      return res.json(inv)
    }

    const tw = buildTenantWhereClause(req, '', 2)
    const { rows } = await safeQuery(
      pool,
      `UPDATE invoices
       SET status = 'cancelled', updated_at = NOW()
       WHERE id = $1::uuid AND ${tw.clause}
       RETURNING *`,
      [id, tw.param],
    )
    if (!rows.length) {
      return res.status(404).json({ error: 'Not found' })
    }
    res.json(rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('PATCH /invoices/:id/cancel error:', err)
    res.status(500).json({ error: err.message })
  }
})

export default router

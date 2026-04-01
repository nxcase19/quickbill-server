import { Router } from 'express'
import puppeteer from 'puppeteer'
import fs from 'node:fs'
import path from 'node:path'
import { pool } from '../db.js'
import { getAccountId, getCompanyId, buildTenantWhereClause } from '../utils/tenant.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import { requireAccountId, safeQuery } from '../utils/tenantQuery.js'
import { renderDocument } from '../utils/documentTemplate.js'
import { getCompany } from '../services/companyService.js'
import { applyPdfLogoBaseUrl, buildCompanyForPdf } from '../utils/buildCompanyForPdf.js'
import { assertCanCreateDocument } from '../middleware/planGuards.js'
import { getPdfWatermarkText } from '../utils/planService.js'
import {
  FREE_DAILY_DOC_LIMIT,
  countDocumentsCreatedToday,
  incrementDocumentUsage,
} from '../utils/usageService.js'

/** Legacy bigint company_id for INSERT only when the column is NOT NULL; never used as tenant filter. */
function legacyCompanyIdForInsert(req) {
  const v = getCompanyId(req)
  if (v == null || v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

const router = Router()

function docTypeToPrefix(dt) {
  if (!dt || typeof dt !== 'string') return 'INV'
  const u = dt.trim().toUpperCase()
  if (u === 'INV' || u === 'RC' || u === 'QT' || u === 'DN') return u
  return 'INV'
}

function normalizeDocumentItemsForPdf(raw) {
  if (!Array.isArray(raw)) return []
  return raw.map((row) => {
    const q = Number(row.qty ?? row.quantity ?? 0) || 0
    const up = Number(row.unit_price ?? 0) || 0
    const lineTot =
      row.line_total != null && row.line_total !== ''
        ? Number(row.line_total)
        : Math.round(q * up * 100) / 100
    const amount = Number.isFinite(lineTot) ? lineTot : 0
    return {
      description: row.description != null ? String(row.description) : '',
      quantity: q,
      unit_price: up,
      amount,
    }
  })
}

router.get('/', async (req, res) => {
  try {
    const accountId = getAccountId(req)
    if (!accountId) {
      return res.status(401).json({ success: false, error: 'Missing account_id' })
    }
    logTenantAccess('GET /api/documents', req)
    console.log('TENANT documents', { accountId })

    const { status, q } = req.query

    const tw = buildTenantWhereClause(req, 'd', 1)
    let sql = `
    SELECT
      d.id,
      d.doc_no,
      d.doc_type,
      d.order_id,
      d.customer_name,
      d.total,
      d.paid_amount,
      d.status AS payment_status,
      d.is_locked
    FROM documents d
    WHERE ${tw.clause}
  `
    const params = [tw.param]

    if (status === 'outstanding') {
      sql += ` AND d.status IN ('unpaid', 'partial')`
    } else if (status === 'paid') {
      sql += ` AND d.status = 'paid'`
    }

    if (q && String(q).trim() !== '') {
      const like = `%${String(q).trim()}%`
      sql += ` AND (d.doc_no ILIKE $${params.length + 1} OR d.customer_name ILIKE $${params.length + 2})`
      params.push(like, like)
    }

    sql += ` ORDER BY d.id DESC`

    const { rows } = await safeQuery(pool, sql, params)
    return res.json({ success: true, data: rows })
  } catch (err) {
    console.error('documents GET error:', err?.message, err?.detail, err?.code, err?.stack)
    return res.status(500).json({ success: false, error: err.message })
  }
})

router.get('/debug/db', async (req, res) => {
  try {
    const accountId = getAccountId(req)
    if (!accountId) {
      return res.status(401).json({ success: false, error: 'Missing account_id' })
    }
    console.log('TENANT documents', { accountId })
    const { rows } = await safeQuery(
      pool,
      `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'documents'
      ORDER BY ordinal_position
    `,
      [],
      { skipAssert: true },
    )
    return res.json({ success: true, data: rows })
  } catch (err) {
    console.error('debug/db error:', err)
    return res.status(500).json({ success: false, error: err.message })
  }
})

router.get('/usage/today', async (req, res) => {
  try {
    let accountId
    try {
      accountId = requireAccountId(req)
    } catch {
      return res.status(401).json({ success: false, error: 'Unauthorized' })
    }
    const isTrial = req.user?.is_trial_active === true
    const plan = String(req.user?.plan || 'free').toLowerCase()
    const count = await countDocumentsCreatedToday(pool, accountId)
    const limit = !isTrial && plan === 'free' ? FREE_DAILY_DOC_LIMIT : null
    return res.json({
      success: true,
      data: { count, limit },
    })
  } catch (err) {
    console.error('GET /documents/usage/today error:', err)
    return res.status(500).json({ success: false, error: err.message })
  }
})

router.get('/:id/pdf', async (req, res) => {
  let accountId
  try {
    accountId = requireAccountId(req)
  } catch {
    return res.status(401).json({ error: 'Unauthorized' })
  }

  try {
    console.log('TENANT documents', { accountId })

    const id = Number(req.params.id)
    if (!Number.isFinite(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }

    const sql = `SELECT * FROM documents d WHERE d.id = $1 AND d.account_id = $2::uuid`
    const params = [id, accountId]
    logTenantAccess('GET /api/documents/:id/pdf', req, { id: req.params.id })

    const { rows: docRows } = await safeQuery(pool, sql, params)
    if (docRows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }

    const document = docRows[0]
    let items = []

    if (String(document.doc_type ?? '').toUpperCase() === 'INV') {
      const { rows } = await safeQuery(
        pool,
        `SELECT * FROM document_items WHERE document_id = $1 ORDER BY line_no ASC`,
        [id],
        { skipAssert: true },
      )
      items = rows
    } else if (document.order_id != null && String(document.order_id) !== '') {
      const { rows: invRows } = await safeQuery(
        pool,
        `SELECT id FROM documents d
         WHERE d.order_id = $1 AND d.account_id = $2::uuid AND d.doc_type = 'INV'
         LIMIT 1`,
        [document.order_id, accountId],
      )

      if (invRows.length > 0) {
        const invId = invRows[0].id
        const { rows } = await safeQuery(
          pool,
          `SELECT * FROM document_items WHERE document_id = $1 ORDER BY line_no ASC`,
          [invId],
          { skipAssert: true },
        )
        items = rows
      }
    }

    const fallbackCompany = await getCompany(pool, accountId)
    const doc = document
    const company = buildCompanyForPdf(doc, fallbackCompany)
    applyPdfLogoBaseUrl(company)
    console.log('PDF FINAL COMPANY:', company)

    const kind = String(document.doc_type ?? 'INV').toUpperCase()
    const typeMap = {
      QT: 'quotation',
      DN: 'dn',
      INV: 'invoice',
      RC: 'receipt',
    }
    const renderType = typeMap[kind] || 'invoice'

    const subtotal = Number(document.subtotal) || 0
    const total = Number(document.total) || 0
    const vatRate = Number(document.vat_rate) || 0
    const vatEnabled = document.vat_enabled === true
    const showVatLine = vatEnabled && vatRate > 0
    const vatAmount = showVatLine ? subtotal * vatRate : 0

    const docVatTypeFromRow =
      document.vat_type != null && String(document.vat_type).trim() === 'vat7'
        ? 'vat7'
        : null
    const docVatType =
      docVatTypeFromRow === 'vat7'
        ? 'vat7'
        : showVatLine && Math.abs(vatRate - 0.07) < 1e-8
          ? 'vat7'
          : 'none'

    const partyTax =
      document.customer_tax_id != null && String(document.customer_tax_id).trim() !== ''
        ? String(document.customer_tax_id).trim()
        : ''

    const watermarkText = await getPdfWatermarkText(pool, accountId)

    // Load Thai font as base64 for Puppeteer embedding
    let fontBase64 = ''
    try {
      const fontPath = path.join(process.cwd(), 'assets/fonts/THSarabun.ttf')
      const buf = fs.readFileSync(fontPath)
      fontBase64 = buf.toString('base64')
    } catch (e) {
      console.error('PDF FONT LOAD ERROR:', e)
    }

    const rawHtml = renderDocument({
      type: renderType,
      data: {
        doc_no: document.doc_no,
        date: document.doc_date,
        party_name: document.customer_name,
        party_address: document.customer_address || '-',
        party_phone: document.customer_phone || '-',
        party_tax: partyTax,
        items: normalizeDocumentItemsForPdf(items),
        subtotal,
        vat: vatAmount,
        total,
        show_vat_line: showVatLine,
        vat_type: docVatType,
      },
      company,
      lang: 'th',
      watermarkText,
    })

    const html = fontBase64
      ? `
<html>
<head>
<meta charset="UTF-8" />
<style>
@font-face {
  font-family: 'THSarabun';
  src: url('data:font/truetype;charset=utf-8;base64,${fontBase64}') format('truetype');
}

* {
  font-family: 'THSarabun' !important;
  box-sizing: border-box;
  font-size: 24px !important;
}

body {
  font-size: 24px;
  line-height: 1.7;
  color: #111;
  padding: 40px;
}

/* HEADER */
.company {
  font-size: 26px !important;
}

.doc-title {
  font-size: 36px !important;
  font-weight: bold;
}

.meta {
  font-size: 24px !important;
}

/* SECTION */
.section {
  margin-top: 30px;
}

/* BOX */
.box {
  background: #f5f6f8;
  padding: 18px;
  border-radius: 10px;
  margin-top: 12px;
  font-size: 24px !important;
}

/* TABLE */
table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 30px;
}

th {
  background: #f1f3f5;
  padding: 14px;
  font-size: 26px !important;
  font-weight: bold;
}

td {
  padding: 14px;
  border-bottom: 1px solid #ddd;
  font-size: 24px !important;
}

/* TOTAL BOX */
.total-box {
  margin-top: 30px;
  margin-left: auto;
  width: 340px;
  background: #f5f6f8;
  padding: 18px;
  border-radius: 10px;
  font-size: 24px !important;
}

.total-row {
  display: flex;
  justify-content: space-between;
  margin-bottom: 10px;
}

.total-final {
  font-size: 28px !important;
  font-weight: bold;
}

/* SIGNATURE */
.signature {
  margin-top: 80px;
  display: flex;
  justify-content: space-between;
}

.sign-box {
  width: 42%;
  text-align: center;
  font-size: 24px !important;
}

.sign-line {
  margin-top: 60px;
  border-top: 1px solid #000;
}
</style>
</head>
<body>
${rawHtml}
</body>
</html>
`
      : rawHtml

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
    console.error('documents GET /:id/pdf error:', err)
    if (!res.headersSent) {
      res.status(500).json({ error: err.message })
    }
  }
})

router.get('/:id', async (req, res) => {
  const accountId = getAccountId(req)
  if (!accountId) {
    return res.status(401).json({ success: false, error: 'Missing account_id' })
  }
  console.log('TENANT documents', { accountId })

  const id = Number(req.params.id)

  if (!Number.isFinite(id)) {
    return res.status(400).json({ success: false, error: 'Invalid id' })
  }

  try {
    const tw = buildTenantWhereClause(req, 'd', 2)
    const sql = `SELECT * FROM documents d WHERE d.id = $1 AND ${tw.clause}`
    const params = [id, tw.param]
    const { rows } = await safeQuery(pool, sql, params)

    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Document not found' })
    }

    return res.json({ success: true, data: rows[0] })
  } catch (err) {
    console.error('GET document error:', err)
    return res.status(500).json({ success: false, error: err.message })
  }
})

router.post('/', assertCanCreateDocument, async (req, res) => {
  try {
    const account_id =
    req.account_id ??
    req.user?.account_id ??
    (req.user?.accountId != null ? String(req.user.accountId) : null)

    if (!account_id) {
      return res.status(400).json({
        success: false,
        error: 'Missing account_id',
      })
    }

    const accountId = account_id

    console.log('DOCUMENT BODY:', req.body)

    logTenantAccess('POST /api/documents', req)

    const rawDocTypes = Array.isArray(req.body.doc_types)
      ? req.body.doc_types
      : [req.body.doc_type || 'INV']

    const docTypes = rawDocTypes
      .map((t) => String(t).trim().toUpperCase())
      .filter((t) => t.length > 0)

    if (docTypes.length === 0) {
      return res.status(400).json({ success: false, error: 'doc_types is required' })
    }

    const allowedDocTypes = ['QT', 'DN', 'INV', 'RC']
    for (const dt of docTypes) {
      if (!allowedDocTypes.includes(dt)) {
        return res.status(400).json({ success: false, error: 'Invalid doc_type: ' + dt })
      }
    }

    const plan = String(req.user?.plan || 'free').toLowerCase()
    const isTrial = req.user?.is_trial_active === true

    const countResult = await safeQuery(
      pool,
      `SELECT COUNT(*)::int AS count
     FROM documents
     WHERE account_id = $1::uuid
       AND created_at::date = CURRENT_DATE`,
      [account_id],
      { skipAssert: true },
    )
    let todayCount = 0
    if (
      countResult &&
      countResult.rows &&
      countResult.rows[0] &&
      countResult.rows[0].count != null
    ) {
      todayCount = Number(countResult.rows[0].count)
    }
    const pendingDocs = docTypes.length

    if (
      !isTrial &&
      plan === 'free' &&
      todayCount + pendingDocs > FREE_DAILY_DOC_LIMIT
    ) {
      return res.status(403).json({
        success: false,
        code: 'LIMIT_REACHED',
        error: 'คุณใช้ครบ 3 เอกสารต่อวันแล้ว กรุณาอัปเกรดแพ็กเกจ',
      })
    }

    const docDateRaw = req.body.doc_date ?? req.body.docDate
    const customerId =
      req.body.customerId != null ? req.body.customerId : req.body.customer_id
    const customerNameInput = String(req.body.customer_name ?? '').trim()
    const customerAddressInput = String(req.body.customer_address ?? '').trim()
    const customerPhoneInput = String(req.body.customer_phone ?? '').trim()
    const customerTaxInput = String(req.body.customer_tax_id ?? req.body.tax_id ?? '').trim()
    const items = Array.isArray(req.body.items) ? req.body.items : []

    if (items.length === 0) {
      return res.status(400).json({ success: false, error: 'items must not be empty' })
    }

    let subtotal = 0
    const normalizedItems = []
    for (const it of items) {
      const qty = Number(it.qty) || 0
      const unitPrice =
        it.unitPrice != null
          ? Number(it.unitPrice)
          : it.unit_price != null
            ? Number(it.unit_price)
            : 0
      const desc = it.description != null ? String(it.description) : ''
      if (!Number.isFinite(qty) || qty <= 0) {
        return res.status(400).json({ success: false, error: 'qty must be greater than 0' })
      }
      if (!Number.isFinite(unitPrice) || unitPrice < 0) {
        return res.status(400).json({ success: false, error: 'unit_price must be >= 0' })
      }
      const lineTotal = qty * unitPrice
      subtotal += lineTotal
      normalizedItems.push({ description: desc, qty, unitPrice, lineTotal })
    }

    const body = req.body
    const vatEnabled = body.vat_enabled ?? body.vatEnabled ?? true

    const vatRate = vatEnabled
      ? Number(body.vat_rate ?? body.vatRate ?? 0)
      : 0
    const vatAmount = subtotal * vatRate
    const total = subtotal + vatAmount

    const note = req.body.note ? String(req.body.note) : ''

    console.log('VAT DEBUG:', {
      subtotal,
      vatRate,
      vatAmount,
      total,
    })

    const docDate =
      docDateRaw != null && String(docDateRaw).trim() !== ''
        ? String(docDateRaw).slice(0, 10)
        : new Date().toISOString().slice(0, 10)

    const client = await pool.connect()
    let committed = false
    try {
      let customerSnapshot = {
        name: customerNameInput,
        address: customerAddressInput,
        phone: customerPhoneInput,
        tax_id: customerTaxInput,
      }

      if (customerId != null && String(customerId).trim() !== '') {
        const twCust = buildTenantWhereClause(req, '', 2)
        const { rows: custRows } = await safeQuery(
          client,
          `SELECT name, address, phone, tax_id FROM customers WHERE id = $1 AND ${twCust.clause}`,
          [customerId, twCust.param],
        )
        if (custRows.length > 0) {
          const c = custRows[0]
          customerSnapshot = {
            name: customerSnapshot.name || String(c.name ?? '').trim(),
            address: customerSnapshot.address || String(c.address ?? '').trim(),
            phone: customerSnapshot.phone || String(c.phone ?? '').trim(),
            tax_id: customerSnapshot.tax_id || String(c.tax_id ?? '').trim(),
          }
        }
      }
      if (!customerSnapshot.name) {
        return res.status(400).json({ success: false, error: 'customer_name is required' })
      }

      const company = await getCompany(pool, accountId)
      console.log('SNAPSHOT COMPANY BEFORE INSERT:', company)
      console.log('FINAL SNAPSHOT:', {
        name: company.name_th,
        address: company.address,
        phone: company.phone,
        logo: company.logo_url,
      })

      await client.query('BEGIN')

      const orderId = Date.now().toString()
      const primaryType = docTypes.includes('INV') ? 'INV' : docTypes[0]
      const legacyCompanyId = legacyCompanyIdForInsert(req)

      console.log('POST /documents tenant', { accountId })
      console.log('POST /documents docTypes', docTypes)
      console.log('POST /documents customerId', customerId)
      console.log('documents POST order_id:', orderId)
      const createdDocs = []

      for (const type of docTypes) {
        const now = new Date()
        const year = now.getFullYear()
        const month = String(now.getMonth() + 1).padStart(2, '0')
        const prefix = docTypeToPrefix(type)
        const { rows: countRows } = await safeQuery(
          client,
          `SELECT COUNT(*)::int AS count
           FROM documents
           WHERE account_id = $1::uuid
             AND EXTRACT(YEAR FROM doc_date) = $2`,
          [accountId, year],
        )
        const running = String(Number(countRows[0]?.count ?? 0) + 1).padStart(4, '0')
        const docNo = `${prefix}-${year}${month}-${running}`

        let insertSql
        let insertParams
        if (legacyCompanyId != null) {
          insertSql = `INSERT INTO documents (
      account_id, company_id, company_name, company_address, company_phone, company_tax_id, company_logo_url, customer_name, customer_address, customer_phone, customer_tax_id, doc_no, doc_type, doc_date,
      subtotal, vat_enabled, vat_rate, total, payment_status, status, order_id, note
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,COALESCE($14::date,CURRENT_DATE),$15,$16,$17,$18,'unpaid','draft',$19,$20)
    RETURNING id`
          insertParams = [
            accountId,
            legacyCompanyId,
            company.name_th,
            company.address,
            company.phone,
            company.tax_id,
            company.logo_url,
            customerSnapshot.name,
            customerSnapshot.address,
            customerSnapshot.phone,
            customerSnapshot.tax_id,
            docNo,
            prefix,
            docDate,
            subtotal,
            vatEnabled,
            vatRate,
            total,
            orderId,
            note,
          ]
        } else {
          insertSql = `INSERT INTO documents (
      account_id, company_name, company_address, company_phone, company_tax_id, company_logo_url, customer_name, customer_address, customer_phone, customer_tax_id, doc_no, doc_type, doc_date,
      subtotal, vat_enabled, vat_rate, total, payment_status, status, order_id, note
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,COALESCE($13::date,CURRENT_DATE),$14,$15,$16,$17,'unpaid','draft',$18,$19)
    RETURNING id`
          insertParams = [
            accountId,
            company.name_th,
            company.address,
            company.phone,
            company.tax_id,
            company.logo_url,
            customerSnapshot.name,
            customerSnapshot.address,
            customerSnapshot.phone,
            customerSnapshot.tax_id,
            docNo,
            prefix,
            docDate,
            subtotal,
            vatEnabled,
            vatRate,
            total,
            orderId,
            note,
          ]
        }

        let docRows
        try {
          const result = await safeQuery(client, insertSql, insertParams)
          docRows = result.rows
        } catch (err) {
          console.error('DOCUMENT INSERT ERROR:', err)
          throw err
        }

        const newDocId = docRows[0].id

        if (type === primaryType) {
          let lineNo = 1
          for (const it of normalizedItems) {
            await safeQuery(
              client,
              `INSERT INTO document_items (
        document_id, line_no, description, qty, unit_price, line_total
      ) VALUES ($1,$2,$3,$4,$5,$6)`,
              [
                newDocId,
                lineNo,
                it.description,
                it.qty,
                it.unitPrice,
                it.lineTotal,
              ],
              { skipAssert: true },
            )
            lineNo += 1
          }
        }

        createdDocs.push({
          id: newDocId,
          doc_no: docNo,
          doc_type: prefix,
          order_id: orderId,
        })
      }

      await client.query('COMMIT')
      committed = true

      try {
        await incrementDocumentUsage(pool, accountId, createdDocs.length)
      } catch (incErr) {
        console.error('incrementDocumentUsage:', incErr)
      }

      return res.status(201).json({
        success: true,
        data: {
          order_id: orderId,
          documents: createdDocs,
          subtotal,
          vat_rate: vatRate,
          vat_amount: vatAmount,
          total,
        },
      })
    } catch (err) {
      if (!committed) {
        await client.query('ROLLBACK')
      }
      console.error('DOCUMENT CREATE ERROR:', err)
      return res.status(500).json({
        success: false,
        error: err.message || 'Create document failed',
      })
    } finally {
      client.release()
    }
  } catch (err) {
    console.error('DOCUMENT CREATE ERROR:', err)
    return res.status(500).json({
      success: false,
      error: err.message || 'Create document failed',
    })
  }
})

export default router

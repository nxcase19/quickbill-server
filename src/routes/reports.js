import { Router } from 'express'
import ExcelJS from 'exceljs'
import { pool } from '../db.js'
import { buildTenantWhereClause, getAccountId } from '../utils/tenant.js'
import { logTenantAccess } from '../utils/tenantDebug.js'
import { requireAccountId, safeQuery } from '../utils/tenantQuery.js'
import { assertCanExport, assertCanUseTaxPurchase } from '../middleware/planGuards.js'

function getTimestamp() {
  const now = new Date()

  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')

  const hours = String(now.getHours()).padStart(2, '0')
  const minutes = String(now.getMinutes()).padStart(2, '0')

  return `${year}-${month}-${day}_${hours}-${minutes}`
}

/** Standard SaaS export names: {base}_YYYY-MM-DD_HH-mm.xlsx (server local time). */
function exportStandardXlsxFilename(baseName) {
  return `${baseName}_${getTimestamp()}.xlsx`
}

function buildPp30ExportFilename(month) {
  return `pp30-${month}-${getTimestamp()}.xlsx`
}

function round2(num) {
  return Math.round(Number(num) * 100) / 100
}

function toYmdLocal(d) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/**
 * @param {Record<string, string | undefined>} query
 * @returns {{ fromYmd: string, toYmd: string } | { error: string }}
 */
function resolveReportBounds(query) {
  const { period, from, to } = query

  let startDate
  let endDate

  if (period === 'day') {
    startDate = new Date()
    startDate.setHours(0, 0, 0, 0)
    endDate = new Date()
    endDate.setHours(23, 59, 59, 999)
  } else if (period === 'month') {
    startDate = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    startDate.setHours(0, 0, 0, 0)
    endDate = new Date()
    endDate.setHours(23, 59, 59, 999)
  } else if (period === 'year') {
    startDate = new Date(new Date().getFullYear(), 0, 1)
    startDate.setHours(0, 0, 0, 0)
    endDate = new Date()
    endDate.setHours(23, 59, 59, 999)
  } else if (period === 'custom') {
    if (!from || !to) {
      return { error: 'period=custom requires from and to' }
    }
    startDate = new Date(from)
    startDate.setHours(0, 0, 0, 0)
    endDate = new Date(to)
    endDate.setHours(23, 59, 59, 999)
  } else if (from && to) {
    startDate = new Date(from)
    startDate.setHours(0, 0, 0, 0)
    endDate = new Date(to)
    endDate.setHours(23, 59, 59, 999)
  } else {
    return { error: 'missing period or from/to' }
  }

  if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
    return { error: 'invalid from/to date' }
  }

  return {
    fromYmd: toYmdLocal(startDate),
    toYmd: toYmdLocal(endDate),
  }
}

const router = Router()

router.get('/summary', async (req, res) => {
  try {
    requireAccountId(req)

    logTenantAccess('GET /api/reports/summary', req)

    const { period, from, to } = req.query
    const bounds = resolveReportBounds(req.query)
    if ('error' in bounds) {
      return res.status(400).json({ error: bounds.error })
    }
    const { fromYmd, toYmd } = bounds

    const tw = buildTenantWhereClause(req, 'd', 1)
    const params = [tw.param, fromYmd, toYmd]

    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate')
    res.set('Pragma', 'no-cache')
    res.set('Expires', '0')
    res.set('Surrogate-Control', 'no-store')

    let result
    try {
      result = await safeQuery(
        pool,
        `SELECT
          ROUND(COALESCE(SUM(d.total), 0)::numeric, 2) AS total_amount,
          ROUND(
            COALESCE(
              SUM(CASE WHEN d.status = 'paid' THEN d.total ELSE 0 END),
              0
            )::numeric,
            2
          ) AS paid_amount,
          ROUND(
            COALESCE(
              SUM(CASE WHEN d.status != 'paid' THEN d.total ELSE 0 END),
              0
            )::numeric,
            2
          ) AS unpaid_amount
        FROM documents d
        WHERE ${tw.clause}
          AND d.doc_type = 'RC'
          AND d.doc_date::date BETWEEN $2::date AND $3::date`,
        params,
      )
    } catch (dbErr) {
      console.error('SUPABASE ERROR:', dbErr)
      return res.status(200).json({
        total_amount: 0,
        paid_amount: 0,
        unpaid_amount: 0,
      })
    }

    const agg = result?.rows?.[0] || {}
    const total_amount = round2(agg.total_amount)
    const paid_amount = round2(agg.paid_amount)
    const unpaid_amount = round2(agg.unpaid_amount)

    console.log('[reports/summary]', {
      period: period ?? null,
      from: from ?? null,
      to: to ?? null,
      fromYmd,
      toYmd,
      account_id: getAccountId(req),
      total_amount,
      paid_amount,
      unpaid_amount,
    })

    res.json({
      total_amount,
      paid_amount,
      unpaid_amount,
    })
  } catch (error) {
    if (error?.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('SUMMARY ERROR:', error)
    return res.status(200).json({
      total_amount: 0,
      paid_amount: 0,
      unpaid_amount: 0,
    })
  }
})

router.get('/vat-summary', async (req, res) => {
  try {
    requireAccountId(req)

    const { period, from, to } = req.query
    const bounds = resolveReportBounds(req.query)
    if ('error' in bounds) {
      return res.status(400).json({ error: bounds.error })
    }
    const { fromYmd, toYmd } = bounds

    const twDoc = buildTenantWhereClause(req, 'd', 1)
    const twPur = buildTenantWhereClause(req, 'p', 1)
    const salesParams = [twDoc.param, fromYmd, toYmd]
    const purchaseParams = [twPur.param, fromYmd, toYmd]

    const [{ rows: salesRows }, { rows: purchaseRows }] = await Promise.all([
      safeQuery(
        pool,
        `SELECT
          ROUND(
            COALESCE(
              SUM(
                CASE
                  WHEN COALESCE(d.vat_enabled, false) = true
                  THEN COALESCE(d.subtotal, 0) * COALESCE(d.vat_rate, 0)
                  ELSE 0
                END
              ),
              0
            )::numeric,
            2
          ) AS vat_sales
        FROM documents d
        WHERE ${twDoc.clause}
          AND d.doc_type = 'RC'
          AND d.doc_date::date BETWEEN $2::date AND $3::date`,
        salesParams,
      ),
      safeQuery(
        pool,
        `SELECT
          ROUND(COALESCE(SUM(COALESCE(p.vat_amount, 0)), 0)::numeric, 2) AS vat_purchase
        FROM purchase_invoices p
        WHERE ${twPur.clause}
          AND p.doc_date::date BETWEEN $2::date AND $3::date
          AND (COALESCE(p.status, 'active') = 'active')
          AND (COALESCE(p.document_status, 'issued') = 'issued')`,
        purchaseParams,
      ),
    ])

    const vat_sales = round2(salesRows[0]?.vat_sales)
    const vat_purchase = round2(purchaseRows[0]?.vat_purchase)
    const vat_payable = round2(vat_sales - vat_purchase)

    console.log('[reports/vat-summary]', {
      period: period ?? null,
      from: from ?? null,
      to: to ?? null,
      fromYmd,
      toYmd,
      account_id: getAccountId(req),
      vat_sales,
      vat_purchase,
      vat_payable,
    })

    res.json({
      vat_sales,
      vat_purchase,
      vat_payable,
    })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('vat-summary error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/export', assertCanExport, async (req, res) => {
  try {
    requireAccountId(req)

    logTenantAccess('GET /api/reports/export', req)

    const { status, from, to, period, doc_type, vat } = req.query

    const [{ rows: docCols }, { rows: payCols }] = await Promise.all([
      safeQuery(
        pool,
        `SELECT column_name
         FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'documents'
           AND column_name = 'vat_enabled'
         LIMIT 1`,
        [],
        { skipAssert: true },
      ),
      safeQuery(
        pool,
        `SELECT column_name
         FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'payments'
           AND column_name = 'payment_date'
         LIMIT 1`,
        [],
        { skipAssert: true },
      ),
    ])
    const hasVatEnabled = docCols.length > 0
    const hasPaymentDate = payCols.length > 0

    const vatSelect = hasVatEnabled ? 'd.vat_enabled' : 'false AS vat_enabled'
    const paymentSelect = hasPaymentDate
      ? 'MAX(p.payment_date) AS payment_date'
      : 'NULL AS payment_date'
    const paymentJoin = hasPaymentDate
      ? `LEFT JOIN payments p
        ON p.order_id = d.order_id AND p.account_id = d.account_id`
      : ''

    const tw = buildTenantWhereClause(req, 'd', 1)
    let sql = `
      SELECT
        d.doc_no,
        d.doc_type,
        d.customer_name,
        d.total,
        ${vatSelect},
        d.paid_amount,
        d.status,
        d.doc_date,
        ${paymentSelect}
      FROM documents d
      ${paymentJoin}
      WHERE ${tw.clause}
    `
    const params = [tw.param]

    if (status === 'paid') {
      sql += ` AND d.status = 'paid'`
    } else if (status === 'unpaid') {
      sql += ` AND d.status != 'paid'`
    }

    if (doc_type) {
      params.push(doc_type)
      sql += ` AND d.doc_type = $${params.length}`
    }

    if (vat === 'vat_only' && hasVatEnabled) {
      sql += ` AND d.vat_enabled = true`
    } else if (vat === 'no_vat' && hasVatEnabled) {
      sql += ` AND (d.vat_enabled = false OR d.vat_enabled IS NULL)`
    }

    if (period === 'day') {
      sql += ` AND d.doc_date = CURRENT_DATE`
    } else if (period === 'month') {
      sql += ` AND date_trunc('month', d.doc_date) = date_trunc('month', CURRENT_DATE)`
    } else if (period === 'year') {
      sql += ` AND date_trunc('year', d.doc_date) = date_trunc('year', CURRENT_DATE)`
    }

    if (from && to) {
      params.push(from, to)
      sql += ` AND d.doc_date BETWEEN $${params.length - 1} AND $${params.length}`
    }

    sql += `
      GROUP BY
        d.id,
        d.doc_no,
        d.doc_type,
        d.customer_name,
        d.total,
        ${hasVatEnabled ? 'd.vat_enabled,' : ''}
        d.paid_amount,
        d.status,
        d.doc_date
      ORDER BY d.doc_date DESC
    `

    console.log(sql, params)
    const { rows } = await safeQuery(pool, sql, params)

    const workbook = new ExcelJS.Workbook()
    const sheet = workbook.addWorksheet('Sales')

    sheet.addRow(['รายงานยอดขาย'])
    sheet.addRow([`วันที่: ${from || '-'} ถึง ${to || '-'}`])
    sheet.addRow([])

    sheet.getRow(1).font = { bold: true, size: 16 }
    sheet.getRow(2).font = { size: 12 }

    sheet.addRow([
      'เลขที่เอกสาร',
      'ประเภท',
      'ลูกค้า',
      'ยอดรวม',
      'VAT',
      'จ่ายแล้ว',
      'สถานะ',
      'วันที่',
      'วันที่จ่ายเงิน',
    ])

    const headerRow = sheet.getRow(4)
    headerRow.font = { bold: true }

    rows.forEach((r) => {
      sheet.addRow([
        r.doc_no,
        r.doc_type,
        r.customer_name,
        r.total,
        r.vat_enabled ? 'มี VAT' : 'ไม่มี VAT',
        r.paid_amount,
        r.status,
        r.doc_date,
        r.payment_date || '-',
      ])
    })

    sheet.getColumn(4).numFmt = '#,##0.00'
    sheet.getColumn(6).numFmt = '#,##0.00'

    sheet.columns.forEach((col) => {
      col.width = 20
    })

    const totalSum = rows.reduce((sum, r) => sum + Number(r.total || 0), 0)
    sheet.addRow([])
    sheet.addRow(['รวมทั้งหมด', '', '', totalSum])

    sheet.getRow(sheet.lastRow.number).font = { bold: true }

    const filename = exportStandardXlsxFilename('documents')
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    )
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition')
    res.setHeader('Content-Disposition', `attachment; filename=${filename}`)

    await workbook.xlsx.write(res)
    res.end()
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('EXPORT ERROR:', err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/tax-receipts', async (req, res) => {
  try {
    const accountId = requireAccountId(req)

    const tw = buildTenantWhereClause(req, '', 1)
    const { rows } = await safeQuery(
      pool,
      `SELECT
      id,
      doc_no,
      doc_type,
      doc_date,
      total,
      paid_amount,
      status AS payment_status
    FROM documents
    WHERE ${tw.clause}
      AND doc_type = 'RC'
      AND paid_amount >= total
    ORDER BY id DESC`,
      [tw.param],
    )
    res.json(rows)
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error(err)
    res.status(500).json({ error: 'Internal server error' })
  }
})

router.get('/vat-sales', async (req, res) => {
  try {
    requireAccountId(req)

    const { from, to } = req.query

    const tw = buildTenantWhereClause(req, 'd', 1)
    let sql = `
      SELECT
        d.doc_date,
        d.doc_no,
        d.customer_name,
        d.subtotal,
        d.vat_rate,
        d.total,
        (d.total - d.subtotal) AS vat_amount
      FROM documents d
      WHERE ${tw.clause}
        AND d.vat_enabled = true
        AND d.doc_type = 'RC'
        AND d.paid_amount >= d.total
    `

    const params = [tw.param]

    if (from) {
      sql += ` AND d.doc_date >= $${params.length + 1}`
      params.push(from)
    }

    if (to) {
      sql += ` AND d.doc_date <= $${params.length + 1}`
      params.push(to)
    }

    sql += ` ORDER BY d.doc_date ASC`

    const { rows } = await safeQuery(pool, sql, params)

    res.json(rows)
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('vat-sales error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/vat-sales/export', assertCanExport, async (req, res) => {
  try {
    requireAccountId(req)

    const tw = buildTenantWhereClause(req, 'd', 1)
    const { rows } = await safeQuery(
      pool,
      `
      SELECT
        d.doc_date,
        d.doc_no,
        d.customer_name,
        d.subtotal,
        (d.total - d.subtotal) AS vat_amount,
        d.total
      FROM documents d
      WHERE ${tw.clause}
        AND d.vat_enabled = true
        AND d.doc_type = 'RC'
        AND d.paid_amount >= d.total
      ORDER BY d.doc_date ASC
    `,
      [tw.param],
    )

    const workbook = new ExcelJS.Workbook()
    const sheet = workbook.addWorksheet('VAT Sales')

    sheet.columns = [
      { header: 'วันที่', key: 'doc_date', width: 15 },
      { header: 'เลขที่เอกสาร', key: 'doc_no', width: 20 },
      { header: 'ลูกค้า', key: 'customer_name', width: 28 },
      { header: 'ยอดก่อนภาษี', key: 'subtotal', width: 15 },
      { header: 'ภาษี', key: 'vat_amount', width: 15 },
      { header: 'รวม', key: 'total', width: 15 },
    ]

    rows.forEach((r) => {
      sheet.addRow({
        doc_date: r.doc_date,
        doc_no: r.doc_no,
        customer_name: r.customer_name,
        subtotal: r.subtotal,
        vat_amount: r.vat_amount,
        total: r.total,
      })
    })

    sheet.getRow(1).font = { bold: true }
    sheet.getColumn('subtotal').numFmt = '#,##0.00'
    sheet.getColumn('vat_amount').numFmt = '#,##0.00'
    sheet.getColumn('total').numFmt = '#,##0.00'

    const filename = exportStandardXlsxFilename('salevat')
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    )
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition')
    res.setHeader('Content-Disposition', `attachment; filename=${filename}`)

    await workbook.xlsx.write(res)
    res.end()
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error(err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/vat-purchase/export', assertCanExport, assertCanUseTaxPurchase, async (req, res) => {
  try {
    requireAccountId(req)

    logTenantAccess('GET /api/reports/vat-purchase/export', req, {
      from: req.query.from,
      to: req.query.to,
    })

    const { from, to } = req.query
    const tw = buildTenantWhereClause(req, 'p', 1)
    const purchaseDateExpr = `COALESCE(p.doc_date, (p.created_at)::date)`

    const { rows: allCountRows } = await safeQuery(
      pool,
      `SELECT COUNT(*)::int AS n FROM purchase_invoices p WHERE ${tw.clause}`,
      [tw.param],
    )
    const allRows = { length: Number(allCountRows[0]?.n ?? 0) }
    console.log('ALL PURCHASE RECORDS:', allRows.length)

    const { rows: filteredCountRows } = await safeQuery(
      pool,
      `SELECT COUNT(*)::int AS n FROM purchase_invoices p
       WHERE ${tw.clause}
         AND LOWER(COALESCE(p.status, 'active')) IN ('active', 'paid')
         AND LOWER(TRIM(COALESCE(p.document_status::text, 'issued'))) <> 'cancelled'
         AND (p.deleted_at IS NULL)`,
      [tw.param],
    )
    const filteredRows = { length: Number(filteredCountRows[0]?.n ?? 0) }
    console.log('AFTER TYPE FILTER:', filteredRows.length)

    const { rows: vatCountRows } = await safeQuery(
      pool,
      `SELECT COUNT(*)::int AS n FROM purchase_invoices p
       WHERE ${tw.clause}
         AND LOWER(COALESCE(p.status, 'active')) IN ('active', 'paid')
         AND LOWER(TRIM(COALESCE(p.document_status::text, 'issued'))) <> 'cancelled'
         AND COALESCE(p.vat_amount, 0) > 0
         AND (p.deleted_at IS NULL)`,
      [tw.param],
    )
    const vatRows = { length: Number(vatCountRows[0]?.n ?? 0) }
    console.log('AFTER VAT FILTER:', vatRows.length)

    const { rows: vatSampleRows } = await safeQuery(
      pool,
      `SELECT p.doc_date, p.doc_no, p.supplier_name, p.subtotal, p.vat_amount, p.total
       FROM purchase_invoices p
       WHERE ${tw.clause}
         AND LOWER(COALESCE(p.status, 'active')) IN ('active', 'paid')
         AND LOWER(TRIM(COALESCE(p.document_status::text, 'issued'))) <> 'cancelled'
         AND COALESCE(p.vat_amount, 0) > 0
         AND (p.deleted_at IS NULL)
       LIMIT 1`,
      [tw.param],
    )
    console.log('SAMPLE ROW:', vatSampleRows[0] ?? null)

    let sql = `
      SELECT
        p.doc_date,
        p.doc_no,
        p.supplier_name,
        p.subtotal,
        p.vat_amount,
        p.total
      FROM purchase_invoices p
      WHERE ${tw.clause}
        AND LOWER(COALESCE(p.status, 'active')) IN ('active', 'paid')
        AND LOWER(TRIM(COALESCE(p.document_status::text, 'issued'))) <> 'cancelled'
        AND COALESCE(p.vat_amount, 0) > 0
        AND (p.deleted_at IS NULL)
    `
    const params = [tw.param]

    if (from && to) {
      sql += ` AND ${purchaseDateExpr} >= $${params.length + 1}::date AND ${purchaseDateExpr} <= $${params.length + 2}::date`
      params.push(String(from).slice(0, 10), String(to).slice(0, 10))
    } else if (from) {
      sql += ` AND ${purchaseDateExpr} >= $${params.length + 1}::date`
      params.push(String(from).slice(0, 10))
    } else if (to) {
      sql += ` AND ${purchaseDateExpr} <= $${params.length + 1}::date`
      params.push(String(to).slice(0, 10))
    }

    sql += ` ORDER BY ${purchaseDateExpr} ASC NULLS LAST, p.id ASC`

    const { rows } = await safeQuery(pool, sql, params)
    console.log('purchase vat rows:', rows.length)

    const workbook = new ExcelJS.Workbook()
    const sheet = workbook.addWorksheet('VAT Purchase')

    sheet.columns = [
      { header: 'วันที่', key: 'doc_date', width: 14 },
      { header: 'เลขเอกสาร', key: 'doc_no', width: 20 },
      { header: 'ผู้ขาย', key: 'supplier_name', width: 28 },
      { header: 'ยอดก่อนภาษี', key: 'subtotal', width: 16 },
      { header: 'VAT', key: 'vat_amount', width: 14 },
      { header: 'รวม', key: 'total', width: 16 },
    ]

    rows.forEach((r) => {
      sheet.addRow({
        doc_date: r.doc_date,
        doc_no: r.doc_no,
        supplier_name: r.supplier_name,
        subtotal: r.subtotal,
        vat_amount: r.vat_amount,
        total: r.total,
      })
    })

    sheet.getRow(1).font = { bold: true }
    sheet.getColumn('subtotal').numFmt = '#,##0.00'
    sheet.getColumn('vat_amount').numFmt = '#,##0.00'
    sheet.getColumn('total').numFmt = '#,##0.00'

    const filename = exportStandardXlsxFilename('purchasevat')
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    )
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition')
    res.setHeader('Content-Disposition', `attachment; filename=${filename}`)

    await workbook.xlsx.write(res)
    res.end()
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('vat-purchase/export error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/pp30', async (req, res) => {
  try {
    const accountId = requireAccountId(req)
    const { month } = req.query // format: 2026-03

    logTenantAccess('GET /api/reports/pp30', req, { month })

    if (!month) {
      return res.status(400).json({ error: 'month is required (YYYY-MM)' })
    }

    const [year, m] = String(month).split('-').map(Number)

    const from = `${year}-${String(m).padStart(2, '0')}-01`
    const nextYear = m === 12 ? year + 1 : year
    const nextMonth = m === 12 ? 1 : m + 1
    const to = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`
    console.log('PP30 ACCOUNT_ID:', accountId)
    console.log('PP30 RANGE:', { from, to })

    const twDoc = buildTenantWhereClause(req, 'd', 1)
    const twPur = buildTenantWhereClause(req, '', 1)
    // VAT ขาย (RC + VAT + fully paid); half-open date range [from, to)
    const sales = await safeQuery(
      pool,
      `
      SELECT
        COALESCE(SUM(subtotal),0) as total_sales,
        COALESCE(SUM(total - subtotal),0) as vat_sales
      FROM documents d
      WHERE ${twDoc.clause}
        AND d.doc_type = 'RC'
        AND d.vat_enabled = true
        AND d.paid_amount >= d.total
        AND d.doc_date >= $2
        AND d.doc_date < $3
    `,
      [twDoc.param, from, to],
    )

    const purchase = await safeQuery(
      pool,
      `
      SELECT
        COALESCE(SUM(vat_amount),0) as vat_purchase
      FROM purchase_invoices
      WHERE ${twPur.clause}
        AND (COALESCE(status, 'active') = 'active')
        AND (COALESCE(document_status, 'issued') = 'issued')
        AND doc_date >= $2
        AND doc_date < $3
    `,
      [twPur.param, from, to],
    )
    console.log('PP30 SALES:', sales.rows[0])
    console.log('PP30 PURCHASE:', purchase.rows[0])

    const totalSales = Number(sales.rows[0].total_sales)
    const vatSales = Number(sales.rows[0].vat_sales)
    const vatPurchase = Number(purchase.rows[0].vat_purchase)

    res.json({
      month,
      total_sales: totalSales,
      vat_sales: vatSales,
      vat_purchase: vatPurchase,
      vat_payable: vatSales - vatPurchase,
    })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('pp30 error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.get('/pp30/export', assertCanExport, async (req, res) => {
  try {
    const accountId = requireAccountId(req)
    const { month } = req.query

    logTenantAccess('GET /api/reports/pp30/export', req, { month })

    if (!month) {
      return res.status(400).json({ error: 'month is required (YYYY-MM)' })
    }

    const [year, m] = String(month).split('-').map(Number)

    const from = `${year}-${String(m).padStart(2, '0')}-01`
    const nextYear = m === 12 ? year + 1 : year
    const nextMonth = m === 12 ? 1 : m + 1
    const to = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`
    console.log('PP30 FILTER:', { from, to })

    const twDoc = buildTenantWhereClause(req, 'd', 1)
    const twPur = buildTenantWhereClause(req, '', 1)
    const sales = await safeQuery(
      pool,
      `
      SELECT
        COALESCE(SUM(subtotal),0) as total_sales,
        COALESCE(SUM(total - subtotal),0) as vat_sales
      FROM documents d
      WHERE ${twDoc.clause}
        AND d.doc_type = 'RC'
        AND d.vat_enabled = true
        AND d.paid_amount >= d.total
        AND d.doc_date >= $2
        AND d.doc_date < $3
    `,
      [twDoc.param, from, to],
    )

    const purchase = await safeQuery(
      pool,
      `
      SELECT
        COALESCE(SUM(vat_amount),0) as vat_purchase
      FROM purchase_invoices
      WHERE ${twPur.clause}
        AND (COALESCE(status, 'active') = 'active')
        AND (COALESCE(document_status, 'issued') = 'issued')
        AND doc_date >= $2
        AND doc_date < $3
    `,
      [twPur.param, from, to],
    )
    console.log('PP30 RESULT:', sales.rows.length)

    const totalSales = Number(sales.rows[0].total_sales || 0)
    const vatSales = Number(sales.rows[0].vat_sales || 0)
    const vatPurchase = Number(purchase.rows[0].vat_purchase || 0)
    const vatPayable = vatSales - vatPurchase

    const workbook = new ExcelJS.Workbook()
    const sheet = workbook.addWorksheet('PP30')

    sheet.columns = [
      { header: 'รายการ', key: 'item', width: 28 },
      { header: 'จำนวน', key: 'amount', width: 20 },
    ]

    sheet.addRow({ item: 'ยอดขายก่อนภาษี', amount: totalSales })
    sheet.addRow({ item: 'ภาษีขาย', amount: vatSales })
    sheet.addRow({ item: 'ภาษีซื้อ', amount: vatPurchase })
    sheet.addRow({ item: 'ภาษีที่ต้องชำระ', amount: vatPayable })

    sheet.getRow(1).font = { bold: true }
    sheet.getColumn('amount').numFmt = '#,##0.00'
    sheet.getRow(5).font = { bold: true }

    const filename = buildPp30ExportFilename(month)
    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    )
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition')
    res.setHeader('Content-Disposition', `attachment; filename=${filename}`)

    await workbook.xlsx.write(res)
    res.end()
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('pp30 export error:', err)
    res.status(500).json({ error: err.message })
  }
})

export default router

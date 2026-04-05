/**
 * Central report date filtering (SQL only — no JS date bounds in WHERE).
 * @param {object} opts
 * @param {string|undefined} opts.period day | month | year | custom
 * @param {string|undefined} opts.from
 * @param {string|undefined} opts.to
 * @param {string} opts.column SQL expression for the effective document date, e.g. COALESCE(d.doc_date, (d.created_at)::date)
 * @param {number} opts.startParamIndex first $ placeholder index for custom range (e.g. 2 when $1 is tenant)
 * @returns {{ sql: string, params: unknown[] }}
 */
export function buildReportDateFilter({
  period,
  from,
  to,
  column,
  startParamIndex,
}) {
  const p = String(period ?? '').trim()
  if (!p) {
    const e = new Error('invalid period')
    e.reportFilterCode = 'INVALID_PERIOD'
    throw e
  }

  const col = `(${column})`

  if (p === 'day') {
    return {
      sql: ` AND ${col}::date = CURRENT_DATE`,
      params: [],
    }
  }

  if (p === 'month') {
    return {
      sql: ` AND DATE_TRUNC('month', ${col}::timestamp) = DATE_TRUNC('month', CURRENT_TIMESTAMP)`,
      params: [],
    }
  }

  if (p === 'year') {
    return {
      sql: ` AND DATE_TRUNC('year', ${col}::timestamp) = DATE_TRUNC('year', CURRENT_TIMESTAMP)`,
      params: [],
    }
  }

  if (p === 'custom') {
    if (!from || !to || String(from).trim() === '' || String(to).trim() === '') {
      const e = new Error('missing from/to')
      e.reportFilterCode = 'MISSING_FROM_TO'
      throw e
    }
    const a = startParamIndex
    const b = startParamIndex + 1
    return {
      sql: ` AND ${col}::date BETWEEN $${a}::date AND $${b}::date`,
      params: [String(from).trim().slice(0, 10), String(to).trim().slice(0, 10)],
    }
  }

  const e = new Error('invalid period')
  e.reportFilterCode = 'INVALID_PERIOD'
  throw e
}

/**
 * Canonical RC sales scope (documents), reusable in summary / vat-summary / exports.
 * @param {{ alias?: string }} [opts]
 * @returns {string} SQL AND-fragment (starts with " AND ...")
 */
export function buildRcSalesWhereClause({ alias = 'd' } = {}) {
  const a = alias
  return ` AND ${a}.doc_type = 'RC'
      AND LOWER(COALESCE(${a}.status, '')) <> 'cancelled'`
}

/**
 * VAT amount from sales documents (no vat_amount column on documents).
 * @param {string} [alias]
 * @returns {string} SQL expression
 */
export function getVatSalesSqlExpression(alias = 'd') {
  const x = alias
  return `CASE
    WHEN ${x}.vat_enabled IS TRUE THEN COALESCE(${x}.subtotal, 0) * COALESCE(${x}.vat_rate, 0)
    ELSE 0
  END`
}

function toYmdLocal(d) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/**
 * Human-readable range for export sheet subtitles only (not used in WHERE).
 * Call after period validation succeeds.
 */
export function getExportSheetDateRangeLabels(query) {
  const { period, from, to } = query
  const p = String(period ?? '').trim()
  const now = new Date()

  if (p === 'custom' && from && to) {
    return {
      fromYmd: String(from).trim().slice(0, 10),
      toYmd: String(to).trim().slice(0, 10),
    }
  }
  if (p === 'day') {
    const y = toYmdLocal(now)
    return { fromYmd: y, toYmd: y }
  }
  if (p === 'month') {
    const start = new Date(now.getFullYear(), now.getMonth(), 1)
    return { fromYmd: toYmdLocal(start), toYmd: toYmdLocal(now) }
  }
  if (p === 'year') {
    const start = new Date(now.getFullYear(), 0, 1)
    return { fromYmd: toYmdLocal(start), toYmd: toYmdLocal(now) }
  }
  return { fromYmd: '', toYmd: '' }
}

export function mapReportDateFilterError(err) {
  const code = err?.reportFilterCode
  if (code === 'MISSING_FROM_TO') {
    return { status: 400, body: { error: 'missing from/to' } }
  }
  if (code === 'INVALID_PERIOD') {
    return { status: 400, body: { error: 'invalid period' } }
  }
  return null
}

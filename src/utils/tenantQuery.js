/**
 * App-layer tenant isolation helpers.
 *
 * Source of truth is req.account_id (set by auth middleware). Query/header/body
 * values must never override tenant identity for protected routes.
 */

/** @type {readonly string[]} Tables that store per-account business data (tenant-owned). */
export const TENANT_OWNED_TABLES = Object.freeze([
  'customers',
  'documents',
  'document_items',
  'payments',
  'purchase_invoices',
  'purchase_orders',
  'purchase_order_items',
  'invoices',
  'invoice_items',
  'company_settings',
  'products',
])

const isDev = process.env.NODE_ENV !== 'production'

function normalizeAccountIdValue(v) {
  if (v === undefined || v === null || v === '') return null
  const s = typeof v === 'string' ? v.trim() : String(v).trim()
  return s || null
}

function readAccountIdFromReq(req) {
  const fromReq = normalizeAccountIdValue(req.account_id)
  if (fromReq) return fromReq

  const fromJwt = normalizeAccountIdValue(req.user?.account_id)
  if (fromJwt) return fromJwt
  return null
}

/**
 * Returns tenant account_id from auth middleware context or throws.
 * company_id must not be used for access control — legacy only.
 * @param {import('express').Request} req
 * @returns {string}
 */
export function requireAccountId(req) {
  const id = readAccountIdFromReq(req)
  if (id == null || id === '') {
    throw new Error('Missing account_id')
  }
  return id
}

/** @deprecated use requireAccountId */
export function resolveAccountIdForPdfRoute(req) {
  return readAccountIdFromReq(req)
}

/**
 * SQL fragment + bound params for a single tenant column predicate.
 * @param {import('express').Request} req
 * @param {string} [alias] Table alias, e.g. 'd' → "d.account_id = $n"
 * @param {number} [paramIndex] 1-based placeholder index
 * @returns {{ clause: string, params: string[] }}
 */
export function tenantClause(req, alias = '', paramIndex = 1) {
  const accountId = requireAccountId(req)
  const prefix = alias ? `${alias}.` : ''
  return {
    clause: `${prefix}account_id = $${paramIndex}`,
    params: [accountId],
  }
}

/**
 * Development-only guardrails for raw SQL strings.
 * @param {string} sql
 */
export function assertTenantSql(sql) {
  if (!isDev || typeof sql !== 'string') return
  const s = sql.trim()
  if (s.length === 0) return
  if (s.includes('information_schema') || s.includes('pg_catalog')) return

  if (!s.includes('account_id')) {
    console.warn('⚠️ [tenant] SQL missing account_id substring:', s.slice(0, 400))
  }

  const lower = s.toLowerCase()
  for (const table of TENANT_OWNED_TABLES) {
    const re = new RegExp(`\\b(from|join|into|update)\\s+${table}\\b`, 'i')
    if (re.test(lower) && !s.includes('account_id')) {
      console.warn(
        `⚠️ [tenant] Query may touch "${table}" without an account_id predicate in the SQL text.`,
      )
    }
  }
}

/**
 * Run a query with optional dev-time tenant assertions.
 * @param {import('pg').Pool | import('pg').PoolClient} poolOrClient
 * @param {string} sql
 * @param {unknown[]} [params]
 * @param {{ skipAssert?: boolean }} [options] Use skipAssert for non-tenant queries (e.g. auth by email, schema introspection).
 */
export function safeQuery(poolOrClient, sql, params = [], options = {}) {
  if (!options.skipAssert) {
    assertTenantSql(sql)
  }
  return poolOrClient.query(sql, params)
}

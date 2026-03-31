/**
 * Tenant helpers: account_id (UUID string) is the primary tenant key.
 * company_id is legacy metadata only — not used for access isolation in new code.
 * Never coerce account_id / company_id with Number() — use as bound params as-is.
 */

import { tenantClause } from './tenantQuery.js'

export function getAccountId(req) {
  const v = req.account_id ?? req.user?.account_id
  if (v === undefined || v === null || v === '') return null
  return typeof v === 'string' ? v.trim() || null : String(v)
}

export function getCompanyId(req) {
  const v = req.user?.company_id
  if (v === undefined || v === null || v === '') return null
  return typeof v === 'string' ? v.trim() || null : String(v)
}

export function hasAccountId(req) {
  return getAccountId(req) != null
}

/**
 * Tenant SQL fragment: always `account_id` (never `company_id`) for multi-tenant isolation.
 * Delegates to tenantClause — requires account_id on req (throws if missing).
 *
 * @param {import('express').Request} req
 * @param {string} tableAlias - e.g. 'd' → "d.account_id = $n"; '' → "account_id = $n"
 * @param {number} paramIndex - 1-based placeholder index for pg
 * @returns {{ clause: string, param: unknown }}
 */
export function buildTenantWhereClause(req, tableAlias, paramIndex) {
  const t = tenantClause(req, tableAlias, paramIndex)
  return { clause: t.clause, param: t.params[0] }
}

/** @deprecated use buildTenantWhereClause */
export const tenantWhereClause = buildTenantWhereClause

/** @deprecated use getAccountId */
export function accountIdFromUser(req) {
  return getAccountId(req)
}

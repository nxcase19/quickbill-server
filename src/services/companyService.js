import { safeQuery } from '../utils/tenantQuery.js'
import { fetchAccountBillingRow, getEffectivePlan } from '../utils/planService.js'

/**
 * Canonical company header from company_settings (company_name is the only name source).
 * Plan comes from joined accounts row (same billing fields as auth / planService).
 */
const COMPANY_HEADER_SQL = `
  SELECT
    cs.company_name,
    cs.address,
    cs.phone,
    cs.tax_id,
    cs.logo_url,
    cs.signature_url,
    cs.auto_signature_enabled,
    cs.date_format,
    a.plan_type AS account_plan_type,
    a.trial_started_at,
    a.trial_ends_at,
    a.subscription_id,
    a.subscription_ends_at,
    a.cancel_at_period_end
  FROM company_settings cs
  LEFT JOIN accounts a ON a.id = cs.account_id
  WHERE cs.account_id = $1::uuid
  ORDER BY cs.updated_at DESC NULLS LAST, cs.id DESC
  LIMIT 1
`

/** Older DBs: missing column in main SELECT — full row; map uses only canonical fields. */
const COMPANY_HEADER_SQL_FALLBACK = `
  SELECT *
  FROM company_settings
  WHERE account_id = $1::uuid
  ORDER BY id DESC
  LIMIT 1
`

/** Header used when company_settings is missing or not yet filled (no hard block on documents). */
export function genericCompanyHeader() {
  return {
    name_th: '',
    address: '',
    phone: '',
    tax_id: '',
    logo_url: null,
    signature_url: null,
    auto_signature_enabled: true,
    date_format: 'thai',
  }
}

/**
 * Map a company_settings row to the canonical header shape.
 * Empty company_name is allowed (onboarding incomplete).
 * @param {Record<string, unknown> | null | undefined} row
 * @returns {{ name_th: string, address: string, phone: string, tax_id: string, logo_url: string | null, signature_url?: string | null, auto_signature_enabled?: boolean, date_format?: string } | null}
 */
export function mapCompanyFromRow(row) {
  if (!row) return null

  const name_th = String(row.company_name ?? '').trim()

  const logo_url =
    row.logo_url && String(row.logo_url).trim() !== ''
      ? String(row.logo_url).trim()
      : null

  const signature_url =
    row.signature_url != null && String(row.signature_url).trim() !== ''
      ? String(row.signature_url).trim()
      : null

  return {
    name_th,
    address: row.address != null ? String(row.address) : '',
    phone: row.phone != null ? String(row.phone) : '',
    tax_id: row.tax_id != null ? String(row.tax_id) : '',
    logo_url,
    signature_url,
    auto_signature_enabled: row.auto_signature_enabled !== false,
    date_format: ['thai', 'iso', 'business'].includes(String(row.date_format ?? ''))
      ? String(row.date_format)
      : 'thai',
  }
}

/**
 * @param {Record<string, unknown> | null | undefined} row
 */
function billingAccountFromJoinedRow(row) {
  if (!row) return null
  return {
    plan_type: row.account_plan_type ?? row.plan_type,
    trial_started_at: row.trial_started_at,
    trial_ends_at: row.trial_ends_at,
    subscription_id: row.subscription_id,
    subscription_ends_at: row.subscription_ends_at,
    cancel_at_period_end: row.cancel_at_period_end,
  }
}

/**
 * @param {Record<string, unknown>} header
 * @param {object | null} billingAccount
 */
function withResolvedPlan(header, billingAccount) {
  const eff = getEffectivePlan(billingAccount)
  const company = { ...header, plan: eff }
  company.plan = company.plan || 'free'
  console.log('CHECK PLAN:', company.plan)
  return company
}

/**
 * Load normalized company header for PDFs and PO/document snapshots.
 * @param {import('pg').Pool | import('pg').PoolClient} poolOrClient
 * @param {string} accountId
 * @returns {Promise<{ name_th: string, address: string, phone: string, tax_id: string, logo_url: string | null, plan: string }>}
 */
export async function getCompany(poolOrClient, accountId) {
  const empty = genericCompanyHeader()
  try {
    const { rows } = await safeQuery(poolOrClient, COMPANY_HEADER_SQL, [accountId])
    if (!rows[0]) {
      const billing = await fetchAccountBillingRow(poolOrClient, accountId)
      return withResolvedPlan({ ...empty }, billing)
    }
    const mapped = mapCompanyFromRow(rows[0])
    if (!mapped) {
      const billing = await fetchAccountBillingRow(poolOrClient, accountId)
      return withResolvedPlan({ ...empty }, billing)
    }
    return withResolvedPlan(mapped, billingAccountFromJoinedRow(rows[0]))
  } catch (err) {
    if (err && err.code === '42703') {
      const { rows } = await safeQuery(poolOrClient, COMPANY_HEADER_SQL_FALLBACK, [
        accountId,
      ])
      const billing = await fetchAccountBillingRow(poolOrClient, accountId)
      if (!rows[0]) {
        return withResolvedPlan({ ...empty }, billing)
      }
      const mapped = mapCompanyFromRow(rows[0])
      if (!mapped) {
        return withResolvedPlan({ ...empty }, billing)
      }
      return withResolvedPlan(mapped, billing)
    }
    throw err
  }
}

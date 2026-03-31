import { safeQuery } from '../utils/tenantQuery.js'

/**
 * Canonical company header from company_settings (company_name is the only name source).
 */
const COMPANY_HEADER_SQL = `
  SELECT
    company_name,
    address,
    phone,
    tax_id,
    logo_url,
    signature_url,
    auto_signature_enabled,
    date_format
  FROM company_settings
  WHERE account_id = $1::uuid
  ORDER BY updated_at DESC NULLS LAST, id DESC
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
 * Load normalized company header for PDFs and PO/document snapshots.
 * @param {import('pg').Pool | import('pg').PoolClient} poolOrClient
 * @param {string} accountId
 * @returns {Promise<{ name_th: string, address: string, phone: string, tax_id: string, logo_url: string | null } | null>}
 */
export async function getCompany(poolOrClient, accountId) {
  const empty = genericCompanyHeader()
  try {
    const { rows } = await safeQuery(poolOrClient, COMPANY_HEADER_SQL, [accountId])
    if (!rows[0]) {
      return { ...empty }
    }
    const mapped = mapCompanyFromRow(rows[0])
    if (!mapped) {
      return { ...empty }
    }
    return mapped
  } catch (err) {
    if (err && err.code === '42703') {
      const { rows } = await safeQuery(poolOrClient, COMPANY_HEADER_SQL_FALLBACK, [
        accountId,
      ])
      if (!rows[0]) {
        return { ...empty }
      }
      const mapped = mapCompanyFromRow(rows[0])
      if (!mapped) {
        return { ...empty }
      }
      return mapped
    }
    throw err
  }
}

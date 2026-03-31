/**
 * company_settings: explicit SELECT + fallback for older DBs; null-safe logo_url.
 */

import { pool } from '../db.js'
import { mapCompanyFromRow } from '../services/companyService.js'
import { safeQuery } from './tenantQuery.js'

const COMPANY_SELECT = `
  SELECT
    company_name,
    company_name_en,
    company_name_th,
    address,
    phone,
    tax_id,
    logo_url,
    image_url,
    signature_url,
    auto_signature_enabled,
    language,
    date_format
  FROM company_settings
  WHERE account_id = $1
  ORDER BY updated_at DESC NULLS LAST, id DESC
  LIMIT 1
`

/**
 * @param {import('pg').Pool | import('pg').PoolClient} poolOrClient
 * @param {string} accountId
 * @returns {Promise<Record<string, unknown> | null>}
 */
export async function fetchCompanyRow(poolOrClient, accountId) {
  try {
    const { rows } = await safeQuery(poolOrClient, COMPANY_SELECT, [accountId])
    return rows[0] ?? null
  } catch (err) {
    if (err && err.code === '42703') {
      const { rows } = await safeQuery(
        poolOrClient,
        `SELECT * FROM company_settings WHERE account_id = $1 ORDER BY id DESC LIMIT 1`,
        [accountId],
      )
      return rows[0] ?? null
    }
    throw err
  }
}

/**
 * PDF / invoice routes: never crash on null logo_url.
 * @param {Record<string, unknown> | null | undefined} row
 */
/**
 * Load company settings for PDF routes (uses pool; never throws).
 * @param {string} accountId
 */
export async function getCompanySettings(accountId) {
  try {
    const row = await fetchCompanyRow(pool, accountId)
    return normalizeCompanyForPdf(row)
  } catch (err) {
    console.error('getCompanySettings:', err)
    return normalizeCompanyForPdf(null)
  }
}

export function normalizeCompanyForPdf(row) {
  if (!row) {
    return {
      company_name: '',
      company_name_th: '',
      company_name_en: '',
      address: '',
      tax_id: '',
      logo_url: null,
      image_url: null,
      signature_url: null,
      auto_signature_enabled: true,
      language: 'th',
      date_format: 'thai',
      phone: '',
    }
  }
  const header = mapCompanyFromRow(row)
  const cnTrim =
    row.company_name != null && String(row.company_name).trim() !== ''
      ? String(row.company_name).trim()
      : ''
  const rawLogo = header ? header.logo_url : row.logo_url
  const logoUrl =
    rawLogo != null && String(rawLogo).trim() !== ''
      ? String(rawLogo).trim()
      : null
  const rawImage = row.image_url
  const imageUrl =
    rawImage != null && String(rawImage).trim() !== ''
      ? String(rawImage).trim()
      : null
  const rawSig = row.signature_url
  const signatureUrl =
    rawSig != null && String(rawSig).trim() !== ''
      ? String(rawSig).trim()
      : null

  return {
    company_name: cnTrim,
    company_name_th: cnTrim,
    company_name_en:
      row.company_name_en != null ? String(row.company_name_en).trim() : '',
    address: header ? header.address : row.address != null ? String(row.address) : '',
    tax_id: header ? header.tax_id : row.tax_id != null ? String(row.tax_id) : '',
    logo_url: logoUrl,
    image_url: imageUrl,
    signature_url: signatureUrl,
    auto_signature_enabled: row.auto_signature_enabled !== false,
    language: row.language === 'en' ? 'en' : 'th',
    date_format: ['thai', 'iso', 'business'].includes(String(row.date_format ?? ''))
      ? String(row.date_format)
      : 'thai',
    phone: header ? header.phone : row.phone != null ? String(row.phone).trim() : '',
  }
}

/** PDF / UI: company_name is the only source of truth. */
export function resolveCompanyDisplayName(company) {
  if (!company) return '-'
  const nm =
    company.company_name != null ? String(company.company_name).trim() : ''
  return nm !== '' ? nm : '-'
}

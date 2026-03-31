import { toAbsoluteUrl } from './url.js'

/** @param {unknown} v */
function trimLogoOrNull(v) {
  if (v == null) return null
  const t = String(v).trim()
  return t !== '' ? t : null
}

/**
 * Turn relative logo/signature paths into absolute URLs for Puppeteer (BASE_URL from env).
 * When there is no logo, leave logo_url empty/null so the template skips the img tag (no broken icon).
 * @param {{ logo_url?: string | null, signature_url?: string | null } | null | undefined} company
 */
export function applyPdfLogoBaseUrl(company) {
  if (!company) return
  if (!company.logo_url || String(company.logo_url).trim() === '') {
    company.logo_url = null
  } else if (!String(company.logo_url).startsWith('http')) {
    company.logo_url = toAbsoluteUrl(String(company.logo_url).trim())
  }
  if (company.signature_url != null && String(company.signature_url).trim() !== '') {
    const sig = String(company.signature_url).trim()
    if (!sig.startsWith('http')) {
      company.signature_url = toAbsoluteUrl(sig)
    }
  }
}

/**
 * @param {{
 *   company_name?: unknown,
 *   company_address?: unknown,
 *   company_phone?: unknown,
 *   company_tax_id?: unknown,
 *   company_logo_url?: unknown,
 *   company_signature_url?: unknown
 * }} doc
 * @param {{
 *   name_th?: string,
 *   address?: string,
 *   phone?: string,
 *   tax_id?: string,
 *   logo_url?: string | null,
 *   signature_url?: string | null,
 *   auto_signature_enabled?: boolean,
 *   date_format?: string
 * } | null | undefined} fallbackCompany
 */
export function buildCompanyForPdf(doc, fallbackCompany) {
  console.log('PDF SOURCE DOC:', doc?.company_name)

  if (doc?.company_name != null && String(doc.company_name).trim() !== '') {
    console.log('USING SNAPSHOT')

    return {
      name_th: String(doc.company_name).trim(),
      address: doc.company_address != null ? String(doc.company_address) : '-',
      phone:
        doc.company_phone != null && String(doc.company_phone).trim() !== ''
          ? String(doc.company_phone).trim()
          : '',
      tax_id:
        doc.company_tax_id != null && String(doc.company_tax_id).trim() !== ''
          ? String(doc.company_tax_id).trim()
          : '',
      logo_url: trimLogoOrNull(doc.company_logo_url),
      signature_url:
        trimLogoOrNull(doc.company_signature_url) ??
        fallbackCompany?.signature_url ??
        null,
      auto_signature_enabled:
        fallbackCompany?.auto_signature_enabled !== undefined
          ? fallbackCompany.auto_signature_enabled
          : true,
      date_format: fallbackCompany?.date_format ?? 'thai',
    }
  }

  if (!fallbackCompany) {
    console.error('PDF: fallbackCompany missing — using placeholders')
    return {
      name_th: '-',
      address: '-',
      phone: '',
      tax_id: '',
      logo_url: null,
      signature_url: null,
      auto_signature_enabled: true,
      date_format: 'thai',
    }
  }

  console.log('USING FALLBACK COMPANY')

  return {
    name_th: fallbackCompany.name_th || '-',
    address: fallbackCompany.address != null ? String(fallbackCompany.address) : '-',
    phone:
      fallbackCompany.phone != null && String(fallbackCompany.phone).trim() !== ''
        ? String(fallbackCompany.phone).trim()
        : '',
    tax_id:
      fallbackCompany.tax_id != null && String(fallbackCompany.tax_id).trim() !== ''
        ? String(fallbackCompany.tax_id).trim()
        : '',
    logo_url: trimLogoOrNull(fallbackCompany.logo_url),
    signature_url: fallbackCompany.signature_url ?? null,
    auto_signature_enabled:
      fallbackCompany.auto_signature_enabled !== undefined
        ? fallbackCompany.auto_signature_enabled
        : true,
    date_format: fallbackCompany.date_format ?? 'thai',
  }
}

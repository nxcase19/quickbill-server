/**
 * Puppeteer PDF: assets must be absolute http(s) URLs so Chromium can fetch them.
 * Uses Supabase public object URLs (same as company.js uploads) when SUPABASE_URL is set.
 */
import { toAbsoluteUrl } from './url.js'

function isAbsoluteHttpUrl(s) {
  return typeof s === 'string' && /^https?:\/\//i.test(s.trim())
}

/**
 * Build public URL for an object key inside STORAGE_BUCKET (default uploads).
 * Matches quickbill-server/src/routes/company.js companyStoragePublicUrl().
 * @param {string} rawPath - e.g. company/123-logo.png or uploads/company/123.png
 * @returns {string | null}
 */
function toSupabasePublicObjectUrl(rawPath) {
  const base = String(process.env.SUPABASE_URL || '').trim().replace(/\/$/, '')
  if (!base) return null
  const bucket =
    String(process.env.STORAGE_BUCKET || 'uploads')
      .trim()
      .replace(/^\/+|\/+$/g, '') || 'uploads'

  let p = String(rawPath || '').trim()
  if (!p) return null
  p = p.replace(/^\/+/, '')

  if (p.startsWith(`${bucket}/`)) {
    p = p.slice(bucket.length + 1).replace(/^\/+/, '')
  }
  if (p.startsWith('uploads/')) {
    p = p.slice('uploads/'.length)
  }
  if (!p) return null

  const url = `${base}/storage/v1/object/public/${bucket}/${p}`
  return isAbsoluteHttpUrl(url) ? url.trim() : null
}

/**
 * @param {string | null | undefined} logoUrl
 * @returns {string | null}
 */
export function resolvePdfLogoAbsoluteUrl(logoUrl) {
  if (logoUrl == null || String(logoUrl).trim() === '') return null
  let s = String(logoUrl).trim()
  if (s.startsWith('data:')) return s
  if (s.startsWith('//')) {
    s = `https:${s}`
  }
  if (isAbsoluteHttpUrl(s)) return s.trim()

  const supabaseUrl = toSupabasePublicObjectUrl(s)
  if (supabaseUrl) return supabaseUrl

  const full = toAbsoluteUrl(s)
  if (!full || !isAbsoluteHttpUrl(full)) return null
  return full.trim()
}

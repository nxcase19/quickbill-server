/**
 * Puppeteer PDF: assets must be absolute http(s) URLs so Chromium can fetch them.
 */
import { toAbsoluteUrl } from './url.js'

export function resolvePdfLogoAbsoluteUrl(logoUrl) {
  if (!logoUrl || !String(logoUrl).trim()) return null
  const s = String(logoUrl).trim()
  if (s.startsWith('http')) return s
  const full = toAbsoluteUrl(s)
  return full || null
}

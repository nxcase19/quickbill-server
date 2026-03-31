/**
 * Resolve relative upload paths for PDF / HTML render (no DB writes).
 * Uses BASE_URL from env (single public API origin).
 */
import { toAbsoluteAssetUrl } from './pdfAssetUrl.js'

export function toAbsoluteUrl(path) {
  if (!path) return ''
  const s = String(path).trim()
  if (s === '') return ''
  if (s.startsWith('http')) return s
  return toAbsoluteAssetUrl(s)
}

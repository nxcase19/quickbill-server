/**
 * Public origin for resolving relative upload paths in PDF / Puppeteer.
 * Single source: process.env.BASE_URL (no scattered localhost literals).
 */

export function getPublicBaseUrl() {
  return String(process.env.BASE_URL || 'http://localhost:8080').replace(/\/$/, '')
}

/**
 * @param {string | null | undefined} path
 * @returns {string}
 */
export function toAbsoluteAssetUrl(path) {
  if (path == null || String(path).trim() === '') return ''
  const s = String(path).trim()
  if (/^https?:\/\//i.test(s)) return s
  const pathname = s.startsWith('/') ? s : `/${s}`
  return `${getPublicBaseUrl()}${pathname}`
}

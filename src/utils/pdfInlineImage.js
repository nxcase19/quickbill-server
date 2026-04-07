/**
 * Inline remote images as data URLs for Puppeteer PDFs (no network at print time).
 */

/** @param {string} url */
export async function getBase64Image(url) {
  const res = await fetch(url, { redirect: 'follow' })
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`)
  }
  let mime = 'image/png'
  const hdr = res.headers.get('content-type')
  if (hdr) {
    const part = hdr.split(';')[0].trim().toLowerCase()
    if (/^image\/[a-z0-9.+*-]+$/.test(part)) mime = part
  }
  const ab = await res.arrayBuffer()
  const base64 = Buffer.from(ab).toString('base64')
  return `data:${mime};base64,${base64}`
}

/**
 * Replace company.logo_url with a data URL when fetch succeeds. Mutates company.
 * On failure, leaves the absolute URL so Puppeteer may still load it over the network.
 * @param {{ logo_url?: string | null } | null | undefined} company
 */
export async function inlineCompanyLogoForPdf(company) {
  if (!company?.logo_url) return
  const raw = String(company.logo_url).trim()
  if (raw.startsWith('data:')) return

  try {
    company.logo_url = await getBase64Image(raw)
  } catch (e) {
    console.warn('PDF logo inline failed:', e?.message || e)
  }
}

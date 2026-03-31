/**
 * PDF / server-side document dates from company settings.
 * @param {Date|string|number|null|undefined} date
 * @param {string} [language] — company.language (reserved for future use)
 * @param {string} [format] — 'thai' | 'business' | 'iso' (default: YYYY-MM-DD)
 */
function parseToDate(date) {
  if (date == null || date === '') return null
  if (date instanceof Date) {
    return Number.isNaN(date.getTime()) ? null : date
  }
  if (typeof date === 'number') {
    const d = new Date(date)
    return Number.isNaN(d.getTime()) ? null : d
  }
  const s = String(date).trim()
  if (!s) return null
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s)
  if (m) {
    const y = Number(m[1])
    const mo = Number(m[2])
    const day = Number(m[3])
    const d = new Date(y, mo - 1, day)
    return Number.isNaN(d.getTime()) ? null : d
  }
  const d = new Date(s)
  return Number.isNaN(d.getTime()) ? null : d
}

export function formatDate(date, language, format) {
  void language
  const d = parseToDate(date)
  if (!d) return ''

  const day = String(d.getDate()).padStart(2, '0')
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const year = d.getFullYear()

  const fmt = String(format ?? 'thai').toLowerCase()

  if (fmt === 'thai') {
    return `${day}/${month}/${year + 543}`
  }

  if (fmt === 'business') {
    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    })
  }

  return `${year}-${month}-${day}`
}

export default formatDate

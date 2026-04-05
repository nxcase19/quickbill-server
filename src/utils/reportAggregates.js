/**
 * Money rounding for JSON responses (2 decimals, NaN-safe).
 * @param {unknown} value
 * @returns {number}
 */
export function roundMoney(value) {
  const n = Number(value)
  if (!Number.isFinite(n)) return 0
  return Math.round(n * 100) / 100
}

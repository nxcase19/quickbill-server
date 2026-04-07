/**
 * Withholding tax (WHT) on invoice subtotal.
 * base = subtotal; WHT = base * (rate/100); net = (subtotal + vat) - WHT
 */

export function roundMoney(num) {
  return Math.round(Number(num || 0) * 100) / 100
}

/**
 * @param {{ subtotal: number, vatAmount: number, rate: number }} opts
 * @returns {{ baseAmount: number, whtAmount: number, netAmount: number, total: number }}
 */
export function calculateWHT({ subtotal, vatAmount, rate }) {
  const baseAmount = roundMoney(subtotal)
  const whtAmount = roundMoney(baseAmount * (Number(rate) / 100))
  const total = roundMoney(Number(subtotal) + Number(vatAmount))
  const netAmount = roundMoney(total - whtAmount)

  return {
    baseAmount,
    whtAmount,
    netAmount,
    total,
  }
}

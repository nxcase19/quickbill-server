/**
 * Same rules as frontend `src/utils/payment.js` — keep in sync.
 * Enriches API document rows with computed payment_status + outstanding_amount.
 */

function docTotal(row) {
  return Number(row?.total_amount ?? row?.total ?? 0)
}

function docPaid(row) {
  return Number(row?.paid_amount ?? 0)
}

export function isCancelledRow(row) {
  return String(row?.status ?? '').toLowerCase() === 'cancelled'
}

export function getPaymentStatus(row) {
  if (!row) return 'unpaid'
  if (isCancelledRow(row)) return 'cancelled'
  const total = docTotal(row)
  const paid = docPaid(row)
  if (paid >= total) return 'paid'
  return 'unpaid'
}

export function getOutstandingAmount(row) {
  if (!row || isCancelledRow(row)) return 0
  const total = docTotal(row)
  const paid = docPaid(row)
  return Math.max(0, total - paid)
}

/**
 * @returns {Record<string, unknown>}
 */
export function enrichDocumentRow(row) {
  return {
    ...row,
    payment_status: getPaymentStatus(row),
    outstanding_amount: getOutstandingAmount(row),
  }
}

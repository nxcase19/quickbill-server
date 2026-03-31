/**
 * Centralized sales / purchase cancellation checks (no DB access).
 */

export function isSalesCancelled(doc) {
  return String(doc?.status || '').toLowerCase() === 'cancelled'
}

export function assertSalesNotCancelled(doc) {
  if (isSalesCancelled(doc)) {
    const err = new Error('เอกสารถูกยกเลิกแล้ว')
    err.statusCode = 400
    throw err
  }
}

export function isPoCancelled(po) {
  return String(po?.status || '').toLowerCase() === 'cancelled'
}

export function assertPoNotCancelled(po) {
  if (isPoCancelled(po)) {
    const err = new Error('ใบสั่งซื้อถูกยกเลิกแล้ว')
    err.statusCode = 400
    throw err
  }
}

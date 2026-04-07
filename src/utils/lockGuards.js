import { getPaymentStatus } from './documentPaymentMath.js'

export function deriveSalesDocumentLocked(status) {
  const s = String(status ?? '').trim().toLowerCase()
  return s === 'cancelled'
}

export function derivePurchaseOrderLocked(status) {
  const s = String(status ?? '').trim().toLowerCase()
  return s === 'paid' || s === 'cancelled'
}

export function isSalesDocumentLocked(doc) {
  if (!doc) return false
  if (doc.is_locked === true) return true
  if (getPaymentStatus(doc) === 'paid') return true
  return deriveSalesDocumentLocked(doc.status)
}

export function isPurchaseOrderLocked(po) {
  if (!po) return false
  return po.is_locked === true || derivePurchaseOrderLocked(po.status)
}

export function assertDocumentNotLocked(doc, actionName = 'modify this document') {
  if (isSalesDocumentLocked(doc)) {
    const err = new Error(`Cannot ${actionName}: เอกสารถูกล็อกแล้ว`)
    err.statusCode = 400
    throw err
  }
}

export function assertPurchaseOrderNotLocked(po, actionName = 'modify this purchase order') {
  if (isPurchaseOrderLocked(po)) {
    const err = new Error(`Cannot ${actionName}: ใบสั่งซื้อถูกล็อกแล้ว`)
    err.statusCode = 400
    throw err
  }
}

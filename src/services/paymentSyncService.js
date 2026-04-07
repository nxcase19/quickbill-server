/**
 * Keeps documents.payment_status aligned with invoices.status (invoices are the source of truth).
 * @param {import('pg').Pool | import('pg').PoolClient} client
 * @param {string} invoiceId
 */
export async function syncPaymentStatusByInvoice(client, invoiceId) {
  const { rows } = await client.query(
    `SELECT id, status, doc_no, account_id FROM invoices WHERE id = $1::uuid`,
    [invoiceId],
  )

  if (!rows.length) return

  const invoice = rows[0]
  const paymentStatus = invoice.status === 'paid' ? 'paid' : 'unpaid'

  await client.query(
    `UPDATE documents
     SET payment_status = $1
     WHERE account_id = $2::uuid
       AND order_id IN (
         SELECT order_id FROM documents
         WHERE account_id = $2::uuid AND doc_no = $3
       )`,
    [paymentStatus, invoice.account_id, invoice.doc_no],
  )

  console.log('SYNC PAYMENT:', {
    invoiceId,
    invoiceStatus: invoice.status,
    updated: true,
  })
}

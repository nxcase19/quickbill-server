/**
 * Shared minimal “premium” HTML layout for Puppeteer PDFs.
 *
 * Used by: Purchase Order, Invoice (Puppeteer).
 * Same shell for future HTML PDFs — only pass different:
 *   - headerRightHtml (title / subtitle / meta)
 *   - partySectionLabel + partyBlockHtml (Supplier vs Customer vs other)
 *   - lineItemsSectionLabel, table rows, summary, signature labels
 *
 * Quotation / Delivery Note / Receipt currently use pdfkit in documents.js;
 * they can call renderPremiumDocumentPdfHtml with matching label sets when migrated.
 */

export function escapeHtml(v) {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/** Blank date under signatures; shape follows company date_format. */
export function buildSignatureDatePlaceholderHtml(dateFormat, dateLabel) {
  const label = escapeHtml(dateLabel)
  const fmt = String(dateFormat || 'thai').toLowerCase()
  if (fmt === 'iso') {
    return `${label} ____-____-____`
  }
  if (fmt === 'business') {
    return `${label} ____ ___, ____`
  }
  return `${label} ____ / ____ / ____`
}

const STYLES = `
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Tahoma, Arial, sans-serif;
      font-size: 11px;
      color: #1e293b;
      margin: 0;
      padding: 0;
      background: #fff;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .page {
      max-width: 720px;
      margin: 0 auto;
      padding: 28px 32px 40px;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 24px;
      margin-bottom: 28px;
      padding-bottom: 20px;
      border-bottom: 1px solid #e2e8f0;
    }
    .header-left {
      display: flex;
      gap: 16px;
      flex: 1;
      min-width: 0;
    }
    .logo-placeholder {
      width: 80px;
      height: 80px;
      border: 1px dashed #cbd5e1;
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #94a3b8;
      font-size: 10px;
      font-weight: 600;
      letter-spacing: 0.05em;
      flex-shrink: 0;
      background: #fff;
    }
    .company-lines {
      line-height: 1.45;
    }
    .company-lines .name {
      font-weight: 700;
      font-size: 13px;
      color: #0f172a;
      margin-bottom: 4px;
    }
    .company-lines .muted {
      color: #64748b;
      font-size: 10px;
      white-space: pre-wrap;
    }
    .header-right {
      text-align: right;
      flex-shrink: 0;
    }
    .doc-title {
      font-size: 20px;
      font-weight: 700;
      letter-spacing: 0.04em;
      color: #0f172a;
      margin-bottom: 4px;
    }
    .doc-title-sub {
      font-size: 11px;
      color: #64748b;
      margin-bottom: 8px;
    }
    .doc-meta {
      font-size: 11px;
      color: #475569;
      line-height: 1.45;
    }
    .doc-meta strong { color: #334155; }
    .section-block {
      margin-bottom: 20px;
    }
    .section-label {
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: #64748b;
      margin-bottom: 8px;
    }
    .section-label.section-label--thai {
      text-transform: none;
      letter-spacing: 0.02em;
    }
    .party-block p {
      margin: 0 0 4px;
      line-height: 1.5;
      color: #334155;
    }
    .party-block p:last-child { margin-bottom: 0; }
    .party-block strong { color: #0f172a; }
    table.doc-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 4px;
    }
    .doc-table th {
      background: #f1f5f9;
      border: 1px solid #cbd5e1;
      padding: 8px 10px;
      font-size: 10px;
      font-weight: 600;
      text-align: left;
      color: #334155;
    }
    .doc-table td {
      border: 1px solid #e2e8f0;
      padding: 8px 10px;
      vertical-align: top;
    }
    .doc-table .col-no { width: 36px; text-align: center; color: #64748b; }
    .doc-table .col-desc { min-width: 180px; }
    .doc-table .col-num {
      text-align: right;
      font-variant-numeric: tabular-nums;
      white-space: nowrap;
    }
    .summary-wrap {
      margin-top: 16px;
      display: flex;
      justify-content: flex-end;
    }
    .summary-box {
      width: 260px;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 12px 14px;
      background: #fff;
    }
    .summary-line {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      padding: 4px 0;
      font-size: 11px;
      color: #475569;
    }
    .summary-line.total {
      margin-top: 8px;
      padding-top: 10px;
      border-top: 1px solid #e2e8f0;
      font-size: 14px;
      font-weight: 700;
      color: #0f172a;
    }
    .signature-section {
      display: flex;
      justify-content: space-between;
      margin-top: 56px;
      gap: 48px;
      padding: 0 4px;
    }
    .signature-col {
      flex: 1;
      max-width: 45%;
      text-align: center;
      font-size: 10px;
      color: #64748b;
    }
    .signature-line {
      border-top: 1px solid #64748b;
      width: 65%;
      margin: 0 auto;
      height: 0;
    }
    .signature-label {
      margin-top: 10px;
      color: #475569;
    }
    .signature-date {
      margin-top: 8px;
      font-size: 9px;
      color: #94a3b8;
      line-height: 1.4;
    }
`

/**
 * @param {object} o
 * @param {string} o.lang - html lang attribute
 * @param {boolean} [o.isThai] - section label typography
 * @param {string} o.logoBlock - raw HTML (trusted)
 * @param {string} o.companyLinesHtml - escaped name/address rows inside .company-lines
 * @param {string} o.headerRightHtml - title, optional subtitle, meta (prebuilt)
 * @param {string} o.partySectionLabel - escaped
 * @param {string} o.partyBlockHtml - escaped inner <p>…</p>
 * @param {string} o.lineItemsSectionLabel - escaped
 * @param {string} o.tableHeadRowHtml - <th> cells
 * @param {string} o.tableBodyHtml - rows
 * @param {string} o.summaryBoxInnerHtml - summary lines
 * @param {string} o.sigLeftLabel - escaped
 * @param {string} o.sigRightLabel - escaped
 * @param {string} o.sigDateLineHtml - safe HTML (from buildSignatureDatePlaceholderHtml)
 */
/** Example titles when adding QT / DN / RC HTML routes (party label = Customer or Supplier). */
export const PREMIUM_PDF_DOC_TITLE = {
  quotationTh: 'ใบเสนอราคา',
  quotationEn: 'QUOTATION',
  deliveryTh: 'ใบส่งสินค้า',
  deliveryEn: 'DELIVERY NOTE',
  receiptTh: 'ใบเสร็จรับเงิน',
  receiptEn: 'RECEIPT',
}

export function renderPremiumDocumentPdfHtml(o) {
  const thai = o.isThai ? ' section-label--thai' : ''
  return `<!DOCTYPE html>
<html lang="${o.lang === 'en' ? 'en' : 'th'}">
<head>
  <meta charset="utf-8" />
  <style>${STYLES}</style>
</head>
<body>
  <div class="page">
    <header class="header">
      <div class="header-left">
        ${o.logoBlock}
        <div class="company-lines">
          ${o.companyLinesHtml}
        </div>
      </div>
      <div class="header-right">
        ${o.headerRightHtml}
      </div>
    </header>

    <div class="section-block">
      <div class="section-label${thai}">${o.partySectionLabel}</div>
      <div class="party-block">
        ${o.partyBlockHtml}
      </div>
    </div>

    <div class="section-block">
      <div class="section-label${thai}">${o.lineItemsSectionLabel}</div>
      <table class="doc-table">
        <thead>
          <tr>
            ${o.tableHeadRowHtml}
          </tr>
        </thead>
        <tbody>
          ${o.tableBodyHtml}
        </tbody>
      </table>

      <div class="summary-wrap">
        <div class="summary-box">
          ${o.summaryBoxInnerHtml}
        </div>
      </div>
    </div>

    <div class="signature-section">
      <div class="signature-col">
        <div class="signature-line"></div>
        <div class="signature-label">${o.sigLeftLabel}</div>
        <div class="signature-date">${o.sigDateLineHtml}</div>
      </div>
      <div class="signature-col">
        <div class="signature-line"></div>
        <div class="signature-label">${o.sigRightLabel}</div>
        <div class="signature-date">${o.sigDateLineHtml}</div>
      </div>
    </div>
  </div>
</body>
</html>`
}

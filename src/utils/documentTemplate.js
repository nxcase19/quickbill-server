/**
 * Centralized SaaS-style HTML for Puppeteer PDFs (PO, Invoice, QT, DN, Receipt).
 */

import path from 'node:path'
import fs from 'node:fs'
import { formatDate } from './formatDate.js'
import { resolvePdfLogoAbsoluteUrl } from './pdfLogoUrl.js'

function escapeHtml(v) {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

function escapeAttrUrl(u) {
  return String(u).replace(/&/g, '&amp;').replace(/"/g, '&quot;')
}

function formatMoneyPdf(n, locale) {
  return Number(n || 0).toLocaleString(locale, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
}

/**
 * @param {object} opts
 * @param {'po'|'invoice'|'quotation'|'dn'|'receipt'} opts.type
 * @param {object} opts.data
 * @param {object} opts.company - normalized company_settings (logo_url)
 * @param {'th'|'en'} [opts.lang]
 */
export function renderDocument({ type, data, company, lang }) {
  const langResolved = lang === 'en' ? 'en' : 'th'

  const companySafeRaw = company || {}

  const companySafe = {
    name_th:
      companySafeRaw.name_th ||
      companySafeRaw.company_name ||
      '',

    address:
      companySafeRaw.address || '',

    phone:
      companySafeRaw.phone != null ? String(companySafeRaw.phone) : '',

    tax_id:
      companySafeRaw.tax_id || '',

    logo_url:
      companySafeRaw.logo_url || '',

    signature_url:
      companySafeRaw.signature_url || '',

    auto_signature_enabled:
      companySafeRaw.auto_signature_enabled ?? true,

    date_format:
      companySafeRaw.date_format || 'thai',
  }
  console.log('FINAL COMPANY USED IN PDF:', companySafe)
  const isTH = langResolved === 'th'
  const locale = isTH ? 'th-TH' : 'en-US'
  const dateFmt = companySafe?.date_format ?? 'thai'

  const labels = {
    title: {
      po: isTH ? 'ใบสั่งซื้อ' : 'PURCHASE ORDER',
      invoice: isTH ? 'ใบแจ้งหนี้' : 'INVOICE',
      quotation: isTH ? 'ใบเสนอราคา' : 'QUOTATION',
      dn: isTH ? 'ใบส่งสินค้า' : 'DELIVERY NOTE',
      receipt: isTH ? 'ใบเสร็จรับเงิน' : 'RECEIPT',
    },
    docNo: isTH ? 'เลขที่เอกสาร' : 'Doc No',
    date: isTH ? 'วันที่' : 'Date',
    customer: isTH ? 'ลูกค้า' : 'Customer',
    supplier: isTH ? 'ผู้ขาย' : 'Supplier',
    qty: isTH ? 'จำนวน' : 'Qty',
    price: isTH ? 'ราคาต่อหน่วย' : 'Unit Price',
    amount: isTH ? 'จำนวนเงิน' : 'Amount',
    subtotal: isTH ? 'มูลค่าสินค้า' : 'Subtotal',
    vat: isTH ? 'ภาษีมูลค่าเพิ่ม' : 'VAT',
    total: isTH ? 'ยอดรวม' : 'Total',
    seller: isTH ? 'ผู้ขาย' : 'Prepared By',
    approve: isTH ? 'ผู้อนุมัติ' : 'Approved By',
    desc: isTH ? 'รายการ' : 'Description',
    emptyRow: isTH ? 'ไม่มีรายการ' : 'No line items',
  }

  const companyNameRaw = companySafe?.name_th || ''
  const companyName = escapeHtml(companyNameRaw)

  const rawLogo = companySafe?.logo_url
  const logoFull =
    rawLogo != null && String(rawLogo).trim() !== ''
      ? resolvePdfLogoAbsoluteUrl(String(rawLogo).trim()) || ''
      : ''

  const signature = companySafe?.signature_url
  const signatureFull =
    signature != null && String(signature).trim() !== ''
      ? resolvePdfLogoAbsoluteUrl(String(signature).trim()) || ''
      : ''
  const autoSign = companySafe?.auto_signature_enabled !== false

  let showLeftStamp = false
  let showRightStamp = false
  if (autoSign && signatureFull) {
    switch (type) {
      case 'po':
        showRightStamp = true
        break
      case 'quotation':
        showLeftStamp = true
        break
      case 'dn':
        break
      case 'invoice':
        showLeftStamp = true
        break
      case 'receipt':
        showRightStamp = true
        break
      default:
        showLeftStamp = true
    }
  }

  const docNo = escapeHtml(data.doc_no ?? '—')
  const dateRaw = data.doc_date ?? data.date
  const dateStr =
    formatDate(dateRaw, langResolved, dateFmt) || escapeHtml(String(dateRaw ?? '—'))

  const partyName = escapeHtml(data.party_name ?? '—')
  const partyAddress = escapeHtml(data.party_address ?? '-')
  const partyPhone = escapeHtml(data.party_phone ?? '-')
  const partyTax = escapeHtml(data.party_tax ?? '-')
  const phoneLabel = isTH ? 'โทร:' : 'Phone:'
  const taxLabel = isTH ? 'เลขผู้เสียภาษี:' : 'Tax ID:'

  const addr = escapeHtml(companySafe?.address ?? '')
  const companyPhoneRaw = String(companySafe?.phone ?? '').trim()
  const taxIdRaw = String(companySafe?.tax_id ?? '').trim()

  const items = Array.isArray(data.items) ? data.items : []
  const isDn = type === 'dn'

  const totalQty = items.reduce(
    (sum, it) => sum + Number(it.quantity ?? it.qty ?? 0),
    0,
  )

  const rowsHtmlFull =
    items.length === 0
      ? `<tr><td colspan="5" style="text-align:center;color:#94a3b8">${escapeHtml(labels.emptyRow)}</td></tr>`
      : items
          .map((it, i) => {
            const d = escapeHtml(it.description ?? '')
            const q = formatMoneyPdf(it.quantity, locale)
            const p = formatMoneyPdf(it.unit_price, locale)
            const a = formatMoneyPdf(it.amount, locale)
            return `
            <tr>
              <td>${i + 1}</td>
              <td>${d}</td>
              <td style="text-align:right">${q}</td>
              <td style="text-align:right">${p}</td>
              <td style="text-align:right">${a}</td>
            </tr>`
          })
          .join('')

  const rowsHtmlDn =
    items.length === 0
      ? `<tr><td colspan="3" style="text-align:center;color:#94a3b8">${escapeHtml(labels.emptyRow)}</td></tr>`
      : items
          .map((it, i) => {
            const d = escapeHtml(it.description ?? '')
            const q = formatMoneyPdf(it.quantity, locale)
            return `
            <tr>
              <td>${i + 1}</td>
              <td>${d}</td>
              <td style="text-align:right">${q}</td>
            </tr>`
          })
          .join('')

  const tableHtml = isDn
    ? `<table>
    <thead>
      <tr>
        <th>#</th>
        <th>รายการ</th>
        <th>จำนวน</th>
      </tr>
    </thead>
    <tbody>
      ${rowsHtmlDn}
    </tbody>
  </table>
<div style="margin-top:10px; text-align:right; font-weight:600">
  รวมจำนวน: ${totalQty}
</div>`
    : `<table>
    <thead>
      <tr>
        <th>#</th>
        <th>${escapeHtml(labels.desc)}</th>
        <th>${escapeHtml(labels.qty)}</th>
        <th>${escapeHtml(labels.price)}</th>
        <th>${escapeHtml(labels.amount)}</th>
      </tr>
    </thead>
    <tbody>
      ${rowsHtmlFull}
    </tbody>
  </table>`

  const subtotal = formatMoneyPdf(data.subtotal, locale)
  const showVatLine = data.show_vat_line !== false
  const vatRaw = data.vat ?? data.vat_amount ?? 0
  const vatAmt = formatMoneyPdf(vatRaw, locale)
  const total = formatMoneyPdf(data.total, locale)

  const vatTypeRaw =
    data.vat_type != null && String(data.vat_type).trim() !== ''
      ? String(data.vat_type).trim()
      : 'none'
  const vatType = vatTypeRaw === 'vat7' ? 'vat7' : 'none'

  const vatLabelText =
    vatType === 'vat7'
      ? isTH
        ? 'ภาษีมูลค่าเพิ่ม 7%'
        : 'VAT 7%'
      : isTH
        ? 'ภาษีมูลค่าเพิ่ม'
        : labels.vat

  const title = labels.title[type] ?? labels.title.invoice

  let leftLabel = labels.seller
  let rightLabel = labels.approve

  if (type === 'quotation') {
    leftLabel = 'ผู้เสนอราคา'
    rightLabel = 'ผู้อนุมัติ'
  }

  if (type === 'invoice') {
    leftLabel = 'ผู้รับวางบิล'
    rightLabel = 'ผู้แจ้งหนี้'
  }

  if (type === 'receipt') {
    leftLabel = 'ผู้จ่ายเงิน'
    rightLabel = 'ผู้รับเงิน'
  }

  if (type === 'dn') {
    leftLabel = 'ผู้ส่งสินค้า'
    rightLabel = 'ผู้รับสินค้า'
  }

  function renderSignatureColumn(showStamp, roleLabelEscaped) {
    const imgHtml =
      showStamp && autoSign && signatureFull
        ? `<img src="${escapeAttrUrl(signatureFull)}" style="max-height:60px;width:auto;max-width:100%;object-fit:contain" alt="" />`
        : ''
    return `<div style="width:45%;text-align:center;display:flex;flex-direction:column;justify-content:flex-end;height:120px;box-sizing:border-box;">
  <div style="height:60px;display:flex;align-items:flex-end;justify-content:center;width:100%;box-sizing:border-box;">${imgHtml}</div>
  <div style="border-top:1px solid #000;margin-top:10px;width:100%;box-sizing:border-box;"></div>
  <div style="font-size:14px;margin-top:6px;">${roleLabelEscaped}</div>
  <div style="font-size:13px;margin-top:4px;">วันที่ ____ / ____ / ____</div>
</div>`
  }

  const signLeftHtml = renderSignatureColumn(showLeftStamp, escapeHtml(leftLabel))
  const signRightHtml = renderSignatureColumn(showRightStamp, escapeHtml(rightLabel))

  const summaryHtml =
    type !== 'dn'
      ? `<div class="summary">
    <div><span>${escapeHtml(labels.subtotal)}</span><span>${subtotal}</span></div>
    ${
      showVatLine
        ? `<div><span>${escapeHtml(vatLabelText)}</span><span>${vatAmt}</span></div>`
        : ''
    }
    <div class="total">
      <span>${escapeHtml(labels.total)}</span>
      <span>${total}</span>
    </div>
  </div>`
      : ''

  console.log('PDF company:', company)

  // Thai font for PDF loaded from local filesystem for Puppeteer.
  // Use base64-embedded @font-face so it works reliably in serverless/containers.
  // Expect font file at: <project-root>/assets/fonts/THSarabun.ttf
  const __dirname = path.dirname(new URL(import.meta.url).pathname)
  const fontPath = path.join(__dirname, '../assets/fonts/THSarabun.ttf')
  let fontDataUrl = ''
  try {
    if (!fs.existsSync(fontPath)) {
      console.error('FONT NOT FOUND:', fontPath)
    } else {
      const fontBuf = fs.readFileSync(fontPath)
      const fontBase64 = fontBuf.toString('base64')
      fontDataUrl = `data:font/truetype;charset=utf-8;base64,${fontBase64}`
    }
  } catch (e) {
    console.error('FONT LOAD ERROR:', e)
  }

  const planLower = String(companySafeRaw.plan ?? '').toLowerCase()

  /** Watermark: plan === 'free' only — trial / basic / pro / business → no watermark */
  let watermarkTier = null

  if (planLower === 'free') {
    watermarkTier = 'FREE'
  }

  // ❌ ห้ามมี fallback ใด ๆ อีก

  const watermarkLineEscaped = watermarkTier
    ? escapeHtml(`QuickBill ${watermarkTier}`)
    : ''

  let watermarkOpacity = '0.104'
  let fontWeight = '500'

  if (watermarkTier === 'TRIAL') {
    watermarkOpacity = '0.169'
    fontWeight = '700'
  }

  const watermarkGridHtml = watermarkTier
    ? `<div style="
position: fixed;
top: 0;
left: 0;
width: 100%;
height: 100%;
display: grid;
grid-template-columns: repeat(3, 1fr);
grid-template-rows: repeat(4, 1fr);
z-index: 9999;
pointer-events: none;
">
${Array(12)
  .fill(0)
  .map(
    () => `
  <div style="
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 55px;
    color: rgba(0,0,0,${watermarkOpacity});
    transform: rotate(-30deg);
    font-weight: ${fontWeight};
    letter-spacing: 2px;
  ">
    ${watermarkLineEscaped}
  </div>`,
  )
  .join('')}
</div>`
    : ''

  return `<!DOCTYPE html>
<html lang="${isTH ? 'th' : 'en'}">
<head>
  <meta charset="utf-8" />
  <style>
    ${fontDataUrl
      ? `@font-face {
      font-family: 'THSarabun';
      src: url('${fontDataUrl}') format('truetype');
      font-weight: 400;
      font-style: normal;
    }`
      : ''}

    ${fontDataUrl
      ? `* {
      font-family: 'THSarabun', sans-serif !important;
    }`
      : ''}

    body {
      font-family: ${fontDataUrl
        ? "'THSarabun', sans-serif"
        : "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"};
      padding: 48px;
      color: #0f172a;
      margin: 0;
      font-size: 14px;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }

    hr {
      border: none;
      border-top: 1px solid #e2e8f0;
      margin: 20px 0;
    }

    .section-title {
      font-weight: 600;
      margin-bottom: 6px;
    }

    /* กล่องผู้ขาย/ลูกค้า (สำคัญ) */
    .card {
      background: #f1f5f9;
      border-radius: 10px;
      padding: 14px 16px;
      margin-bottom: 20px;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
    }

    th, td {
      border: 1px solid #e2e8f0;
      padding: 8px;
      font-size: 14px;
    }

    th {
      background: #f1f5f9;
      font-weight: 600;
    }

    /* summary กล่องขวา */
    .summary {
      margin-top: 20px;
      width: 260px;
      margin-left: auto;
      border-radius: 10px;
      background: #f8fafc;
      padding: 14px;
    }

    .summary div {
      display: flex;
      justify-content: space-between;
      margin-bottom: 6px;
      font-size: 14px;
    }

    .total {
      font-weight: bold;
      font-size: 18px;
      margin-top: 6px;
    }

  </style>
</head>
<body>
  ${watermarkGridHtml}
  <div style="display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:24px;">
    <div style="display:flex; gap:12px; align-items:flex-start;">
      ${
        logoFull
          ? `<img src="${escapeAttrUrl(logoFull)}" style="width:60px; height:60px; object-fit:contain;" alt="" />`
          : ''
      }
      <div style="display:flex; flex-direction:column; line-height:1.4;">
        <div style="font-weight:bold; font-size:16px;">
          ${companyName}
        </div>
        <div style="font-size:13px;">
          ${addr}
        </div>
        ${
          companyPhoneRaw !== ''
            ? `<div style="font-size:13px;">
          ${escapeHtml(phoneLabel)} ${escapeHtml(companyPhoneRaw)}
        </div>`
            : ''
        }
        ${
          taxIdRaw !== ''
            ? `<div style="font-size:13px;">
          ${escapeHtml(taxLabel)} ${escapeHtml(taxIdRaw)}
        </div>`
            : ''
        }
      </div>
    </div>
    <div style="text-align:right; line-height:1.6;">
      <div style="font-weight:bold; font-size:18px;">
        ${escapeHtml(title)}
      </div>
      <div style="font-size:13px;">
        ${escapeHtml(labels.docNo)}: ${docNo}
      </div>
      <div style="font-size:13px;">
        ${escapeHtml(labels.date)}: ${dateStr}
      </div>
    </div>
  </div>

  <hr />

  <div class="section-title">
    ${escapeHtml(type === 'po' ? labels.supplier : labels.customer)}
  </div>

  <div class="card">
    <div><strong>${partyName}</strong></div>
    <div>${partyAddress}</div>
    <div>${escapeHtml(phoneLabel)} ${partyPhone}</div>
    <div>${escapeHtml(taxLabel)} ${partyTax}</div>
  </div>

  ${tableHtml}

  ${summaryHtml}

  <div style="display:flex;justify-content:space-between;margin-top:60px;width:100%;align-items:flex-start;box-sizing:border-box;">
    ${signLeftHtml}
    ${signRightHtml}
  </div>
</body>
</html>`
}

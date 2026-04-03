/**
 * Watermark only on free plan (company.plan from getCompany / billing).
 * @param {{ plan?: string }} company
 */
export function pdfIsFreePlan(company) {
  return String(company?.plan ?? '').toLowerCase() === 'free'
}

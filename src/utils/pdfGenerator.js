/**
 * PDF tier: free vs pro (company.plan from billing / caller).
 * @param {{ plan?: string }} company
 */
export function pdfIsFreePlan(company) {
  const isFree = company.plan !== 'pro'
  return isFree
}

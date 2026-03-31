/**
 * Non-production logging for tenant-scoped routes (debug / audit during development).
 * Does not replace proper authorization — account_id must still be enforced in SQL.
 */

export function logTenantAccess(routeName, req, extra = {}) {
  if (process.env.NODE_ENV === 'production') return
  console.log('[TENANT]', {
    route: routeName,
    account_id: req.user?.account_id ?? null,
    ...extra,
  })
}

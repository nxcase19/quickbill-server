/**
 * Express middleware: gate routes behind PRO plan (req.user.plan from auth).
 * @param {string} featureName - Shown in 403 JSON for clients
 */
export function requirePro(featureName) {
  return (req, res, next) => {
    const plan = req.user?.plan || 'free'

    if (plan !== 'pro') {
      return res.status(403).json({
        error: `Feature "${featureName}" requires PRO plan`,
      })
    }

    next()
  }
}

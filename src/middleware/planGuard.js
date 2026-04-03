import { allowsProAndTrialOnly } from '../utils/planAccess.js'

/**
 * Express middleware: PRO-only routes (not Basic) — allows `pro` and `trial` only.
 * @param {string} featureName - Shown in 403 JSON for clients
 */
export function requirePro(featureName) {
  return (req, res, next) => {
    const plan = String(req.user?.plan ?? 'free').toLowerCase()
    console.log('CHECK PLAN:', plan)

    if (!allowsProAndTrialOnly(plan)) {
      return res.status(403).json({
        error: `Feature "${featureName}" requires PRO plan`,
      })
    }

    next()
  }
}

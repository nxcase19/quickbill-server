/** Browser origins allowed for credentialed CORS (must echo exact Origin). */
export const ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'https://quickbill-web.vercel.app',
]

const ALLOW_SET = new Set(ALLOWED_ORIGINS)

/**
 * Set CORS headers on this response (use on error paths / explicit handlers).
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 */
export function applyCorsHeaders(req, res) {
  const origin = req.headers.origin
  if (typeof origin === 'string' && ALLOW_SET.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin)
    res.setHeader('Access-Control-Allow-Credentials', 'true')
  }
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Origin, X-Requested-With, Content-Type, Accept, Authorization',
  )
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
}

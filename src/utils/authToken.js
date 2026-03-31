import jwt from 'jsonwebtoken'
import { jwtSecret } from '../config.js'

const JWT_EXPIRES = '7d'

/**
 * Canonical JWT claims (snake_case only). company_id is resolved server-side when needed.
 * @param {{ userId: unknown, accountId: unknown, email?: string | null, role?: string | null }} payload
 */
export function signAuthToken({ userId, accountId, email, role }) {
  const emailNorm = email != null ? String(email).trim().toLowerCase() : ''
  const roleNorm = role != null && String(role).trim() !== '' ? String(role).trim() : 'owner'
  return jwt.sign(
    {
      user_id: userId,
      account_id: accountId,
      email: emailNorm || undefined,
      role: roleNorm,
    },
    jwtSecret,
    { expiresIn: JWT_EXPIRES },
  )
}

export function verifyAuthToken(token) {
  return jwt.verify(token, jwtSecret)
}

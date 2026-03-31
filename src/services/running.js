/**
 * Next running number per tenant + doc_type.
 * - If table `running_numbers_account` exists: use (account_id UUID, doc_type).
 * - Else legacy `running_numbers` keyed by bigint company_id — tenantKey must not be a UUID
 *   (run sql/running_numbers_account.sql to enable UUID tenants).
 *
 * @param {import('pg').PoolClient} conn
 * @param {string} tenantKey — account UUID string; never coerced with Number()
 * @param {string} docType One of: QT, DN, INV, RC
 */
export async function nextRunningNo(conn, tenantKey, docType) {
  const docTypeStr = String(docType ?? 'INV').toUpperCase()
  const useAccountTable = await hasRunningNumbersAccountTable(conn)

  if (useAccountTable) {
    return nextRunningAccountTable(conn, tenantKey, docTypeStr)
  }
  return nextRunningLegacyCompany(conn, tenantKey, docTypeStr)
}

/** @type {Promise<boolean> | null} */
let hasAccountTablePromise = null

async function hasRunningNumbersAccountTable(conn) {
  if (!hasAccountTablePromise) {
    hasAccountTablePromise = (async () => {
      const { rows } = await conn.query(
        `SELECT 1
         FROM information_schema.tables
         WHERE table_schema = 'public'
           AND table_name = 'running_numbers_account'
         LIMIT 1`,
      )
      return rows.length > 0
    })()
  }
  return hasAccountTablePromise
}

/** Exported for tests only */
export function resetRunningModeCacheForTests() {
  hasAccountTablePromise = null
}

function isUuidLike(s) {
  if (typeof s !== 'string') return false
  const t = s.trim()
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(t)
}

async function nextRunningAccountTable(conn, accountId, docTypeStr) {
  await conn.query(
    `INSERT INTO running_numbers_account (account_id, doc_type, next_no)
     VALUES ($1::uuid, $2, 1)
     ON CONFLICT (account_id, doc_type) DO NOTHING`,
    [accountId, docTypeStr],
  )

  const { rows } = await conn.query(
    `SELECT next_no
     FROM running_numbers_account
     WHERE account_id = $1::uuid AND doc_type = $2
     FOR UPDATE`,
    [accountId, docTypeStr],
  )

  const current = Number(rows[0].next_no)
  await conn.query(
    `UPDATE running_numbers_account
     SET next_no = next_no + 1
     WHERE account_id = $1::uuid AND doc_type = $2`,
    [accountId, docTypeStr],
  )
  return current
}

async function nextRunningLegacyCompany(conn, tenantKey, docTypeStr) {
  if (isUuidLike(String(tenantKey))) {
    throw new Error(
      'Running numbers: apply sql/running_numbers_account.sql so UUID account_id can allocate sequences.',
    )
  }

  const { rows: colRows } = await conn.query(
    `SELECT 1
     FROM information_schema.columns
     WHERE table_name = 'running_numbers'
       AND column_name = 'doc_type'
     LIMIT 1`,
  )

  if (colRows.length > 0) {
    await conn.query(
      `INSERT INTO running_numbers (company_id, doc_type, next_no)
       VALUES ($1, $2, 1)
       ON CONFLICT (company_id, doc_type) DO NOTHING`,
      [tenantKey, docTypeStr],
    )

    const { rows } = await conn.query(
      `SELECT next_no
       FROM running_numbers
       WHERE company_id = $1 AND doc_type = $2
       FOR UPDATE`,
      [tenantKey, docTypeStr],
    )

    const current = Number(rows[0].next_no)
    await conn.query(
      `UPDATE running_numbers
       SET next_no = next_no + 1
       WHERE company_id = $1 AND doc_type = $2`,
      [tenantKey, docTypeStr],
    )
    return current
  }

  await conn.query(
    `INSERT INTO running_numbers (company_id, next_no) VALUES ($1, 1)
     ON CONFLICT (company_id) DO NOTHING`,
    [tenantKey],
  )
  const { rows } = await conn.query(
    `SELECT next_no
     FROM running_numbers
     WHERE company_id = $1
     FOR UPDATE`,
    [tenantKey],
  )
  const current = Number(rows[0].next_no)
  await conn.query(
    `UPDATE running_numbers
     SET next_no = next_no + 1
     WHERE company_id = $1`,
    [tenantKey],
  )
  return current
}

export function formatDocNo(prefix, runningNo) {
  const n = String(runningNo).padStart(6, '0')
  return `${prefix}-${n}`
}

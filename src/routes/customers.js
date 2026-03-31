import { Router } from 'express'
import { pool } from '../db.js'
import { buildTenantWhereClause } from '../utils/tenant.js'
import { safeQuery } from '../utils/tenantQuery.js'

const router = Router()
const isUuid = (v) =>
  typeof v === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)

// account_id is mandatory for isolation; enforced by requireAccountMiddleware + tenant SQL.

// GET customers
router.get('/', async (req, res) => {
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ success: false, error: 'Missing account_id in token' })
    }
    if (!isUuid(String(accountId))) {
      return res.status(400).json({ success: false, error: 'Invalid account_id' })
    }
    const tw = buildTenantWhereClause(req, '', 1)
    const { rows } = await safeQuery(
      pool,
      `SELECT id, name, phone, address, tax_id
       FROM customers
       WHERE ${tw.clause}
         AND deleted_at IS NULL
       ORDER BY created_at DESC`,
      [tw.param],
    )

    return res.json({ success: true, data: rows })
  } catch (err) {
    console.error('CUSTOMERS ERROR:', err)
    return res.status(500).json({ success: false, error: err.message })
  }
})

// CREATE customer
router.post('/', async (req, res) => {
  try {
    console.log('CREATE CUSTOMER BODY:', req.body)
    const { name, phone, address, tax_id } = req.body
    const account_id = req.account_id
    if (!account_id) {
      return res.status(400).json({
        success: false,
        error: 'Missing account_id',
      })
    }

    const result = await safeQuery(
      pool,
      `INSERT INTO customers (
         account_id,
         name,
         phone,
         address,
         tax_id
       )
       VALUES ($1::uuid, $2, $3, $4, $5)
       RETURNING *`,
      [
        account_id,
        name ?? '',
        phone ?? '',
        address ?? '',
        tax_id ?? '',
      ],
    )

    return res.status(201).json({
      success: true,
      data: result.rows[0],
    })
  } catch (err) {
    console.error('CREATE CUSTOMER ERROR:', err)
    return res.status(500).json({
      success: false,
      error: err.message,
    })
  }
})

// UPDATE customer
router.put('/:id', async (req, res) => {
  try {
    const accountId = req.account_id
    if (!accountId) {
      return res.status(401).json({ success: false, error: 'Missing account_id in token' })
    }
    if (!isUuid(String(accountId))) {
      return res.status(400).json({ success: false, error: 'Invalid account_id' })
    }
    const id = req.params.id
    if (!isUuid(String(id))) {
      return res.status(400).json({ success: false, error: 'Invalid customer id' })
    }
    const { name, phone, address, tax_id } = req.body
    if (!name || String(name).trim() === '') {
      return res.status(400).json({ success: false, error: 'name is required' })
    }
    const { rows } = await safeQuery(
      pool,
      `UPDATE customers
       SET name = $1, phone = $2, address = $3, tax_id = $4
       WHERE id = $5 AND account_id = $6::uuid
         AND deleted_at IS NULL
       RETURNING id`,
      [String(name).trim(), phone ?? '', address ?? '', tax_id ?? '', id, accountId],
    )
    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Not found' })
    }
    return res.json({ success: true, data: { id: rows[0].id } })
  } catch (err) {
    console.error('CUSTOMERS ERROR:', err)
    return res.status(500).json({ success: false, error: err.message })
  }
})

// DELETE customer
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const account_id = req.account_id
    if (!id) {
      return res.status(400).json({ success: false, error: 'Missing id' })
    }
    if (!account_id) {
      return res.status(401).json({ success: false, error: 'Missing account_id' })
    }
    const result = await safeQuery(
      pool,
      `UPDATE customers
       SET deleted_at = NOW()
       WHERE id = $1 AND account_id = $2
         AND deleted_at IS NULL
       RETURNING id`,
      [id, account_id],
    )

    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Customer not found' })
    }

    return res.json({ success: true, data: { id: result.rows[0].id } })
  } catch (err) {
    console.error('DELETE CUSTOMER ERROR:', err)
    return res.status(500).json({ success: false, error: err.message })
  }
})

export default router

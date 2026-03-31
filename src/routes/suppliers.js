import { Router } from 'express'
import { pool } from '../db.js'
import { requireAccountId, safeQuery } from '../utils/tenantQuery.js'

const router = Router()
const isUuid = (v) =>
  typeof v === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)

router.get('/', async (req, res) => {
  try {
    const accountId = requireAccountId(req)
    if (!isUuid(String(accountId))) {
      return res.status(400).json({ error: 'Invalid account_id' })
    }
    const { rows } = await safeQuery(
      pool,
      `SELECT id, name, address, phone, tax_id
       FROM suppliers
       WHERE account_id = $1::uuid
         AND deleted_at IS NULL
       ORDER BY created_at DESC`,
      [accountId],
    )
    res.json(rows)
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('SUPPLIERS ERROR:', err)
    res.status(500).json({ error: err.message })
  }
})

router.post('/', async (req, res) => {
  try {
    const accountId = requireAccountId(req)
    if (!isUuid(String(accountId))) {
      return res.status(400).json({ error: 'Invalid account_id' })
    }
    const { name, address, phone, tax_id } = req.body || {}
    if (!name || String(name).trim() === '') {
      return res.status(400).json({ error: 'name is required' })
    }
    const { rows } = await safeQuery(
      pool,
      `INSERT INTO suppliers (account_id, name, address, phone, tax_id)
       VALUES ($1::uuid, $2, $3, $4, $5)
       RETURNING id, account_id, name, address, phone, tax_id, created_at`,
      [
        accountId,
        String(name).trim(),
        address != null ? String(address) : '',
        phone != null ? String(phone) : '',
        tax_id != null ? String(tax_id) : '',
      ],
    )
    res.status(201).json(rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('SUPPLIERS ERROR:', err)
    res.status(500).json({ error: err.message })
  }
})

router.put('/:id', async (req, res) => {
  try {
    const accountId = requireAccountId(req)
    const { id } = req.params
    if (!isUuid(String(accountId))) {
      return res.status(400).json({ error: 'Invalid account_id' })
    }
    if (!isUuid(String(id))) {
      return res.status(400).json({ error: 'Invalid supplier id' })
    }
    const { name, address, phone, tax_id } = req.body || {}
    if (!name || String(name).trim() === '') {
      return res.status(400).json({ error: 'name is required' })
    }
    const { rows } = await safeQuery(
      pool,
      `UPDATE suppliers
       SET name = $1, address = $2, phone = $3, tax_id = $4, updated_at = NOW()
       WHERE id = $5::uuid AND account_id = $6::uuid
         AND deleted_at IS NULL
       RETURNING id, account_id, name, address, phone, tax_id, created_at`,
      [
        String(name).trim(),
        address != null ? String(address) : '',
        phone != null ? String(phone) : '',
        tax_id != null ? String(tax_id) : '',
        id,
        accountId,
      ],
    )
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    res.json(rows[0])
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('SUPPLIERS ERROR:', err)
    res.status(500).json({ error: err.message })
  }
})

router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const account_id = requireAccountId(req)
    if (!id) {
      return res.status(400).json({ error: 'Missing id' })
    }
    const { rows } = await safeQuery(
      pool,
      `UPDATE suppliers
       SET deleted_at = NOW(), updated_at = NOW()
       WHERE id = $1::uuid AND account_id = $2::uuid
         AND deleted_at IS NULL
       RETURNING id`,
      [id, account_id],
    )
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Supplier not found' })
    }
    res.json({ success: true })
  } catch (err) {
    if (err.message === 'Missing account_id') {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    console.error('DELETE SUPPLIER ERROR:', err)
    res.status(500).json({ error: err.message })
  }
})

export default router

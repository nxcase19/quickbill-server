import { Router } from 'express'
import { pool } from '../db.js'
import { buildTenantWhereClause } from '../utils/tenant.js'
import { safeQuery } from '../utils/tenantQuery.js'

const router = Router()

router.get('/', async (req, res) => {
  try {
    const tw = buildTenantWhereClause(req, '', 1)
    const { rows } = await safeQuery(
      pool,
      `SELECT id, name, default_price FROM products WHERE ${tw.clause} ORDER BY id DESC`,
      [tw.param],
    )
    res.json(rows)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Internal server error' })
  }
})

router.post('/', async (req, res) => {
  try {
    const accountId = req.user?.account_id
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id' })
    }
    const { rows: userRows } = await safeQuery(
      pool,
      `SELECT company_id FROM users WHERE account_id = $1::uuid ORDER BY id ASC LIMIT 1`,
      [accountId],
    )
    const companyId = userRows[0]?.company_id
    const name = req.body.name
    const defaultPrice =
      req.body.default_price != null ? req.body.default_price : req.body.defaultPrice
    if (!name || String(name).trim() === '') {
      return res.status(400).json({ error: 'name is required' })
    }
    const price =
      defaultPrice === undefined || defaultPrice === null || defaultPrice === ''
        ? 0
        : Number(defaultPrice)
    const safePrice = Number.isFinite(price) ? price : 0
    if (companyId == null || companyId === '') {
      return res.status(400).json({ error: 'No company_id for this account' })
    }
    const sql = `INSERT INTO products (company_id, account_id, name, default_price) VALUES ($1, $2, $3, $4) RETURNING id`
    const params = [companyId, accountId, String(name).trim(), safePrice]
    const { rows } = await safeQuery(pool, sql, params)
    res.status(201).json({ id: rows[0].id })
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Internal server error' })
  }
})

router.delete('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id)
    if (!Number.isFinite(id)) {
      return res.status(400).json({ error: 'Invalid id' })
    }
    const tw = buildTenantWhereClause(req, '', 2)
    const { rowCount } = await safeQuery(
      pool,
      `DELETE FROM products WHERE id = $1 AND ${tw.clause}`,
      [id, tw.param],
    )
    if (rowCount === 0) {
      return res.status(404).json({ error: 'Not found' })
    }
    res.status(204).send()
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: 'Internal server error' })
  }
})

export default router

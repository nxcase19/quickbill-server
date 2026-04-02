import { Router } from 'express'
import { pool } from '../db.js'
import { getAccountId } from '../utils/tenant.js'
import { uploadLogo, uploadSignature } from '../middleware/upload.js'
import { safeQuery } from '../utils/tenantQuery.js'
import { fetchCompanyRow } from '../utils/companySettings.js'
import { supabase } from '../utils/supabase.js'

const router = Router()

const STORAGE_BUCKET = 'quickbill'

function safeOriginalName(name, fallback) {
  const safe = String(name || fallback)
    .replace(/[/\\]/g, '_')
    .replace(/[^a-zA-Z0-9._-]/g, '_')
  return safe || fallback
}

function companyStoragePublicUrl(fileName) {
  const base = String(process.env.SUPABASE_URL || '').replace(/\/$/, '')
  return `${base}/storage/v1/object/public/${STORAGE_BUCKET}/${fileName}`
}

async function uploadToCompanyBucket(buffer, file, fallbackName) {
  const safe = safeOriginalName(file.originalname, fallbackName)
  const fileName = `company/${Date.now()}-${safe}`
  const { error } = await supabase.storage.from(STORAGE_BUCKET).upload(fileName, buffer, {
    contentType: file.mimetype || 'application/octet-stream',
  })
  if (error) throw error
  const publicUrl = companyStoragePublicUrl(fileName)
  return { fileName, publicUrl }
}

/** Remove previous object when URL is our public Supabase URL (ignores legacy /uploads paths). */
async function removeBucketObjectByPublicUrl(storedUrl) {
  if (!storedUrl || typeof storedUrl !== 'string') return
  const base = String(process.env.SUPABASE_URL || '').replace(/\/$/, '')
  const prefix = `${base}/storage/v1/object/public/${STORAGE_BUCKET}/`
  if (!storedUrl.startsWith(prefix)) return
  const objectPath = storedUrl.slice(prefix.length)
  if (!objectPath) return
  const { error } = await supabase.storage.from(STORAGE_BUCKET).remove([objectPath])
  if (error) console.warn('[company] Supabase remove:', error.message)
}

function handleLogoUpload(req, res, next) {
  uploadLogo.single('logo')(req, res, (err) => {
    if (err) {
      return res.status(400).json({ error: err.message || 'Upload failed' })
    }
    next()
  })
}

function handleSignatureUpload(req, res, next) {
  uploadSignature.single('signature')(req, res, (err) => {
    if (err) {
      return res.status(400).json({ error: err.message || 'Upload failed' })
    }
    next()
  })
}

/** Normalize row for API: company_name is the only source of truth for display name. */
function mapCompanyRow(row) {
  if (!row) return null
  const companyName =
    row.company_name != null ? String(row.company_name).trim() : ''
  return {
    id: row.id,
    account_id: row.account_id,
    company_name: companyName,
    company_name_en: row.company_name_en ?? '',
    address: row.address ?? '',
    tax_id: row.tax_id ?? '',
    logo_url:
      row.logo_url != null && String(row.logo_url).trim() !== ''
        ? String(row.logo_url).trim()
        : null,
    signature_url:
      row.signature_url != null && String(row.signature_url).trim() !== ''
        ? String(row.signature_url).trim()
        : null,
    auto_signature_enabled: row.auto_signature_enabled !== false,
    language: row.language ?? 'th',
    date_format: row.date_format ?? 'thai',
    phone: row.phone ?? '',
    name: companyName,
    created_at: row.created_at ?? null,
    updated_at: row.updated_at ?? null,
  }
}

async function ensureDefaultCompanyRow(client, accountId) {
  let row = await fetchCompanyRow(client, accountId)
  if (row) return row

  const { rows: inserted } = await safeQuery(
    client,
    `INSERT INTO company_settings (account_id, language, date_format)
     VALUES ($1::uuid, 'th', 'thai')
     RETURNING *`,
    [accountId],
  )
  row = await fetchCompanyRow(client, accountId)
  return row ?? inserted[0] ?? null
}

router.get('/', async (req, res) => {
  try {
    const accountId = getAccountId(req)
    if (!accountId) {
      return res.status(401).json({ error: 'Missing account_id in token' })
    }

    const client = await pool.connect()
    try {
      const row = await ensureDefaultCompanyRow(client, accountId)
      res.json({ success: true, data: mapCompanyRow(row) })
    } finally {
      client.release()
    }
  } catch (err) {
    console.error('GET /company error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.post('/', async (req, res) => {
  const accountId = getAccountId(req)
  if (!accountId) {
    return res.status(401).json({ error: 'Missing account_id in token' })
  }

  const body = req.body ?? {}
  const companyName =
    body.company_name != null && String(body.company_name).trim() !== ''
      ? String(body.company_name).trim()
      : ''
  const companyNameEn =
    body.company_name_en != null ? String(body.company_name_en).trim() : ''
  const address =
    body.address != null && String(body.address).trim() !== ''
      ? String(body.address).trim()
      : ''
  const taxId = body.tax_id != null ? String(body.tax_id) : ''
  const phone =
    body.phone != null && String(body.phone).trim() !== ''
      ? String(body.phone).trim()
      : ''

  if (!companyName) {
    return res.status(400).json({ error: 'company_name is required' })
  }
  if (!address) {
    return res.status(400).json({ error: 'address is required' })
  }
  if (!phone) {
    return res.status(400).json({ error: 'phone is required' })
  }
  const language =
    body.language === 'en' || body.language === 'th' ? body.language : 'th'
  const dateFormatRaw = body.date_format != null ? String(body.date_format) : 'thai'
  const dateFormat = ['thai', 'iso', 'business'].includes(dateFormatRaw)
    ? dateFormatRaw
    : 'thai'

  const autoSignatureEnabled =
    body.auto_signature_enabled === false || body.auto_signature_enabled === 'false'
      ? false
      : true

  const client = await pool.connect()
  try {
    await client.query('BEGIN')

    const { rows: existing } = await safeQuery(
      client,
      `SELECT id FROM company_settings WHERE account_id = $1::uuid LIMIT 1`,
      [accountId],
    )

    let row
    if (existing.length > 0) {
      const { rows } = await safeQuery(
        client,
        `UPDATE company_settings
         SET company_name = $2,
             company_name_en = $3,
             name = $2,
             address = $4,
             tax_id = $5,
             phone = $6,
             language = $7,
             date_format = $8,
             auto_signature_enabled = $9,
             updated_at = NOW()
         WHERE account_id = $1::uuid
         RETURNING *`,
        [
          accountId,
          companyName,
          companyNameEn,
          address,
          taxId,
          phone,
          language,
          dateFormat,
          autoSignatureEnabled,
        ],
      )
      row = rows[0]
    } else {
      const { rows } = await safeQuery(
        client,
        `INSERT INTO company_settings (
           account_id, company_name, company_name_en, name, address, tax_id, phone,
           language, date_format, auto_signature_enabled
         )
         VALUES ($1::uuid, $2, $3, $2, $4, $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          accountId,
          companyName,
          companyNameEn,
          address,
          taxId,
          phone,
          language,
          dateFormat,
          autoSignatureEnabled,
        ],
      )
      row = rows[0]
    }

    await client.query('COMMIT')
    res.json({ success: true, data: mapCompanyRow(row) })
  } catch (err) {
    try {
      await client.query('ROLLBACK')
    } catch {
      /* ignore */
    }
    console.error('POST /company error:', err)
    res.status(500).json({ error: err.message })
  } finally {
    client.release()
  }
})

router.post('/logo', handleLogoUpload, async (req, res) => {
  const accountId = getAccountId(req)
  if (!accountId) {
    return res.status(401).json({ error: 'Missing account_id in token' })
  }
  if (!req.file?.buffer) {
    return res.status(400).json({ error: 'No file uploaded' })
  }

  let newObjectPath = null
  try {
    const { fileName, publicUrl } = await uploadToCompanyBucket(
      req.file.buffer,
      req.file,
      'logo',
    )
    newObjectPath = fileName

    const client = await pool.connect()
    try {
      await client.query('BEGIN')

      const { rows: existing } = await safeQuery(
        client,
        `SELECT id, logo_url FROM company_settings WHERE account_id = $1::uuid LIMIT 1`,
        [accountId],
      )

      const oldUrl =
        existing.length > 0 && existing[0].logo_url
          ? String(existing[0].logo_url).trim()
          : ''

      if (existing.length > 0) {
        await safeQuery(
          client,
          `UPDATE company_settings
           SET logo_url = $2,
               updated_at = NOW()
           WHERE account_id = $1::uuid`,
          [accountId, publicUrl],
        )
      } else {
        await safeQuery(
          client,
          `INSERT INTO company_settings (account_id, logo_url, language, date_format)
           VALUES ($1::uuid, $2, 'th', 'thai')`,
          [accountId, publicUrl],
        )
      }

      await client.query('COMMIT')
      await removeBucketObjectByPublicUrl(oldUrl)
      res.json({ logo_url: publicUrl })
    } catch (dbErr) {
      try {
        await client.query('ROLLBACK')
      } catch {
        /* ignore */
      }
      throw dbErr
    } finally {
      client.release()
    }
  } catch (err) {
    if (newObjectPath) {
      try {
        await supabase.storage.from(STORAGE_BUCKET).remove([newObjectPath])
      } catch {
        /* ignore */
      }
    }
    console.error('POST /company/logo error:', err)
    res.status(500).json({ error: err.message })
  }
})

router.post('/signature', handleSignatureUpload, async (req, res) => {
  const accountId = getAccountId(req)
  if (!accountId) {
    return res.status(401).json({ error: 'Missing account_id in token' })
  }
  if (!req.file?.buffer) {
    return res.status(400).json({ error: 'No file uploaded' })
  }

  let newObjectPath = null
  try {
    const { fileName, publicUrl } = await uploadToCompanyBucket(
      req.file.buffer,
      req.file,
      'signature',
    )
    newObjectPath = fileName

    const client = await pool.connect()
    try {
      await client.query('BEGIN')

      const { rows: existing } = await safeQuery(
        client,
        `SELECT id, signature_url FROM company_settings WHERE account_id = $1::uuid LIMIT 1`,
        [accountId],
      )

      const oldUrl =
        existing.length > 0 && existing[0].signature_url
          ? String(existing[0].signature_url).trim()
          : ''

      if (existing.length > 0) {
        await safeQuery(
          client,
          `UPDATE company_settings
           SET signature_url = $2,
               updated_at = NOW()
           WHERE account_id = $1::uuid`,
          [accountId, publicUrl],
        )
      } else {
        await safeQuery(
          client,
          `INSERT INTO company_settings (account_id, signature_url, language, date_format)
           VALUES ($1::uuid, $2, 'th', 'thai')`,
          [accountId, publicUrl],
        )
      }

      await client.query('COMMIT')
      await removeBucketObjectByPublicUrl(oldUrl)
      res.json({ signature_url: publicUrl })
    } catch (dbErr) {
      try {
        await client.query('ROLLBACK')
      } catch {
        /* ignore */
      }
      throw dbErr
    } finally {
      client.release()
    }
  } catch (err) {
    if (newObjectPath) {
      try {
        await supabase.storage.from(STORAGE_BUCKET).remove([newObjectPath])
      } catch {
        /* ignore */
      }
    }
    console.error('POST /company/signature error:', err)
    res.status(500).json({ error: err.message })
  }
})

export default router

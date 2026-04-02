import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import multer from 'multer'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/** Logo/signature: memory → Supabase Storage (bucket quickbill). */
export const uploadLogo = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 3 * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    if (!file.mimetype || !file.mimetype.startsWith('image/')) {
      cb(new Error('Only image files are allowed'))
      return
    }
    cb(null, true)
  },
})

const purchasesDir = path.join(__dirname, '../../uploads/purchases')
fs.mkdirSync(purchasesDir, { recursive: true })

const purchaseStorage = multer.diskStorage({
  destination(_req, _file, cb) {
    cb(null, purchasesDir)
  },
  filename(_req, file, cb) {
    const safe = String(file.originalname || 'image').replace(/[^a-zA-Z0-9._-]/g, '_')
    cb(null, `${Date.now()}-${safe}`)
  },
})

export const uploadPurchaseInvoice = multer({
  storage: purchaseStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    if (!file.mimetype || !file.mimetype.startsWith('image/')) {
      cb(new Error('Only image files are allowed'))
      return
    }
    cb(null, true)
  },
})

export const uploadSignature = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 3 * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    if (!file.mimetype || !file.mimetype.startsWith('image/')) {
      cb(new Error('Only image files are allowed'))
      return
    }
    cb(null, true)
  },
})

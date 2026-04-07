import path from 'node:path'
import express from 'express'
import cors from 'cors'
import { authMiddleware } from './middleware/auth.js'
import authRoutes from './routes/auth.js'
import customersRoutes from './routes/customers.js'
import productsRoutes from './routes/products.js'
import documentsRoutes from './routes/documents.js'
import { paymentsRouter } from './routes/payments.js'
import reportsRoutes from './routes/reports.js'
import companyRoutes from './routes/company.js'
import purchasesRoutes from './routes/purchases.js'
import purchaseOrdersRoutes from './routes/purchaseOrders.js'
import ordersRoutes from './routes/orders.js'
import invoicesRoutes from './routes/invoices.js'
import ocrRoutes from './routes/ocr.js'
import suppliersRoutes from './routes/suppliers.js'
import billingRoutes from './routes/billing.js'
import { handleStripeWebhook } from './routes/billing.js'
import feedbackRoutes from './routes/feedback.js'

const app = express()

app.disable('etag')

app.use((req, res, next) => {
  res.setHeader('Cache-Control', 'no-store')
  res.setHeader('Pragma', 'no-cache')
  res.setHeader('Expires', '0')
  next()
})

const corsConfig = {
  origin(origin, callback) {
    if (!origin) {
      return callback(null, true)
    }

    const allowedOrigins = [
      'http://localhost:5173',
      'http://127.0.0.1:5173',
      'https://quickbill.dev',
      'https://quickbill-web.vercel.app',
    ]

    if (allowedOrigins.includes(origin)) {
      return callback(null, true)
    }

    console.error('CORS blocked:', origin)
    return callback(null, false)
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'Cache-Control',
    'Pragma',
  ],
}

app.use(cors(corsConfig))
app.options('*', cors(corsConfig))

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Credentials', 'true')
  next()
})

app.use((req, res, next) => {
  console.log('REQ:', req.method, req.path)
  next()
})

app.post(
  '/api/billing/webhook',
  express.raw({ type: 'application/json' }),
  handleStripeWebhook,
)

app.use(express.json())
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')))

app.get('/health', (req, res) => {
  res.json({ ok: true })
})

app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'API OK' })
})

app.get('/api/test', (req, res) => {
  res.json({ ok: true })
})

app.use('/api/auth', authRoutes)
app.use('/api/billing', authMiddleware, billingRoutes)
app.use('/api/customers', authMiddleware, customersRoutes)
app.use('/api/products', authMiddleware, productsRoutes)
app.use('/api/documents', authMiddleware, documentsRoutes)
app.use('/api/orders', authMiddleware, ordersRoutes)
app.use('/api/payments', authMiddleware, paymentsRouter)
app.use('/api/reports', authMiddleware, reportsRoutes)
app.use('/api/company', authMiddleware, companyRoutes)
app.use('/api/company-settings', authMiddleware, companyRoutes)
app.use('/api/purchases', authMiddleware, purchasesRoutes)
app.use('/api/purchase-invoices', authMiddleware, purchasesRoutes)
app.use('/api/po', authMiddleware, purchaseOrdersRoutes)
app.use('/api/purchase-orders', authMiddleware, purchaseOrdersRoutes)
app.use('/api/invoices', authMiddleware, invoicesRoutes)
app.use('/api/ocr', authMiddleware, ocrRoutes)
app.use('/api/suppliers', authMiddleware, suppliersRoutes)
app.use('/api/feedback', authMiddleware, feedbackRoutes)

app.use((err, req, res, next) => {
  console.error('GLOBAL ERROR:', err)
  res.status(500).json({
    success: false,
    error: err?.message || 'Internal Server Error',
  })
})

export default app

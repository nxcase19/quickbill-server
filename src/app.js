import path from 'node:path'
import express from 'express'
import cors from 'cors'
import { authMiddleware } from './middleware/auth.js'
import authRoutes from './routes/auth.js'
import customersRoutes from './routes/customers.js'
import productsRoutes from './routes/products.js'
import documentsRoutes from './routes/documents.js'
import { paymentsRouter } from "./routes/payments.js"
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

const app = express()

// CORS must be before all routes (including auth + preflight)
const corsOptions = {
  origin: [
    'http://localhost:5173',
    'http://127.0.0.1:5173',
    'https://quickbill-web.vercel.app',
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}

app.use(cors(corsOptions))
app.options('*', cors(corsOptions))

app.use((req, res, next) => {
  console.log('Incoming request:', req.method, req.path)
  next()
})

// 🔥 MUST BE FIRST (Stripe webhook uses raw body)
app.post(
  '/api/billing/webhook',
  express.raw({ type: 'application/json' }),
  handleStripeWebhook,
)

// ❗ แล้วค่อยมี
app.use(express.json())
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')))

// Public health checks (no auth required)
app.get('/health', (req, res) => {
  res.json({ ok: true })
})

app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'API OK' })
})

app.get('/api/test', (req, res) => {
  res.json({ ok: true })
})

// Route policy:
// - Public: /api/auth/* (login, register) — no auth middleware
// - Protected: selected /api/* — require Bearer JWT via authMiddleware
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

app.use((err, req, res, next) => {
  console.error('GLOBAL ERROR:', err)
  res.status(500).json({
    success: false,
    error: err?.message || 'Internal Server Error',
  })
})

export default app

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

// 🔥 MUST BE FIRST
app.post(
  '/api/billing/webhook',
  express.raw({ type: 'application/json' }),
  handleStripeWebhook,
)

app.use(
  cors({
    origin: ['https://quickbill-web.vercel.app', 'http://localhost:5173'],
    credentials: true,
  }),
)

app.options('*', cors())

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

/**
 * Route policy:
 * - Public: /api/auth/* (login, register) — must stay before authMiddleware on /api.
 * - Protected: all other /api/* — require Bearer JWT; req.account_id from token only.
 */
app.use('/api/auth', authRoutes)
app.use('/api', authMiddleware)
app.use('/api/billing', billingRoutes)
app.use('/api/customers', customersRoutes)
app.use('/api/products', productsRoutes)
app.use('/api/documents', documentsRoutes)
app.use('/api/orders', ordersRoutes)
app.use('/api/payments', paymentsRouter)
app.use('/api/reports', reportsRoutes)
app.use('/api/company', companyRoutes)
app.use('/api/company-settings', companyRoutes)
app.use('/api/purchases', purchasesRoutes)
app.use('/api/purchase-invoices', purchasesRoutes)
app.use('/api/po', purchaseOrdersRoutes)
app.use('/api/purchase-orders', purchaseOrdersRoutes)
app.use('/api/invoices', invoicesRoutes)
app.use('/api/ocr', ocrRoutes)
app.use('/api/suppliers', suppliersRoutes)

app.use((err, req, res, next) => {
  console.error('GLOBAL ERROR:', err)
  res.status(500).json({
    success: false,
    error: err?.message || 'Internal Server Error',
  })
})

export default app

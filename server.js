import dotenv from 'dotenv'
import path from 'path'

// โหลด env ตาม NODE_ENV แบบชัดเจน (ไม่ซ้อนมั่ว)
const env = process.env.NODE_ENV || 'development'

let envFile = '.env.local' // default = dev
if (env === 'production') envFile = '.env.production'
if (env === 'staging') envFile = '.env.staging'

// โหลดไฟล์หลักก่อน
dotenv.config({ path: path.resolve(envFile) })

// fallback: ถ้ามี .env ให้ใช้เป็นค่า default ที่ยังไม่มี
dotenv.config({ path: path.resolve('.env') })

// 🔥 import หลังโหลด env เสร็จเท่านั้น
const { default: app } = await import('./src/app.js')
const { port: configPort } = await import('./src/config.js')

const port = process.env.PORT || configPort || 8080

console.log('==============================')
console.log('🚀 Starting QuickBill Server')
console.log('NODE_ENV:', process.env.NODE_ENV)
console.log('APP_ENV:', process.env.APP_ENV)
console.log('ENV_FILE:', envFile)
console.log('DATABASE_URL:', process.env.DATABASE_URL ? '[SET]' : '[MISSING]')
console.log('SUPABASE_URL:', process.env.SUPABASE_URL ? '[SET]' : '[MISSING]')
console.log('==============================')

const server = app.listen(port, () => {
  console.log(`✅ QuickBill API listening on port ${port}`)
})

server.on('error', (err) => {
  console.error('❌ Server failed to start:', err)
  process.exit(1)
})
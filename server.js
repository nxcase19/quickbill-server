import 'dotenv/config'
import app from './src/app.js'
import { port as configPort } from './src/config.js'

const port = process.env.PORT || configPort || 8080

console.log('==============================')
console.log('🚀 Starting QuickBill Server')
console.log('ENV PORT:', process.env.PORT)
console.log('Using PORT:', port)
console.log('==============================')

const server = app.listen(port, () => {
  console.log(`✅ QuickBill API listening on port ${port}`)
})

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ Port ${port} is already in use`)
  } else {
    console.error('❌ Server error:', err)
  }
})

process.on('SIGINT', () => {
  console.log('🛑 Shutting down server...')
  server.close(() => {
    console.log('✅ Server closed')
    process.exit(0)
  })
})

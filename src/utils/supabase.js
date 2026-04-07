import { createClient } from '@supabase/supabase-js'

const url = process.env.SUPABASE_URL
const key = process.env.SUPABASE_SERVICE_KEY
const env = process.env.APP_ENV

console.log('APP_ENV:', env)
console.log('SUPABASE_URL:', url)

// 🚨 check ENV ครบ
if (!url || !key) {
  throw new Error('❌ Supabase ENV missing')
}

// 🚨 กัน DEV ยิง PROD
if (env === 'dev' && url.includes('enxhpxhbnzrncijqboqh')) {
  throw new Error('🚨 DEV MODE ห้ามใช้ PROD DB')
}

// 🚨 กัน PROD ยิง DEV
if (env === 'prod' && url.includes('bbefnsvfmfqfidtljpss')) {
  throw new Error('🚨 PROD MODE ห้ามใช้ DEV DB')
}

export const supabase = createClient(url, key)
import dotenv from 'dotenv'

dotenv.config()

export const port = Number(process.env.PORT) || 8080
export const jwtSecret = process.env.JWT_SECRET || 'secret123'

export const databaseUrl = process.env.DATABASE_URL

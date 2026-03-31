import fs from 'node:fs'
import { Router } from 'express'
import multer from 'multer'
import OpenAI from 'openai'

const OCR_ENABLED = process.env.FEATURE_OCR === 'true'

const router = Router()

const upload = multer({ dest: 'uploads/' })

function getOpenAI() {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error('OCR not configured')
  }

  return new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  })
}

router.post('/scan', upload.single('file'), async (req, res) => {
  if (!OCR_ENABLED) {
    if (req.file?.path) {
      try {
        fs.unlinkSync(req.file.path)
      } catch {
        /* ignore */
      }
    }
    return res.status(404).json({ error: 'Not found' })
  }

  let openai
  try {
    openai = getOpenAI()
  } catch {
    if (req.file?.path) {
      try {
        fs.unlinkSync(req.file.path)
      } catch {
        /* ignore */
      }
    }
    return res.status(500).json({ error: 'OCR not configured' })
  }

  let filePath
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' })
    }

    filePath = req.file.path

    const base64 = fs.readFileSync(filePath, { encoding: 'base64' })
    const mime = req.file.mimetype || 'image/jpeg'
    const dataUrl = `data:${mime};base64,${base64}`

    const response = await openai.chat.completions.create({
      model: 'gpt-4.1-mini',
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: `
อ่านบิลนี้และดึงข้อมูลออกมาเป็น JSON เท่านั้น:

{
  supplier_name: string,
  tax_id: string,
  doc_no: string,
  doc_date: string (YYYY-MM-DD),
  subtotal: number,
  vat_amount: number,
  total: number
}

ถ้าไม่มีค่า ให้เป็น null
`,
            },
            {
              type: 'image_url',
              image_url: {
                url: dataUrl,
              },
            },
          ],
        },
      ],
    })

    const text = response.choices[0]?.message?.content ?? ''

    let data
    try {
      const trimmed = text.trim()
      const jsonBlock = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/)
      const jsonStr = jsonBlock ? jsonBlock[1].trim() : trimmed
      data = JSON.parse(jsonStr)
    } catch {
      data = { raw: text }
    }

    res.json(data)
  } catch (err) {
    console.error(err)
    res.status(500).json({ error: err.message })
  } finally {
    if (filePath) {
      try {
        fs.unlinkSync(filePath)
      } catch {
        /* ignore */
      }
    }
  }
})

export default router

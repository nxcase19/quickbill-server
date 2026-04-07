/**
 * Puppeteer: wait for document + network, then ensure all <img> resources
 * have loaded (or failed) before print — avoids blank logos in PDF.
 */

/**
 * @param {import('puppeteer').Page} page
 * @param {string} html
 */
export async function setContentAndWaitForImages(page, html) {
  await page.setContent(html, { waitUntil: 'networkidle0' })
  await page.evaluate(async () => {
    const images = Array.from(document.images)
    await Promise.all(
      images.map((img) => {
        if (img.complete) return Promise.resolve()
        return new Promise((resolve) => {
          img.onload = img.onerror = resolve
        })
      }),
    )
  })
}

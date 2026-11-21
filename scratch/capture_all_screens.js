const puppeteer = require('puppeteer');

async function capture() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });

  // 1. Dashboard
  console.log('Navigating to dashboard...');
  await page.goto('http://localhost:8080/#/dashboard', { waitUntil: 'networkidle0', timeout: 30000 });
  await new Promise(r => setTimeout(r, 3000));
  await page.screenshot({ path: '/Users/suyashpandey/.gemini/antigravity/brain/01ce4393-f472-4d25-86d2-8f30a78b60b5/dashboard_verified_latest.png' });
  console.log('Dashboard captured.');

  // 2. Summary
  console.log('Navigating to summary...');
  await page.goto('http://localhost:8080/#/summary', { waitUntil: 'networkidle0', timeout: 30000 });
  await new Promise(r => setTimeout(r, 2000));
  await page.screenshot({ path: '/Users/suyashpandey/.gemini/antigravity/brain/01ce4393-f472-4d25-86d2-8f30a78b60b5/summary_verified_latest.png' });
  console.log('Summary captured.');

  // 3. Build My Honda
  console.log('Navigating to Build My Honda...');
  await page.goto('http://localhost:8080/#/build-my-honda', { waitUntil: 'networkidle0', timeout: 30000 });
  await new Promise(r => setTimeout(r, 2000));
  await page.screenshot({ path: '/Users/suyashpandey/.gemini/antigravity/brain/01ce4393-f472-4d25-86d2-8f30a78b60b5/build_my_honda_verified_latest.png' });
  console.log('Build My Honda captured.');

  await browser.close();
}

capture().catch(err => {
  console.error(err);
  process.exit(1);
});

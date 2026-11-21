const puppeteer = require('puppeteer');

async function run() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });

  console.log('Navigating to dashboard...');
  await page.goto('https://yash-honda-enquiry-crm-frontend.vercel.app/#/dashboard', {
    waitUntil: 'networkidle2',
    timeout: 45000
  });

  await new Promise(r => setTimeout(r, 6000));

  // Click Sign out button at bottom left of sidebar: (55, 865)
  console.log('Clicking Sign out button at (55, 865)...');
  await page.mouse.click(55, 865);
  await new Promise(r => setTimeout(r, 4000));

  console.log('Current URL after logout:', page.url());

  // Click Branch Manager demo card at EXACT center: (1112, 650)
  console.log('Clicking Branch Manager demo card at (1112, 650)...');
  await page.mouse.click(1112, 650);
  await new Promise(r => setTimeout(r, 1000));

  console.log('Clicking Sign in button at (1112, 516)...');
  await page.mouse.click(1112, 516);
  await new Promise(r => setTimeout(r, 7000));

  console.log('Current URL after Branch Manager login:', page.url());

  await page.screenshot({
    path: '/Users/suyashpandey/.gemini/antigravity/brain/01ce4393-f472-4d25-86d2-8f30a78b60b5/manager_dashboard_verified.png'
  });
  console.log('Saved manager_dashboard_verified.png');

  await browser.close();
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});

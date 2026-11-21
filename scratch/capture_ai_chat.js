const puppeteer = require('puppeteer');

async function run() {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });

  console.log('Navigating to login...');
  await page.goto('https://yash-honda-enquiry-crm-frontend.vercel.app/#/login', {
    waitUntil: 'networkidle2',
    timeout: 45000
  });

  await new Promise(r => setTimeout(r, 6000));

  console.log('Signing in at (1112, 516)...');
  await page.mouse.click(1112, 516);
  await new Promise(r => setTimeout(r, 6000));

  console.log('Current URL after sign in:', page.url());

  // Click AI Robot icon at exact center: (1224, 32)
  console.log('Clicking AI Robot icon at exact coordinates (1224, 32)...');
  await page.mouse.click(1224, 32);
  await new Promise(r => setTimeout(r, 2500));

  await page.screenshot({
    path: '/Users/suyashpandey/.gemini/antigravity/brain/01ce4393-f472-4d25-86d2-8f30a78b60b5/ai_copilot_chatbot_open.png'
  });
  console.log('Saved ai_copilot_chatbot_open.png');

  // Center of dialog is x=720, y=450 (width=720, height=760 => x in [360, 1080], y in [70, 830])
  // Input bar is near bottom: y ~ 800, x ~ 700
  console.log('Typing query into AI chat input at (700, 800)...');
  await page.mouse.click(700, 800);
  await page.keyboard.type('How is our dealership performing today and which branch is leading?');
  await new Promise(r => setTimeout(r, 600));
  await page.keyboard.press('Enter');
  await new Promise(r => setTimeout(r, 4500));

  await page.screenshot({
    path: '/Users/suyashpandey/.gemini/antigravity/brain/01ce4393-f472-4d25-86d2-8f30a78b60b5/ai_copilot_conversation.png'
  });
  console.log('Saved ai_copilot_conversation.png');

  await browser.close();
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});

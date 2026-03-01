#!/usr/bin/env node
/**
 * LC Visual Test — Playwright-based PWA screenshot + verification
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:18815';
const SCREENSHOT_DIR = '/home/jarvis.linux/projects/lovers-compass/visual-test-screenshots';

async function run() {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
  const results = [];

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 }, // iPhone 14 size
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
    permissions: ['geolocation'],
    geolocation: { latitude: 34.0522, longitude: -118.2437 },
  });
  const page = await context.newPage();

  function check(name, pass, detail = '') {
    results.push({ name, pass, detail });
    console.log(`  ${pass ? '✅' : '❌'} ${name}${detail ? ' — ' + detail : ''}`);
  }

  try {
    // 1. Load pairing screen
    console.log('[1] Pairing Screen');
    await page.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 15000 });
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '01-pairing-screen.png') });
    
    const title = await page.title();
    check('Page loads', title.length > 0, `title: "${title}"`);
    
    const hasCreate = await page.$('text=Create') || await page.$('button:has-text("Create")');
    check('Create button visible', !!hasCreate);
    
    const hasJoin = await page.$('text=Join') || await page.$('button:has-text("Join")');
    check('Join button visible', !!hasJoin);

    const hasDemo = await page.$('text=Demo') || await page.$('button:has-text("Demo")');
    check('Demo button visible', !!hasDemo);

    // 2. Create a pair
    console.log('[2] Create Pair');
    if (hasCreate) {
      await hasCreate.click();
      await page.waitForTimeout(2000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, '02-pair-created.png') });
      
      const pageContent = await page.textContent('body');
      const hasCode = /[A-Z0-9]{8}/.test(pageContent);
      check('Pairing code displayed', hasCode);
    }

    // 3. Try Demo Mode
    await page.evaluate(() => localStorage.clear());
    console.log('[3] Demo Mode');
    await page.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 15000 });
    await page.waitForTimeout(1000);
    
    const demoBtn = await page.$('text=Demo') || await page.$('button:has-text("Demo")') || await page.$('text=Try Demo');
    if (demoBtn) {
      await demoBtn.click();
      await page.waitForTimeout(2000);
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, '03-demo-compass.png') });
      
      const compass = await page.$('.compass, [class*="compass"], #compass, canvas');
      check('Compass element visible', !!compass);
      
      const poke = await page.$('text=Poke') || await page.$('button:has-text("Poke")') || await page.$('[class*="poke"]');
      check('Poke button visible', !!poke);
      
      if (poke) {
        await poke.click();
        await page.waitForTimeout(1500);
        await page.screenshot({ path: path.join(SCREENSHOT_DIR, '04-poke-result.png') });
        check('Poke button clickable', true);
      }
    } else {
      check('Demo button found', false);
    }

    // 4. Check responsive layout
    console.log('[4] Layout Check');
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    const viewWidth = await page.evaluate(() => window.innerWidth);
    check('No horizontal overflow', bodyWidth <= viewWidth + 5, `body: ${bodyWidth}, viewport: ${viewWidth}`);

  } catch (err) {
    check('Test execution', false, err.message);
  }

  await browser.close();

  // Write report
  const passed = results.filter(r => r.pass).length;
  const total = results.length;
  const report = `# LC Visual Test Report — ${new Date().toISOString()}

## Summary: ${passed}/${total} passed

${results.map(r => `- ${r.pass ? '✅' : '❌'} **${r.name}**${r.detail ? ': ' + r.detail : ''}`).join('\n')}

## Screenshots
${fs.readdirSync(SCREENSHOT_DIR).filter(f => f.endsWith('.png')).map(f => `- ${f}`).join('\n')}
`;
  
  console.log(`\n=== ${passed}/${total} passed ===`);
  fs.writeFileSync('/home/jarvis.linux/projects/lovers-compass/visual-test-report.md', report);
  process.exit(total - passed);
}

run().catch(err => { console.error(err); process.exit(1); });

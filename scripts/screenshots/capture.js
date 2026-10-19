// Снимает экраны трёх Flutter Web-сборок против локального backend с демо-данными
// (scripts/seed-demo-data.sh). Запускается через scripts/screenshots.sh.
//
// Flutter Web рисует в canvas, поэтому управляем им через дерево семантики
// (flt-semantics), которое включается кликом по flt-semantics-placeholder.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const OUT = process.env.OUT_DIR || 'screenshots';
const USER = process.env.USER_URL || 'http://localhost:8101/';
const BIZ = process.env.BUSINESS_URL || 'http://localhost:8102/';
const ADMIN = process.env.PLATFORM_URL || 'http://localhost:8103/';
const PASSWORD = process.env.DEMO_PASSWORD || 'Demo12345!';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'DemoAdmin123!';
const CHROME = process.env.CHROME_PATH; // по умолчанию — браузер Playwright

const ROLES = ['button', 'tab', 'link', 'checkbox', 'radio']
  .map((r) => `flt-semantics[role="${r}"]`).join(', ');

async function open(url, w, h, dark = false) {
  const browser = await chromium.launch({
    executablePath: CHROME,
    args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const ctx = await browser.newContext({
    viewport: { width: w, height: h }, deviceScaleFactor: 2, locale: 'en-US',
    colorScheme: dark ? 'dark' : 'light',
    geolocation: { latitude: 43.2383, longitude: 76.9455 }, permissions: ['geolocation'],
  });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(6000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);
  return { browser, page };
}

async function tap(page, text, wait = 2500) {
  let loc = page.locator(ROLES, { hasText: text }).first();
  if (!(await loc.count())) {
    loc = page.locator(ROLES.split(', ').map((r) => `${r}[aria-label*="${text}"]`).join(', ')).first();
  }
  await loc.click({ timeout: 8000 });
  await page.waitForTimeout(wait);
}

async function type(page, selector, text) {
  await page.locator(selector).first().click({ force: true });
  await page.waitForTimeout(300);
  await page.keyboard.type(text, { delay: 15 });
  await page.waitForTimeout(300);
}

async function scroll(page, dy) {
  await page.mouse.move(195, 400);
  await page.mouse.wheel(0, dy);
  await page.waitForTimeout(1200);
}

const shot = async (page, name) => {
  await page.screenshot({ path: `${OUT}/${name}.png` });
  console.log('shot', name);
};

async function emailLogin(page, email, password, button = 'Log in') {
  await tap(page, 'Continue with email');
  await type(page, 'input[aria-label="Email"]', email);
  await type(page, 'input[type=password]', password);
  await tap(page, button, 6000);
}

async function customer() {
  const { browser, page } = await open(USER, 390, 844);
  await shot(page, 'user-01-onboarding');
  await tap(page, 'Skip');
  await page.waitForTimeout(4000);
  await shot(page, 'user-02-home-guest');
  await tap(page, 'Search', 3500);
  await shot(page, 'user-03-search');
  await tap(page, 'Profile');
  await tap(page, 'Log in');
  await emailLogin(page, 'client@zairo-demo.test', PASSWORD);
  await shot(page, 'user-04-profile');
  await tap(page, 'Home', 4000);
  await shot(page, 'user-05-home');
  await tap(page, 'Search', 3500);
  await tap(page, 'Book', 5000);
  await scroll(page, 450);
  await shot(page, 'user-06a-services');
  // Picking a service brings the free times into view by itself ("Any master" is already chosen).
  await tap(page, 'Женская стрижка', 3500);
  await shot(page, 'user-06-times');
  await tap(page, 'Calendar', 1500);
  await shot(page, 'user-06b-calendar');
  // The first day that has free times ("…: free times"; busy days read "…: no free times").
  const day = await page.evaluateHandle((roles) => [...document.querySelectorAll(roles)]
    .find((e) => /: free times$/.test((e.getAttribute('aria-label') || e.textContent || '').trim())), ROLES);
  await day.asElement().click({ timeout: 8000 });
  await page.waitForTimeout(1800);
  // First free time of the chosen day (the "Soonest" chips start with the day, the list with the time).
  const chip = await page.evaluateHandle((roles) => [...document.querySelectorAll(roles)]
    .find((e) => /^\d{2}:\d{2}/.test((e.getAttribute('aria-label') || e.textContent || '').trim())), ROLES);
  await chip.asElement().click({ timeout: 8000 });
  await page.waitForTimeout(1500);
  await shot(page, 'user-06c-time-picked');
  await tap(page, 'Book', 4000);
  await shot(page, 'user-07-review-booking');
  await tap(page, 'Confirm booking', 6000);
  await shot(page, 'user-08-confirmed');
  await tap(page, 'Bookings', 4000);
  await shot(page, 'user-09-my-bookings');
  await browser.close();

  // Тёмная тема на самом узком экране.
  const dark = await open(USER, 360, 740, true);
  await tap(dark.page, 'Skip');
  await dark.page.waitForTimeout(4500);
  await shot(dark.page, 'user-10-home-dark-360');
  await tap(dark.page, 'Search', 3500);
  await shot(dark.page, 'user-11-search-dark-360');
  await dark.browser.close();
}

async function owner() {
  const { browser, page } = await open(BIZ, 1280, 800);
  await shot(page, 'business-01-login');
  await emailLogin(page, 'salon.almaty1@zairo-demo.test', PASSWORD);
  await shot(page, 'business-02-dashboard');
  for (const [item, name] of [['Campaigns', 'campaigns'], ['Loyalty', 'loyalty'],
    ['Automation Center', 'automation'], ['Subscription', 'subscription'],
    ['Messages', 'messages'], ['Settings', 'settings']]) {
    await tap(page, item, 4500);
    await shot(page, `business-${name}`);
  }
  await tap(page, 'Dashboard', 4000);
  await tap(page, 'Almaty Beauty Studio', 4500);
  await shot(page, 'business-03-business');
  await browser.close();
}

async function platform() {
  const { browser, page } = await open(ADMIN, 1280, 800);
  await type(page, 'input[type=text],input[type=email]', 'admin@zairo-demo.test');
  await type(page, 'input[type=password]', ADMIN_PASSWORD);
  await shot(page, 'platform-01-login');
  await tap(page, 'Log in', 6000).catch(() => tap(page, 'Sign in', 6000));
  await shot(page, 'platform-02-dashboard');
  for (const item of ['Businesses', 'Catalog', 'Cities', 'Ads', 'Reviews', 'Finance', 'Activity', 'Staff', 'Settings']) {
    await tap(page, item, 4000);
    await shot(page, `platform-${item.toLowerCase()}`);
  }
  await browser.close();
}

(async () => {
  require('fs').mkdirSync(OUT, { recursive: true });
  const which = process.argv[2] || 'all';
  if (which === 'all' || which === 'user') await customer();
  if (which === 'all' || which === 'business') await owner();
  if (which === 'all' || which === 'platform') await platform();
})().catch((e) => { console.error(e); process.exit(1); });

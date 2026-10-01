// Captures the client-demo screenshots from the running local platform
// (Proviyaa master on :5173, the vendor panel on :8642) at 1440×900, 2×.
//   PPT=<global puppeteer dir> node capture.cjs
// Logins come from backend/.data (local test accounts only).
const fs = require('fs');
const path = require('path');
const puppeteer = require(process.env.PPT);

const OUT = path.join(__dirname, 'shots');
const ONLY = process.env.ONLY; // ONLY=master re-captures just the master-admin shots (01-03)
if (!ONLY) fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
const accountsFile = fs.readFileSync(path.join(__dirname, '..', 'backend', '.data', 'laturspice-accounts.txt'), 'utf8');
const acct = (email) => {
  const line = accountsFile.split('\n').find((l) => l.split(/\s+/).includes(email));
  if (!line) throw new Error(`no login ${email} in laturspice-accounts.txt`);
  const parts = line.trim().split(/\s+/);
  return { email, password: parts[parts.indexOf(email) + 1] };
};
const owner = acct('owner@laturspice.test');
const manager2 = acct('manager2@laturspice.test');
const cashier = acct('cashier@laturspice.test');
const kitchen = acct('kitchen@laturspice.test');
const superadmin = fs.readFileSync(path.join(__dirname, '..', 'backend', '.data', 'LOGINS.txt'), 'utf8').split('\n').find((l) => l.includes('superadmin@')).trim().split(/\s+/);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let shot = 0;
async function snap(page, name) {
  shot++;
  const file = path.join(OUT, `${String(shot).padStart(2, '0')}-${name}.png`);
  await page.screenshot({ path: file });
  console.log('shot', path.basename(file));
}

// ── Flutter helpers: the app exposes its widgets as role/text nodes once
// the accessibility placeholder is clicked. ──
async function enableSemantics(page) {
  for (let i = 0; i < 20; i++) {
    const ok = await page.evaluate(() => {
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) { p.click(); return true; }
      return document.querySelectorAll('[role], [aria-label]').length > 0;
    });
    if (ok) break;
    await sleep(500);
  }
  await sleep(1500);
}
/// The visible node whose label or text matches [text].
async function labelled(page, text, { exact = true, pick = 'first', timeout = 15000 } = {}) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const handle = await page.evaluateHandle((text, exact, pick) => {
      const norm = (s) => (s || '').replace(/\s+/g, ' ').trim();
      const nodes = Array.from(document.querySelectorAll('flt-semantics, [role], [aria-label]'));
      const hits = nodes.filter((n) => {
        const label = norm(n.getAttribute('aria-label'));
        const txt = n.childElementCount === 0 ? norm(n.textContent) : '';
        const m = (v) => v && (exact ? v === text : v.startsWith(text));
        if (!(m(label) || m(txt))) return false;
        const r = n.getBoundingClientRect();
        return r.width > 0 && r.height > 0;
      });
      return hits.length ? hits[pick === 'last' ? hits.length - 1 : 0] : null;
    }, text, exact, pick);
    const el = handle.asElement();
    if (el) return el;
    await sleep(300);
  }
  throw new Error(`no element "${text}"`);
}
async function clickLabel(page, text, opts) {
  const el = await labelled(page, text, opts);
  await el.evaluate((n) => n.scrollIntoView({ block: 'center' }));
  await sleep(250);
  const box = await el.boundingBox();
  if (!box) throw new Error(`"${text}" has no box`);
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await sleep(700);
}
async function signIn(page, { email, password }) {
  await page.goto('http://localhost:8642/?demo=' + Date.now(), { waitUntil: 'networkidle2', timeout: 90000 });
  await sleep(5000);
  await enableSemantics(page);
  const inputs = await page.$$('input');
  if (inputs.length < 2) throw new Error('login fields not found');
  await inputs[0].click();
  await page.keyboard.type(email, { delay: 10 });
  await inputs[1].click();
  await page.keyboard.type(password, { delay: 10 });
  await page.keyboard.press('Enter');
  await sleep(10000);
  await enableSemantics(page);
}
async function signOut(page) {
  await clickLabel(page, 'Sign Out', { timeout: 8000 });
  await sleep(3000);
}
async function open(page, group, item, opts) {
  if (group) { try { await clickLabel(page, group, { timeout: 4000 }); } catch {} }
  await clickLabel(page, item, opts);
  await sleep(3500);
}

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--window-size=1440,900'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900, deviceScaleFactor: 2 });

  // ── 1. Proviyaa master ──
  await page.goto('http://localhost:5173/login', { waitUntil: 'networkidle2' });
  await sleep(1000);
  const masterInputs = await page.$$('input');
  if (masterInputs.length < 2) throw new Error('master login fields not found');
  await masterInputs[0].click();
  await page.keyboard.type(superadmin[0], { delay: 10 });
  await masterInputs[1].click();
  await page.keyboard.type(superadmin[1], { delay: 10 });
  await page.keyboard.press('Enter');
  for (let i = 0; i < 40 && /\/login/.test(page.url()); i++) await sleep(500);
  if (/\/login/.test(page.url())) throw new Error('master sign-in did not leave /login');
  await sleep(2500);
  const masterPage = async (url, heading) => {
    await page.goto(url, { waitUntil: 'networkidle2' });
    for (let i = 0; i < 20; i++) {
      const ok = await page.evaluate((h) => Array.from(document.querySelectorAll('h1,h2,h3')).some((e) => e.textContent.includes(h)), heading);
      if (ok) break;
      await sleep(500);
    }
    if (/\/login/.test(page.url())) throw new Error(`master page ${url} redirected to /login`);
    await sleep(2500);
  };
  await masterPage('http://localhost:5173/organizations/360', 'Partner');
  await snap(page, 'master-partners');
  await masterPage('http://localhost:5173/organizations/01e01c22-4c84-4ee9-882e-b24e64b044ed', 'Latur');
  await snap(page, 'master-partner');
  await page.evaluate(() => { const h = Array.from(document.querySelectorAll('h2,h3')).find((e) => /Location Management/.test(e.textContent)); h && h.scrollIntoView({ block: 'start' }); });
  await sleep(800);
  await snap(page, 'master-branches-logins');
  if (ONLY === 'master') { await browser.close(); console.log('done: master shots only'); return; }

  // ── 2. Owner ──
  await signIn(page, owner);
  await snap(page, 'owner-dashboard');
  await open(page, 'Master', 'Menu Items');
  await snap(page, 'menu-grid');
  await open(page, null, 'Media');
  await snap(page, 'media');
  await open(page, null, 'Inventory');
  await snap(page, 'inventory');
  await open(page, null, 'Recipes');
  await snap(page, 'recipes');
  await open(page, null, 'Suppliers');
  await snap(page, 'suppliers');
  await open(page, null, 'Purchase Orders');
  await snap(page, 'purchase-orders');
  await open(page, null, 'Offers');
  await snap(page, 'offers');
  await clickLabel(page, 'Master'); // collapse
  await open(page, 'Operations', 'Dine In');
  await snap(page, 'dine-in');
  await open(page, null, 'Reservations');
  await snap(page, 'reservations');
  await open(page, null, 'KOT / Kitchen');
  await snap(page, 'kot');
  await open(page, null, 'Live Operations');
  await snap(page, 'live-operations');
  await open(page, null, 'Delivery');
  await snap(page, 'delivery');
  await open(page, null, 'Online Orders');
  await snap(page, 'online-orders');
  await open(page, null, 'POS Billing');
  await snap(page, 'pos-billing');

  // offline: block the API, take a cash bill, then let it sync
  await page.setRequestInterception(true);
  const block = { on: true };
  page.on('request', (r) => (block.on && /localhost:8787/.test(r.url()) ? r.abort() : r.continue()));
  await sleep(5000);
  await clickLabel(page, 'Takeaway');
  await clickLabel(page, 'Mango Lassi', { exact: false });
  await clickLabel(page, 'Masala Chai', { exact: false });
  await sleep(1200);
  await snap(page, 'pos-offline-bill');
  await clickLabel(page, 'Settle & Close', { exact: false });
  await sleep(1500);
  await clickLabel(page, 'Settle', { pick: 'last' });
  await sleep(4000);
  await snap(page, 'pos-offline-settled');
  block.on = false;
  await clickLabel(page, 'Sync');
  await sleep(9000);
  await snap(page, 'pos-synced');
  // interception stays on (the listener now passes everything through)

  await clickLabel(page, 'Operations'); // collapse
  await open(page, 'Franchise / Chain', 'Command Center');
  await snap(page, 'command-center');
  await open(page, null, 'Branch Performance');
  await snap(page, 'branch-performance');
  await open(page, null, 'Inventory & Supply');
  await snap(page, 'chain-inventory');
  await clickLabel(page, 'Franchise / Chain'); // collapse
  await open(page, 'Staff & Users', 'Staff');
  await open(page, null, 'Staff', { pick: 'last' }); // the directory tab
  await snap(page, 'staff-directory');
  await open(page, null, 'Roles & Permissions');
  await snap(page, 'roles');
  await clickLabel(page, 'Staff & Users'); // collapse
  await open(page, null, 'Task Manager');
  await snap(page, 'tasks');
  await open(page, 'Customers & CRM', 'Customers');
  await snap(page, 'crm');
  await clickLabel(page, 'Customers & CRM'); // collapse
  await open(page, 'Finance', 'Payments');
  await snap(page, 'finance');
  await clickLabel(page, 'Finance'); // collapse
  await open(page, 'Integrations', 'Other', { exact: false });
  await snap(page, 'integrations');
  await signOut(page);

  // ── 3. Branch manager, cashier, kitchen ──
  await signIn(page, manager2);
  await snap(page, 'manager-dashboard');
  await open(page, 'Staff & Users', 'Staff');
  await open(page, null, 'Staff', { pick: 'last' });
  await snap(page, 'manager-staff');
  await signOut(page);
  await signIn(page, cashier);
  await snap(page, 'cashier-pos');
  await signOut(page);
  await signIn(page, kitchen);
  await snap(page, 'kitchen-kds');

  await browser.close();
  console.log('done:', shot, 'shots in', OUT);
})().catch((e) => { console.error('capture failed:', e.stack.split('\n').slice(0, 4).join(' / ')); process.exit(1); });

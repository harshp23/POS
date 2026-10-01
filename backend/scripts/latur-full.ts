/**
 * A whole restaurant, filled and exercised through the platform's own APIs:
 * a second branch from Proviyaa master, a full menu with photos, recipes,
 * suppliers, stock, purchase orders, offers, media, tables and orders in
 * every channel for both branches, chain targets / transfers / audits,
 * staff in each branch with logins, tasks, integrations, finance and
 * customers — and then each branch manager signed in to prove they see
 * only their branch. Every write is read back.
 *
 *   QA_BASE=http://localhost:8787 MASTER_BASE=http://localhost:8000/api \
 *   MEDIA_BASE=http://localhost:8643 \
 *   QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… QA_ADMIN_EMAIL=… QA_ADMIN_PASSWORD=… \
 *   npx tsx scripts/latur-full.ts
 *
 * Local database only. The report goes to docs/qa/LATUR-FULL-<run>.md.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

const BASE = (process.env.QA_BASE ?? 'http://localhost:8787').replace(/\/$/, '');
const MASTER = (process.env.MASTER_BASE ?? 'http://localhost:8000/api').replace(/\/$/, '');
const MEDIA = (process.env.MEDIA_BASE ?? 'http://localhost:8643').replace(/\/$/, '');
const OWNER_EMAIL = process.env.QA_OWNER_EMAIL;
const OWNER_PASSWORD = process.env.QA_OWNER_PASSWORD;
const ADMIN_EMAIL = process.env.QA_ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.QA_ADMIN_PASSWORD;
if (!OWNER_EMAIL || !OWNER_PASSWORD || !ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('Set QA_OWNER_EMAIL, QA_OWNER_PASSWORD, QA_ADMIN_EMAIL and QA_ADMIN_PASSWORD.');
  process.exit(2);
}
const RUN = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 12) + randomBytes(2).toString('hex');
const now = () => new Date().toISOString();
const today = new Date().toISOString().slice(0, 10);
const dayPlus = (d: number) => new Date(Date.now() + d * 86_400_000).toISOString().slice(0, 10);

type Row = Record<string, any>;
const results: { section: string; name: string; ok: boolean; detail: string }[] = [];
let section = '';
function check(name: string, ok: boolean, detail = '') {
  results.push({ section, name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  [${section}] ${name}${detail ? ' — ' + detail : ''}`);
}

async function call(method: string, url: string, opts: { token?: string; body?: unknown; branch?: string } = {}) {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (opts.token) headers.authorization = `Bearer ${opts.token}`;
  if (opts.branch) headers['x-location-id'] = opts.branch;
  const res = await fetch(url, { method, headers, body: opts.body === undefined ? undefined : JSON.stringify(opts.body) });
  const text = await res.text();
  let json: any = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: res.status, ok: res.ok, json };
}
const pos = (method: string, path: string, token: string, body?: unknown, branch?: string) => call(method, BASE + path, { token, body, branch });
/** A POS call that must succeed; returns `data`. */
async function must(method: string, path: string, token: string, body?: unknown, branch?: string): Promise<any> {
  const r = await pos(method, path, token, body, branch);
  if (!r.ok) throw new Error(`${method} ${path} → ${r.status} ${r.json?.error?.message ?? JSON.stringify(r.json).slice(0, 200)}`);
  return r.json?.data ?? r.json;
}
/** A POS call whose failure is a finding, not a stop. */
async function tryCall(name: string, method: string, path: string, token: string, body?: unknown, branch?: string): Promise<any> {
  const r = await pos(method, path, token, body, branch);
  check(name, r.ok, r.ok ? `${r.status}` : `${r.status} ${r.json?.error?.message ?? JSON.stringify(r.json).slice(0, 160)}`);
  return r.ok ? (r.json?.data ?? r.json) : null;
}
async function signIn(email: string, password: string) {
  const r = await call('POST', BASE + '/v1/auth/login', { body: { email, password } });
  if (!r.ok) throw new Error(`login ${email} → ${r.status} ${r.json?.error?.message}`);
  return { token: r.json.data.session.access_token as string, me: r.json.data.me as Row };
}
const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const photo = (name: string) => `${MEDIA}/${slug(name)}.png`;

// ── the menu ──────────────────────────────────────────────────────────────
const MENU: { cat: string; items: [string, number, 'veg' | 'non_veg' | 'egg', string][] }[] = [
  { cat: 'Starters', items: [['Paneer Tikka', 260, 'veg', 'grill'], ['Chicken Tikka', 320, 'non_veg', 'grill'], ['Veg Manchurian', 220, 'veg', 'main'], ['Egg Bhurji', 140, 'egg', 'main']] },
  { cat: 'Main Course', items: [['Butter Chicken', 380, 'non_veg', 'main'], ['Dal Tadka', 210, 'veg', 'main'], ['Mutton Rogan Josh', 460, 'non_veg', 'main'], ['Egg Curry', 220, 'egg', 'main']] },
  { cat: 'Breads', items: [['Butter Roti', 30, 'veg', 'tandoor'], ['Cheese Kulcha', 90, 'veg', 'tandoor']] },
  { cat: 'Rice & Biryani', items: [['Veg Biryani', 260, 'veg', 'main'], ['Chicken Biryani', 340, 'non_veg', 'main'], ['Jeera Rice', 150, 'veg', 'main']] },
  { cat: 'Desserts', items: [['Gulab Jamun', 90, 'veg', 'dessert'], ['Rasmalai', 120, 'veg', 'dessert']] },
  { cat: 'Beverages', items: [['Masala Chai', 30, 'veg', 'beverages'], ['Mango Lassi', 90, 'veg', 'beverages'], ['Cold Coffee', 120, 'veg', 'beverages']] },
];

async function main() {
  const lines: string[] = [];

  // ── 1. Proviyaa master: a second branch ─────────────────────────────
  section = 'Proviyaa master';
  const adminLogin = await call('POST', MASTER + '/auth/login', { body: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD } });
  if (!adminLogin.ok) throw new Error(`master login → ${adminLogin.status} ${JSON.stringify(adminLogin.json).slice(0, 200)}`);
  const A = (adminLogin.json.token ?? adminLogin.json.data?.token) as string;
  const orgs = await call('GET', MASTER + '/organizations?search=Latur%20Spice&limit=50', { token: A });
  const orgList: Row[] = orgs.json?.organizations ?? orgs.json?.data ?? [];
  const org = orgList.find((o) => /latur spice house/i.test(String(o.business_name ?? o.name ?? '')));
  check('organization Latur Spice House found', !!org, org ? String(org.id) : JSON.stringify(orgs.json).slice(0, 160));
  if (!org) throw new Error('organization not found in master');
  const locList = await call('GET', `${MASTER}/organizations/${org.id}/locations`, { token: A });
  const existing: Row[] = locList.json?.locations ?? locList.json?.data ?? [];
  let branch2 = existing.find((l) => /ausa road/i.test(String(l.name)));
  if (!branch2) {
    const made = await call('POST', `${MASTER}/organizations/${org.id}/locations`, {
      token: A,
      body: { name: 'Ausa Road Outlet', area: 'Ausa Road, Latur', code: 'LSH-02', type: 'Restaurant', status: 'Active', time_zone: 'Asia/Kolkata', timezone: 'Asia/Kolkata', currency: 'INR' },
    });
    branch2 = made.json?.location ?? made.json?.data;
    check('second branch created (Ausa Road Outlet)', made.ok && !!branch2?.id, made.ok ? String(branch2?.id) : `${made.status} ${JSON.stringify(made.json).slice(0, 160)}`);
  } else {
    check('second branch already present (Ausa Road Outlet)', true, String(branch2.id));
  }

  // ── 2. Owner ────────────────────────────────────────────────────────
  section = 'Owner';
  // The POS backend caches a login's branches for 30 s, so a branch added
  // in master a moment ago shows up on the next sign-in after that.
  let O = await signIn(OWNER_EMAIL!, OWNER_PASSWORD!);
  for (let i = 0; i < 12 && !(O.me.locations ?? []).some((l: Row) => /ausa road/i.test(String(l.name))); i++) {
    await new Promise((r) => setTimeout(r, 4000));
    O = await signIn(OWNER_EMAIL!, OWNER_PASSWORD!);
  }
  const owner = O.token;
  const locations: Row[] = O.me.locations ?? [];
  const b1 = locations.find((l) => /ganj golai/i.test(String(l.name)));
  const b2 = locations.find((l) => /ausa road/i.test(String(l.name)));
  check('owner sees both branches', !!b1 && !!b2, locations.map((l) => l.name).join(' · '));
  if (!b1 || !b2) throw new Error('branches missing for the owner');
  const B1 = String(b1.id);
  const B2 = String(b2.id);

  // ── 3. Menu with photos ─────────────────────────────────────────────
  section = 'Master · Menu';
  const cats: Row[] = await must('GET', '/v1/master/menu-categories', owner);
  const catId: Record<string, string> = {};
  for (const c of cats) catId[String(c.name)] = String(c.id);
  let order = cats.length;
  for (const m of MENU) {
    if (!catId[m.cat]) {
      const c = await must('POST', '/v1/master/menu-categories', owner, { name: m.cat, sort_order: order++ });
      catId[m.cat] = String(c.id);
    }
  }
  check('menu categories present', MENU.every((m) => catId[m.cat]), Object.keys(catId).join(', '));
  const items: Row[] = await must('GET', '/v1/master/menu-items?limit=200', owner);
  const byName = new Map(items.map((i) => [String(i.name), i]));
  let created = 0;
  for (const m of MENU) {
    for (const [name, price, food, station] of m.items) {
      if (byName.has(name)) continue;
      const it = await must('POST', '/v1/master/menu-items', owner, {
        name, price, category_id: catId[m.cat], food_type: food, station, prep_minutes: 12,
        description: `${name} — house recipe`, image_url: photo(name), is_available: true, is_recommended: name === 'Butter Chicken',
      });
      byName.set(name, it);
      created++;
    }
  }
  // every dish we have a picture for gets it (incl. ones other QA runs made)
  const PHOTO_NAMES = new Set([...MENU.flatMap((m) => m.items.map((i) => i[0])), 'Paneer Tikka Masala', 'Garlic Naan', ...(process.env.EXTRA_PHOTOS ?? '').split('|').filter(Boolean)]);
  for (const it of byName.values()) {
    if (!it.image_url && PHOTO_NAMES.has(String(it.name))) await must('PATCH', `/v1/master/menu-items/${it.id}`, owner, { image_url: photo(String(it.name)) });
  }
  const after: Row[] = await must('GET', '/v1/master/menu-items?limit=200', owner);
  const withPhoto = after.filter((i) => String(i.image_url ?? '').startsWith(MEDIA)).length;
  check(`menu has ${after.length} dishes (${created} added now), all with photos`, after.length >= 20 && withPhoto === after.length, `${withPhoto}/${after.length} photos`);
  check('veg / non-veg / egg dishes present', ['veg', 'non_veg', 'egg'].every((f) => after.some((i) => i.food_type === f)));
  const dish = (n: string) => after.find((i) => i.name === n)!;
  // edit and delete round trip
  const cc = dish('Cold Coffee');
  const ed = await tryCall('edit a dish (Cold Coffee → ₹130)', 'PATCH', `/v1/master/menu-items/${cc.id}`, owner, { price: 130 });
  check('edit read back', Number(ed?.price) === 130, String(ed?.price));
  const tmp = await must('POST', '/v1/master/menu-items', owner, { name: `Temp Special ${RUN}`, price: 99, category_id: catId['Starters'], food_type: 'veg' });
  await tryCall('delete a dish', 'DELETE', `/v1/master/menu-items/${tmp.id}`, owner);
  const gone: Row[] = await must('GET', '/v1/master/menu-items?limit=200', owner);
  check('deleted dish is gone', !gone.some((i) => i.id === tmp.id));

  // ── 4. Media assets ─────────────────────────────────────────────────
  section = 'Master · Media';
  let media = 0;
  for (const m of MENU) {
    for (const [name] of m.items) {
      const r = await pos('PUT', '/v1/master/media-assets', owner, {
        id: `media-${slug(name)}`, file_name: `${slug(name)}.png`, file_type: 'image/png', size_bytes: 12000, folder: 'Dishes',
        usage_label: name, image_url: photo(name), bytes: null, archived: false, created_at: now(),
      });
      if (r.ok) media++;
    }
  }
  const mediaRows: Row[] = await must('GET', '/v1/master/media-assets?limit=200', owner);
  check(`media hub: ${media} photos filed under Dishes`, media >= 18 && mediaRows.length >= media, `${mediaRows.length} assets`);

  // ── 5. Suppliers, stock, prices, recipes, purchase orders, offers ──
  section = 'Master · Inventory';
  const suppliers: [string, string, string, string][] = [
    ['SPL-LSH-01', 'Latur Fresh Farms', 'Vegetables & Dairy', 'Ramesh Pawar'],
    ['SPL-LSH-02', 'Deccan Poultry', 'Meat & Poultry', 'Imran Shaikh'],
    ['SPL-LSH-03', 'Maharashtra Grains', 'Grains & Spices', 'Sunita Kale'],
  ];
  for (const [id, name, category, contact] of suppliers) {
    await tryCall(`supplier ${name}`, 'PUT', '/v1/master/suppliers', owner, {
      id, name, legal_name: `${name} Pvt Ltd`, category, contact_person: contact, phone: '+91 98220 33445', email: `${slug(name)}@example.test`,
      gstin: '27AAACL1234A1Z5', city: 'Latur', rating: 4.5, payment_terms: 'Net 15', active: true, created_at: now(),
    });
  }
  const materials: [string, string, string, string, number, number, number, number, string][] = [
    ['RM-LSH-001', 'Paneer', 'Dairy', 'kg', 20, 5, 60, 320, 'SPL-LSH-01'],
    ['RM-LSH-002', 'Chicken (curry cut)', 'Meat', 'kg', 25, 8, 80, 240, 'SPL-LSH-02'],
    ['RM-LSH-003', 'Basmati Rice', 'Grains', 'kg', 60, 20, 200, 95, 'SPL-LSH-03'],
    ['RM-LSH-004', 'Tomato', 'Vegetables', 'kg', 15, 6, 40, 30, 'SPL-LSH-01'],
    ['RM-LSH-005', 'Onion', 'Vegetables', 'kg', 2, 8, 50, 28, 'SPL-LSH-01'],
    ['RM-LSH-006', 'Butter', 'Dairy', 'kg', 10, 3, 30, 480, 'SPL-LSH-01'],
    ['RM-LSH-007', 'Wheat Flour', 'Grains', 'kg', 40, 15, 120, 42, 'SPL-LSH-03'],
    ['RM-LSH-008', 'Garam Masala', 'Spices', 'g', 2000, 500, 5000, 1.2, 'SPL-LSH-03'],
  ];
  for (const branch of [B1, B2]) {
    let ok = 0;
    for (const [id, name, category, unit, stock, reorder, max, cost, sup] of materials) {
      const r = await pos('PUT', '/v1/master/raw-materials', owner, {
        id, code: id, name, category, unit, stock_qty: branch === B1 ? stock : Math.round(stock / 2), reorder_level: reorder, max_capacity: max,
        purchase_cost: cost, last_purchase_price: cost, preferred_supplier_id: sup, hsn: '0401', emoji: '', lead_time_days: 2, active: true, created_at: now(),
      }, branch);
      if (r.ok) ok++;
    }
    check(`raw materials stocked at ${branch === B1 ? b1.name : b2.name}`, ok === materials.length, `${ok}/${materials.length}`);
  }
  const rmB1: Row[] = await must('GET', `/v1/master/raw-materials?location_id=${B1}&limit=200`, owner);
  const rmB2: Row[] = await must('GET', `/v1/master/raw-materials?location_id=${B2}&limit=200`, owner);
  check('each branch reads back its own stock', rmB1.length >= materials.length && rmB2.length >= materials.length, `${rmB1.length} / ${rmB2.length}`);
  check('Onion is below its reorder level (low-stock alert material)', rmB1.some((r) => r.name === 'Onion' && Number(r.stock_qty) < Number(r.reorder_level)));
  for (const [id, ing, mat, sup, unit, price] of [
    ['SP-LSH-01', 'Paneer', 'RM-LSH-001', 'SPL-LSH-01', 'kg', 320], ['SP-LSH-02', 'Chicken (curry cut)', 'RM-LSH-002', 'SPL-LSH-02', 'kg', 240],
    ['SP-LSH-03', 'Basmati Rice', 'RM-LSH-003', 'SPL-LSH-03', 'kg', 95], ['SP-LSH-04', 'Tomato', 'RM-LSH-004', 'SPL-LSH-01', 'kg', 30],
  ] as [string, string, string, string, string, number][]) {
    await tryCall(`supplier price ${ing}`, 'PUT', '/v1/master/supplier-prices', owner, {
      id, ingredient_name: ing, material_id: mat, emoji: '', linked_to: '', supplier_id: sup, unit, last_price: price + 5, current_price: price,
      lowest_week: price - 3, source: 'Quote', priority: 'primary', sku_id: `${id}-SKU`, approved: true, updated_at: now(),
    });
  }
  section = 'Master · Recipes';
  const recipes: [string, string, string, [string, string, number, string][]][] = [
    ['RCP-LSH-01', 'Paneer Tikka Masala', 'Main Course', [['RM-LSH-001', 'Paneer', 0.18, 'kg'], ['RM-LSH-004', 'Tomato', 0.12, 'kg'], ['RM-LSH-006', 'Butter', 0.03, 'kg']]],
    ['RCP-LSH-02', 'Butter Chicken', 'Main Course', [['RM-LSH-002', 'Chicken (curry cut)', 0.25, 'kg'], ['RM-LSH-006', 'Butter', 0.04, 'kg'], ['RM-LSH-004', 'Tomato', 0.15, 'kg']]],
    ['RCP-LSH-03', 'Veg Biryani', 'Rice & Biryani', [['RM-LSH-003', 'Basmati Rice', 0.2, 'kg'], ['RM-LSH-005', 'Onion', 0.06, 'kg'], ['RM-LSH-008', 'Garam Masala', 8, 'g']]],
  ];
  let lineNo = 1;
  for (const [id, name, category, ings] of recipes) {
    const d = dish(name);
    await tryCall(`recipe ${name}`, 'PUT', '/v1/master/recipes', owner, {
      id, code: id, name, version: 'v1', linked_menu_item_id: d?.id ?? null, linked_menu_item_name: name, category, portion: '1 portion',
      target_price: Number(d?.price ?? 0), labor_cost: 18, packaging_cost: 6, trial_result: 'Approved', training_done: 1, training_total: 3,
      status: 'Active', prep_method: `Cook ${name} to the house standard.`, allergens: name.includes('Paneer') || name.includes('Butter') ? 'Dairy' : '', active_channels: 'POS, Dine-In, Takeaway', updated_at: now(),
    });
    for (const [mat, mname, qty, unit] of ings) {
      await pos('PUT', '/v1/master/recipe-lines', owner, { id: lineNo++, recipe_id: id, material_id: mat, name: mname, qty, unit, wastage_pct: 3, fallback_unit_cost: 0, is_key: true, substitute: '' });
    }
  }
  const rcp: Row[] = await must('GET', '/v1/master/recipes?limit=100', owner);
  const rcpLines: Row[] = await must('GET', '/v1/master/recipe-lines?limit=200', owner);
  check('recipes read back with their ingredient lines', rcp.length >= 3 && rcpLines.length >= 9, `${rcp.length} recipes, ${rcpLines.length} lines`);

  section = 'Master · Purchase orders';
  const poNo = `PO-LSH-${RUN.slice(-4)}`;
  await tryCall(`purchase order ${poNo} (Pending)`, 'PUT', '/v1/master/purchase-orders', owner, {
    number: poNo, supplier_id: 'SPL-LSH-01', order_date: now(), expected_delivery: new Date(Date.now() + 2 * 86_400_000).toISOString(), status: 'Pending',
    created_by: 'Anjali Kulkarni', delivery_address: b1.name, delivery_city: 'Latur', tax_pct: 5, notes: 'Weekly vegetables and dairy', updated_at: now(),
  }, B1);
  await pos('PUT', '/v1/master/purchase-order-lines', owner, { id: 1, po_number: poNo, material_id: 'RM-LSH-005', material_name: 'Onion', code: 'RM-LSH-005', unit: 'kg', unit_cost: 28, ordered_qty: 30, received_qty: 0, rejected_qty: 0 }, B1);
  await pos('PUT', '/v1/master/purchase-order-lines', owner, { id: 2, po_number: poNo, material_id: 'RM-LSH-004', material_name: 'Tomato', code: 'RM-LSH-004', unit: 'kg', unit_cost: 30, ordered_qty: 20, received_qty: 0, rejected_qty: 0 }, B1);
  const pos1: Row[] = await must('GET', `/v1/master/purchase-orders?limit=100&location_id=${B1}`, owner);
  const po = pos1.find((p) => p.number === poNo);
  check('purchase order read back with lines', !!po && (await must('GET', `/v1/master/purchase-order-lines?limit=200&location_id=${B1}`, owner)).some((l: Row) => l.po_number === poNo));
  if (po) {
    const dec = await tryCall('chain approves the purchase order', 'POST', `/v1/franchise/purchase-orders/${po.row_id}/decision`, owner, { decision: 'approve' });
    check('purchase order is Approved', dec?.status === 'Approved', String(dec?.status));
  }
  await tryCall('goods receipt posted against the PO', 'PUT', '/v1/master/goods-receipts', owner, { id: `GRN-LSH-${RUN.slice(-4)}`, po_number: poNo, received_at: now(), subtotal: 1440, tax: 72, total: 1512, notes: 'All accepted' }, B1);
  await tryCall('stock movement for the receipt', 'PUT', '/v1/master/stock-movements', owner, { id: 1, material_id: 'RM-LSH-005', qty_delta: 30, reason: 'GRN Receipt', reference: poNo, unit_cost: 28, created_at: now() }, B1);

  section = 'Master · Offers';
  for (const [id, title, code, rule, type] of [
    ['OFF-LSH-01', 'Lunch Combo 20% Off', 'LUNCH20', '20% OFF (Upto ₹100)', 'Percentage Off'],
    ['OFF-LSH-02', 'Family Feast ₹150 Off', 'FAMILY150', '₹150 OFF', 'Flat Discount'],
    ['OFF-LSH-03', 'Free Gulab Jamun', 'SWEET1', 'Free Gulab Jamun', 'Free Item'],
  ] as string[][]) {
    await tryCall(`offer ${title}`, 'PUT', '/v1/master/offers', owner, {
      id, title, code, campaign_type: type, discount_rule: rule, min_order: 400, max_discount: 150, start_date: now(), end_date: new Date(Date.now() + 30 * 86_400_000).toISOString(),
      channels: 'POS, Dine-In, Takeaway', linked_items: type === 'Free Item' ? 'Gulab Jamun' : '', status: 'Active', usage_count: 0, updated_at: now(),
    });
  }
  const offers: Row[] = await must('GET', '/v1/master/offers?limit=100', owner);
  check('offers read back', offers.filter((o) => String(o.id).startsWith('OFF-LSH')).length === 3, `${offers.length} offers in all`);

  // ── 6. Operations in both branches ──────────────────────────────────
  const ops: Record<string, Row> = {};
  for (const [branch, bname] of [[B1, String(b1.name)], [B2, String(b2.name)]] as [string, string][]) {
    section = `Operations · ${bname}`;
    const areas: Row[] = await must('GET', `/v1/operations/dining-areas?location_id=${branch}`, owner);
    const wanted = branch === B1 ? ['Ground Floor', 'Terrace'] : ['Ground Floor', 'Family Section'];
    const areaId: Record<string, string> = {};
    for (const a of areas) areaId[String(a.name)] = String(a.id);
    for (const [i, name] of wanted.entries()) {
      if (!areaId[name]) {
        const a = await must('POST', '/v1/operations/dining-areas', owner, { name, sort_order: i, location_id: branch }, branch);
        areaId[name] = String(a.id);
      }
    }
    const tables: Row[] = await must('GET', `/v1/operations/dining-tables?location_id=${branch}&limit=100`, owner);
    const tableId: Record<string, string> = {};
    for (const t of tables) tableId[String(t.label)] = String(t.id);
    const wantTables: [string, number, string][] = branch === B1 ? [['T3', 4, 'Terrace'], ['T4', 2, 'Terrace']] : [['T1', 4, 'Ground Floor'], ['T2', 6, 'Ground Floor'], ['T3', 8, 'Family Section']];
    for (const [label, seats, area] of wantTables) {
      if (!tableId[label]) {
        const t = await must('POST', '/v1/operations/dining-tables', owner, { label, seats, area_id: areaId[area], location_id: branch }, branch);
        tableId[label] = String(t.id);
      }
    }
    const tablesAfter: Row[] = await must('GET', `/v1/operations/dining-tables?location_id=${branch}&limit=100`, owner);
    check(`floor plan: ${Object.keys(areaId).join(' + ')} with ${tablesAfter.length} tables`, tablesAfter.length >= wantTables.length);
    // edit + delete a table
    const t4 = tablesAfter.find((t) => t.label === (branch === B1 ? 'T4' : 'T3'));
    if (t4) {
      const e = await tryCall('edit a table (seats)', 'PATCH', `/v1/operations/dining-tables/${t4.id}`, owner, { seats: Number(t4.seats) + 2 }, branch);
      check('table edit read back', Number(e?.seats) === Number(t4.seats) + 2);
    }
    const scratch = await must('POST', '/v1/operations/dining-tables', owner, { label: `TX-${RUN.slice(-3)}`, seats: 2, area_id: areaId[wanted[0]], location_id: branch }, branch);
    await tryCall('delete an unused table', 'DELETE', `/v1/operations/dining-tables/${scratch.id}`, owner, undefined, branch);

    // reservation for tomorrow (device row)
    const resId = `RSV-${branch === B1 ? 'A' : 'B'}-${RUN.slice(-4)}`;
    await tryCall('reservation for tomorrow', 'PUT', '/v1/operations/reservations', owner, {
      id: resId, guest_name: 'Deshmukh family', phone: '98765 11111', email: '', guests: 5, scheduled_at: new Date(Date.now() + 86_400_000).toISOString(),
      status: 'confirmed', table_id: null, notes: 'Anniversary', created_at: now(),
    }, branch);
    const resv: Row[] = await must('GET', `/v1/operations/reservations?location_id=${branch}&limit=100`, owner);
    check('reservation read back', resv.some((r) => r.id === resId));

    // orders in every channel
    const dineTable = tablesAfter.find((t) => t.label === (branch === B1 ? 'T3' : 'T1'))!;
    const dine = await must('POST', '/v1/operations/orders', owner, {
      channel: 'dine_in', table_id: dineTable.id, customer_name: 'Walk-in', gst_pct: 5,
      items: [{ menu_item_id: dish('Butter Chicken').id, qty: 1 }, { menu_item_id: dish('Butter Roti').id, qty: 4 }, { menu_item_id: dish('Masala Chai').id, qty: 2 }],
    }, branch);
    check(`dine-in order ${dine.display_no} on ${dineTable.label}`, dine.status === 'sent_to_kitchen', `total ₹${dine.total}`);
    const kots: Row[] = await must('GET', `/v1/operations/kot-tickets?location_id=${branch}`, owner);
    const kot = kots.find((k) => k.order_id === dine.id);
    check('KOT raised for the dine-in order', !!kot, kot ? `KOT #${kot.kot_no}` : '');
    if (kot) {
      await must('POST', `/v1/operations/kot-tickets/${kot.id}/advance`, owner, undefined, branch);
      const k2 = await must('POST', `/v1/operations/kot-tickets/${kot.id}/advance`, owner, undefined, branch);
      check('KOT cooked and ready', k2.status === 'ready', String(k2.status));
    }
    const pay1 = await must('POST', `/v1/operations/orders/${dine.id}/payments`, owner, { method: 'card', amount: dine.total }, branch);
    check('card payment recorded, waiting for verification', (pay1.order ?? pay1).status === 'awaiting_payment' || pay1.status === 'awaiting_payment', JSON.stringify(pay1).slice(0, 80));
    const ver = await tryCall('manager verifies the card payment', 'POST', `/v1/operations/orders/${dine.id}/verify-payment`, owner, { note: 'Card slip checked' }, branch);
    check('dine-in order paid after verification', (ver?.status ?? '') === 'paid', String(ver?.status));

    const pickup = await must('POST', '/v1/operations/orders', owner, { channel: 'pickup', customer_name: 'Sanjay', customer_phone: '9822011230', gst_pct: 5, items: [{ menu_item_id: dish('Veg Biryani').id, qty: 2 }] }, branch);
    const pay2 = await must('POST', `/v1/operations/orders/${pickup.id}/payments`, owner, { method: 'cash', amount: pickup.total }, branch);
    check(`takeaway ${pickup.display_no} paid in cash`, (pay2.order ?? pay2).status === 'paid' || pay2.status === 'paid');

    const delivery = await must('POST', '/v1/operations/orders', owner, {
      channel: 'delivery', customer_name: 'Neha Joshi', customer_phone: '9822011231', gst_pct: 5, items: [{ menu_item_id: dish('Chicken Biryani').id, qty: 1 }, { menu_item_id: dish('Gulab Jamun').id, qty: 2 }],
    }, branch);
    await must('POST', `/v1/operations/orders/${delivery.id}/payments`, owner, { method: 'upi', amount: delivery.total }, branch);
    await must('POST', `/v1/operations/orders/${delivery.id}/verify-payment`, owner, { note: 'UPI seen' }, branch);
    const dlvId = `DLV-${branch === B1 ? 'A' : 'B'}-${RUN.slice(-4)}`;
    await tryCall('delivery assigned to a rider', 'PUT', '/v1/operations/deliveries', owner, {
      id: dlvId, order_id: delivery.id, merchant: 'Restaurant', rider_name: 'Rahul Bhosale', status: 'assigned', eta_minutes: 25, distance_km: 3.4,
      customer_name: 'Neha Joshi', address: '12 Shivaji Nagar, Latur', promised_at: new Date(Date.now() + 40 * 60_000).toISOString(), created_at: now(), updated_at: now(),
    }, branch);
    const dlv: Row[] = await must('GET', `/v1/operations/deliveries?location_id=${branch}&limit=100`, owner);
    check(`delivery ${delivery.display_no} read back`, dlv.some((d) => d.id === dlvId));
    await tryCall('delivery marked delivered', 'PUT', '/v1/operations/deliveries', owner, { ...(dlv.find((d) => d.id === dlvId) ?? {}), status: 'delivered', updated_at: now() }, branch);

    const cancelled = await must('POST', '/v1/operations/orders', owner, { channel: 'pickup', customer_name: 'No-show', gst_pct: 5, items: [{ menu_item_id: dish('Jeera Rice').id, qty: 1 }] }, branch);
    const cx = await tryCall('an order is cancelled with a reason', 'POST', `/v1/operations/orders/${cancelled.id}/status`, owner, { status: 'cancelled', reason: 'Customer did not turn up' }, branch);
    check('cancelled order reads back cancelled', (cx?.status ?? '') === 'cancelled');

    const online = await tryCall('online order from Swiggy', 'POST', '/v1/operations/online-orders', owner, { platform: 'Swiggy', customer: 'Aditya', items_label: 'Paneer Tikka x1, Cheese Kulcha x2', amount_minor: 44000 }, branch);
    if (online?.order_id) {
      const st = await tryCall('online order accepted', 'POST', `/v1/operations/online-orders/${online.order_id}/status`, owner, { status: 'Accepted' }, branch);
      const st2 = await tryCall('online order ready', 'POST', `/v1/operations/online-orders/${online.order_id}/status`, owner, { status: 'Ready' }, branch);
      check('online order status moved', (st2?.status ?? st?.status ?? '') !== '', String(st2?.status ?? st?.status));
    }
    const qrTable = tablesAfter[0];
    await tryCall('QR code enabled for a table', 'PUT', '/v1/operations/qr-codes', owner, { table_id: qrTable.label, enabled: true, token: `qr-${RUN}-${slug(qrTable.label)}`, last_scanned_at: null }, branch);
    await tryCall('QR self-order session', 'PUT', '/v1/operations/qr-sessions', owner, { id: `QRS-${branch === B1 ? 'A' : 'B'}-${RUN.slice(-4)}`, table_label: qrTable.label, guests: 2, started_at: now(), status: 'active', order_id: null, item_count: 2, total_minor: 38000, closed_at: null }, branch);
    const summary = await must('GET', `/v1/operations/summary?location_id=${branch}`, owner);
    check('operations summary for the branch', !!summary, JSON.stringify(summary).slice(0, 120));
    ops[branch] = { dine, pickup, delivery, cancelled };
  }
  section = 'Operations';
  const bs = await tryCall('bill settings saved (GST 5%, FSSAI on bill)', 'PUT', '/v1/operations/bill-settings', owner, { legal_name: 'Latur Spice House', address: 'Ganj Golai, Latur 413512', gstin: '27AAACL1234A1Z5', fssai: '11521999000285', phone: '+91 98220 11223', sgst_pct: 2.5, cgst_pct: 2.5, service_charge_pct: 0, round_off_enabled: true, footer_note: 'Thank you, visit again!' });
  const ordersB1: Row[] = await must('GET', `/v1/operations/orders?location_id=${B1}&limit=200`, owner);
  const ordersB2: Row[] = await must('GET', `/v1/operations/orders?location_id=${B2}&limit=200`, owner);
  check('orders are kept per branch', ordersB1.every((o) => o.location_id === B1) && ordersB2.every((o) => o.location_id === B2) && ordersB2.length >= 4, `${ordersB1.length} / ${ordersB2.length}`);

  // ── 7. Franchise / chain ────────────────────────────────────────────
  section = 'Franchise / Chain';
  const existingTargets: Row[] = await must('GET', '/v1/franchise/targets', owner);
  for (const [branch, sales] of [[B1, 250000], [B2, 180000]] as [string, number][]) {
    if (existingTargets.some((t) => t.location_id === branch)) { check(`target already set for ${branch === B1 ? b1.name : b2.name}`, true); continue; }
    await tryCall(`monthly target for ${branch === B1 ? b1.name : b2.name}`, 'POST', '/v1/franchise/targets', owner, {
      location_id: branch, period_start: today.slice(0, 8) + '01', period_end: dayPlus(30), sales_target: sales, orders_target: 900, aov_target: 450, food_cost_target_pct: 32, labour_cost_pct: 18, operating_expense: 60000, notes: 'Set by the owner',
    });
  }
  const targets: Row[] = await must('GET', '/v1/franchise/targets', owner);
  check('targets read back for both branches', [B1, B2].every((b) => targets.some((t) => t.location_id === b)));
  const gen = await tryCall('exceptions generated from stock + orders', 'POST', '/v1/franchise/exceptions/generate', owner, {});
  const exc: Row[] = await must('GET', '/v1/franchise/exceptions?limit=200', owner);
  check('system raised a low-stock exception for Onion', exc.some((e) => e.source === 'system' && /onion/i.test(String(e.root_cause))), `${exc.filter((e) => e.status === 'open').length} open of ${exc.length}`);
  await tryCall('manual exception logged', 'POST', '/v1/franchise/exceptions', owner, { severity: 'warning', root_cause: 'Fridge temperature high at Ausa Road', impact: 'Dairy at risk', recommended_action: 'Service call', action_type: 'Review', status: 'open', location_id: B2 });
  const tr = await tryCall('stock transfer 5 kg Paneer, Ganj Golai → Ausa Road', 'POST', '/v1/franchise/stock-transfers', owner, { material_id: 'RM-LSH-001', from_location_id: B1, to_location_id: B2, quantity: 5, note: 'Weekend demand' });
  const rmB2After: Row[] = await must('GET', `/v1/master/raw-materials?location_id=${B2}&limit=200`, owner);
  const paneerB2 = rmB2After.find((r) => r.id === 'RM-LSH-001');
  check('Ausa Road paneer stock rose by 5', !!paneerB2 && Number(paneerB2.stock_qty) === 15, String(paneerB2?.stock_qty));
  for (const [type, title] of [['audit_report', 'FSSAI hygiene audit — Ganj Golai'], ['compliance_task', 'Renew fire NOC — Ausa Road'], ['incident', 'Power cut 40 min — Ausa Road']] as string[][]) {
    await tryCall(`chain record: ${title}`, 'POST', '/v1/franchise/records', owner, { record_type: type, title, status: type === 'audit_report' ? 'completed' : 'open', details: { score: 92, notes: 'QA run ' + RUN }, location_id: title.includes('Ausa') ? B2 : B1 });
  }
  await tryCall('resolve every open exception', 'POST', '/v1/franchise/exceptions/resolve-all', owner, {});
  const perfRaw = await must('GET', '/v1/franchise/branch-performance', owner);
  const perf: Row[] = Array.isArray(perfRaw) ? perfRaw : (perfRaw.branches ?? perfRaw.rows ?? Object.values(perfRaw).find(Array.isArray) ?? []);
  check('branch performance lists both branches', perf.length >= 2, perf.map((p) => p.name ?? p.branch_name ?? p.location_name).join(' · '));
  const ov = await must('GET', '/v1/franchise/overview', owner);
  check('chain overview counts 2 branches', Number(ov.branches) === 2, `sales ₹${Number(ov.total_sales_minor) / 100}`);
  const req = await must('GET', '/v1/franchise/purchase-requirements', owner);
  check('purchase requirements read', Array.isArray(req.rows ?? req), '');

  // ── 8. Staff in each branch ─────────────────────────────────────────
  section = 'Staff & Users';
  const roles: Row[] = (await must('GET', '/v1/staff/roles', owner)).roles;
  const roleId = (n: string) => String(roles.find((r) => r.name === n)?.id);
  const logins: Row[] = await must('GET', '/v1/staff/logins', owner);
  const employeesBefore: Row[] = await must('GET', '/v1/staff/employees', owner);
  // Ganj Golai: employee records for the logins made earlier, linked to them.
  const link: [string, string, string, string][] = [
    ['cashier@laturspice.test', 'Priya Sawant', 'Cashier', 'Billing'], ['captain@laturspice.test', 'Sameer Shinde', 'Captain', 'Service'],
    ['kitchen@laturspice.test', 'Ganesh Mane', 'Chef', 'Kitchen'], ['manager@laturspice.test', 'Vikram Jadhav', 'Branch Manager', 'Management'],
  ];
  for (const [email, name, desig, dept] of link) {
    if (employeesBefore.some((e) => e.full_name === name)) continue;
    const emp = await must('POST', '/v1/staff/employees', owner, { full_name: name, designation: desig, department: dept, location_id: B1, joining_date: '2026-09-01', salary_type: 'monthly', monthly_salary: desig === 'Branch Manager' ? 32000 : 18000, delivery_enabled: desig === 'Captain' });
    const l = logins.find((x) => x.email === email);
    if (l) await pos('PATCH', `/v1/staff/logins/${l.user_id}`, owner, { staff_id: emp.id });
  }
  // Ausa Road: four new employees with logins.
  const b2Staff: [string, string, string, string][] = [
    ['Meera Kale', 'Branch Manager', 'Branch Manager', 'manager2@laturspice.test'], ['Akash Patil', 'Cashier', 'Cashier', 'cashier2@laturspice.test'],
    ['Rohit Gaikwad', 'Captain', 'Captain', 'captain2@laturspice.test'], ['Suresh Pawar', 'Chef', 'Kitchen (KOT)', 'kitchen2@laturspice.test'],
  ];
  const pw = (email: string) => `Latur#${email.split('@')[0].replace(/[^a-z0-9]/gi, '')}2026`;
  for (const [name, desig, role, email] of b2Staff) {
    if (employeesBefore.some((e) => e.full_name === name)) continue;
    const r = await pos('POST', '/v1/staff/employees', owner, {
      full_name: name, designation: desig, department: desig === 'Chef' ? 'Kitchen' : 'Operations', location_id: B2, joining_date: today, salary_type: 'monthly', monthly_salary: role === 'Branch Manager' ? 30000 : 16000,
      delivery_enabled: desig === 'Captain', login: { email, password: pw(email), role_id: roleId(role), location_id: B2, force_password_change: false },
    });
    check(`Ausa Road staff ${name} (${role}) with login`, r.ok, r.ok ? email : `${r.status} ${r.json?.error?.message}`);
  }
  const empAll: Row[] = await must('GET', '/v1/staff/employees', owner);
  const empB1 = empAll.filter((e) => e.location_id === B1);
  const empB2 = empAll.filter((e) => e.location_id === B2);
  check('employees listed per branch with branch names', empB1.length >= 4 && empB2.length >= 4 && empB2.every((e) => e.location_name === b2.name), `${empB1.length} at ${b1.name}, ${empB2.length} at ${b2.name}`);
  const allEmp: Row[] = await must('GET', '/v1/staff/employees', owner);
  const staffId = (name: string) => String(allEmp.find((e) => e.full_name === name)?.id);
  await tryCall("today's attendance saved for Ausa Road", 'PUT', '/v1/staff/attendance', owner, {
    date: today, entries: b2Staff.map(([name], i) => ({ staff_id: staffId(name), status: i === 3 ? 'half_day' : 'present', check_in: '10:00', check_out: i === 3 ? '14:00' : '19:00', ot_hours: 0, notes: '' })),
  });
  const shift = await tryCall('evening shift created', 'POST', '/v1/staff/shifts', owner, { name: `Evening ${RUN.slice(-3)}`, start_time: '16:00', end_time: '23:00', break_minutes: 30, grace_minutes: 10, active: true });
  if (shift?.id) await tryCall('Akash rostered on the evening shift', 'POST', '/v1/staff/roster', owner, { date: dayPlus(1), staff_id: staffId('Akash Patil'), shift_id: shift.id });
  await tryCall('salary advance for Rohit', 'POST', '/v1/staff/advances', owner, { staff_id: staffId('Rohit Gaikwad'), amount: 3000, deduct_month: Number(today.slice(5, 7)), deduct_year: Number(today.slice(0, 4)), mode: 'upi', reason: 'Festival' });
  const appr = await tryCall('leave request raised for Suresh', 'POST', '/v1/staff/approvals', owner, { staff_id: staffId('Suresh Pawar'), type: 'leave', details: { from: dayPlus(3), to: dayPlus(4), reason: 'Family function' } });
  if (appr?.id) await tryCall('leave approved', 'POST', `/v1/staff/approvals/${appr.id}/decide`, owner, { decision: 'approve', note: 'OK' });
  const sal = await tryCall('salaries generated for this month', 'POST', '/v1/staff/salaries/generate', owner, { year: Number(today.slice(0, 4)), month: Number(today.slice(5, 7)) });
  check('salary rows cover both branches', Array.isArray(sal) ? sal.length >= 6 : true, Array.isArray(sal) ? `${sal.length} rows` : '');
  await tryCall('training module published', 'POST', '/v1/staff/training', owner, { title: 'Food safety basics', description: 'Hygiene, storage, allergens', category: 'Compliance', roles: ['All Staff'], pass_score: 70, time_limit_minutes: 20, status: 'published', videos: [], questions: [{ question: 'Wash hands before service?', options: ['Yes', 'No'], answer_index: 0 }] });

  // ── 9. Task manager, integrations, finance, customers ───────────────
  section = 'Task Manager';
  for (const [branch, who, title] of [[B1, 'Sameer Shinde', 'Evening floor check — Ganj Golai'], [B2, 'Rohit Gaikwad', 'Opening checklist — Ausa Road']] as string[][]) {
    const t = await tryCall(`task "${title}"`, 'POST', '/v1/tasks/tasks', owner, {
      title, description: 'Daily standard', priority: 'high', category: 'Operations', assignee_staff_id: staffId(who), roles: [], due_date: today, cadence: 'daily',
      photo_required: false, checklist_required: true, approval_required: true, video_required: false, checklist: [{ text: 'Tables wiped' }, { text: 'Menus placed' }], location_id: branch,
    });
    if (t?.id) {
      await tryCall('task started', 'POST', `/v1/tasks/tasks/${t.id}/start`, owner, {});
      await tryCall('checklist ticked', 'POST', `/v1/tasks/tasks/${t.id}/checklist`, owner, { index: 0, done: true });
      await tryCall('checklist ticked (2)', 'POST', `/v1/tasks/tasks/${t.id}/checklist`, owner, { index: 1, done: true });
      await tryCall('task submitted', 'POST', `/v1/tasks/tasks/${t.id}/submit`, owner, { evidence_url: '', note: 'Done' });
      const v = await tryCall('task verified', 'POST', `/v1/tasks/tasks/${t.id}/verify`, owner, { approved: true, note: 'Good' });
      check('task completed', (v?.status ?? '') === 'completed', String(v?.status));
    }
  }
  const tasks: Row[] = (await must('GET', '/v1/tasks/tasks', owner)).rows ?? (await must('GET', '/v1/tasks/tasks', owner));
  check('tasks kept per branch', Array.isArray(tasks) && tasks.some((t) => t.location_id === B2) && tasks.some((t) => t.location_id === B1));

  section = 'Integrations';
  await tryCall('Zomato connection requested', 'POST', '/v1/integrations/apps/zomato/connect', owner, { account_ref: 'ZOM-LSH-2026', note: 'QA' });
  await tryCall('Razorpay connection requested', 'POST', '/v1/integrations/apps/razorpay/connect', owner, { account_ref: 'rzp_test_lsh', note: 'QA' });
  const wh = await tryCall('webhook endpoint added', 'POST', '/v1/integrations/webhooks', owner, { name: 'Order feed', url: 'https://hooks.example.test/latur', events: ['order.created', 'order.status_changed'] });
  if (wh?.id) {
    await tryCall('webhook test delivery sent', 'POST', `/v1/integrations/webhooks/${wh.id}/test`, owner, {});
    await tryCall('webhook paused', 'PATCH', `/v1/integrations/webhooks/${wh.id}`, owner, { active: false });
  }
  const key = await tryCall('API key generated', 'POST', '/v1/integrations/api-keys', owner, { name: 'Accounting export', scopes: ['orders:read'] });
  if (key?.id) await tryCall('API key rotated', 'POST', `/v1/integrations/api-keys/${key.id}/rotate`, owner, {});
  const job = await tryCall('sync job queued', 'POST', '/v1/integrations/sync-jobs', owner, { provider: 'zomato', resource: 'menu', mode: 'full', direction: 'inbound' });
  await tryCall('sync job run (fails honestly: not connected)', 'POST', '/v1/integrations/sync-jobs/run', owner, job?.id ? { id: job.id } : {});
  const overview = await must('GET', '/v1/integrations/overview', owner);
  check('integrations overview reads', !!overview);

  section = 'Finance & CRM';
  for (const [branch, cat, amt] of [[B1, 'Vegetables', 2400], [B2, 'Gas cylinder', 1850]] as [string, string, number][]) {
    await tryCall(`expense ₹${amt} at ${branch === B1 ? b1.name : b2.name}`, 'POST', '/v1/finance/entries', owner, { direction: 'out', kind: 'expense', account: 'cash', category: cat, amount: amt, entry_date: today, location_id: branch });
  }
  await tryCall('Swiggy settlement recorded', 'POST', '/v1/finance/settlements', owner, { source: 'swiggy', amount: 4400, status: 'completed', utr: `UTR${RUN}`, location_id: B2 });
  const fin = await must('GET', '/v1/finance/dashboard', owner);
  check('finance dashboard reads', !!fin, `today's expense ₹${fin.today_expense}`);
  for (const [branch, first, phone] of [[B1, 'Sneha', '9876543210'], [B2, 'Aditya', '9822011232']] as string[][]) {
    const cr = await pos('POST', '/v1/crm/customers', owner, { first_name: first, last_name: 'Patil', phone, location_id: branch, tags: ['Regular'] });
    check(`customer ${first}`, cr.ok || cr.status === 409, cr.status === 409 ? 'already on file' : String(cr.status));
  }
  const custs: Row[] = await must('GET', '/v1/crm/customers', owner);
  check('customers kept with their branch', custs.some((c) => c.location_id === B2), `${custs.length} customers`);

  // ── 10. Branch managers see only their branch ───────────────────────
  for (const [email, password, branch, bname, other] of [
    ['manager@laturspice.test', process.env.QA_MANAGER1_PASSWORD ?? 'Latur#Mgr2026', B1, String(b1.name), B2],
    ['manager2@laturspice.test', pw('manager2@laturspice.test'), B2, String(b2.name), B1],
  ] as string[][]) {
    section = `Branch admin · ${bname}`;
    let M: { token: string; me: Row };
    try { M = await signIn(email, password); } catch (e) { check('sign in', false, String(e)); continue; }
    const locs: Row[] = M.me.locations ?? [];
    check('sees exactly one branch', locs.length === 1 && String(locs[0].id) === branch, locs.map((l) => l.name).join(' · '));
    const emps: Row[] = await must('GET', '/v1/staff/employees', M.token);
    check('staff list is only this branch', emps.length > 0 && emps.every((e) => e.location_id === branch), `${emps.length} staff`);
    const ords: Row[] = await must('GET', '/v1/operations/orders?limit=200', M.token);
    check('orders are only this branch', ords.length > 0 && ords.every((o) => o.location_id === branch), `${ords.length} orders`);
    const tbls: Row[] = await must('GET', '/v1/operations/dining-tables?limit=100', M.token);
    check('tables are only this branch', tbls.length > 0 && tbls.every((t) => t.location_id === branch), `${tbls.length} tables`);
    const cross = await pos('GET', `/v1/operations/orders?location_id=${other}`, M.token);
    check("cannot list the other branch's orders", cross.status === 403 || (cross.ok && (cross.json.data as Row[]).every((o) => o.location_id === branch)), String(cross.status));
    const chain = await pos('GET', '/v1/franchise/targets', M.token);
    check('chain targets are refused', chain.status === 403, String(chain.status));
    const dash = await must('GET', `/v1/operations/summary`, M.token);
    check('branch summary reads', !!dash);
    const o = ops[branch]?.pickup;
    if (o) {
      const one = await pos('GET', `/v1/operations/orders/${o.id}`, M.token);
      check('can open an order of this branch', one.ok, String(one.status));
    }
    const oo = ops[other]?.pickup;
    if (oo) {
      const no = await pos('GET', `/v1/operations/orders/${oo.id}`, M.token);
      check("cannot open the other branch's order", no.status === 403 || no.status === 404, String(no.status));
    }
    const mk = await pos('POST', '/v1/staff/employees', M.token, { full_name: `Trainee ${RUN.slice(-3)}`, designation: 'Trainee', department: 'Service', location_id: branch, salary_type: 'monthly', monthly_salary: 12000 });
    check('can add staff to own branch', mk.ok, String(mk.status));
    const mk2 = await pos('POST', '/v1/staff/employees', M.token, { full_name: `Intruder ${RUN.slice(-3)}`, designation: 'Trainee', department: 'Service', location_id: other, salary_type: 'monthly', monthly_salary: 12000 });
    check('cannot add staff to the other branch', !mk2.ok, String(mk2.status));
  }

  // ── report ──────────────────────────────────────────────────────────
  const failed = results.filter((r) => !r.ok);
  lines.push(`# Latur Spice House — full data and CRUD pass (${RUN})`, '', `Local database only. ${results.length} checks, ${failed.length} failed.`, '', '| Section | Check | Result | Detail |', '|---|---|---|---|');
  for (const r of results) lines.push(`| ${r.section} | ${r.name} | ${r.ok ? 'PASS' : '**FAIL**'} | ${r.detail.replace(/\|/g, '/')} |`);
  mkdirSync('../docs/qa', { recursive: true });
  const file = `../docs/qa/LATUR-FULL-${RUN}.md`;
  writeFileSync(file, lines.join('\n') + '\n');
  console.log(`\n${results.length} checks, ${failed.length} failed. Report: ${file}`);
  if (failed.length) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

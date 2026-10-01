import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addStaff, call, login, makeWorld, type World } from './helpers.js';

/// Customers & CRM, Marketing, Finance, Integrations, Task Manager and
/// Settings: every write goes to the database and is read back through
/// the API, and each section is fenced by role and by restaurant.
describe('business sections', () => {
  let w: World;
  let admin: string;
  let other: string;
  let delhi: string;

  const api = (method: string, path: string, body?: unknown, token = admin) => call(w, method, path, { token, body });

  async function paidOrder(phone: string, name: string, amount: number, channel = 'dine_in', method = 'cash') {
    const o = await api('POST', '/v1/operations/orders', {
      channel,
      customer_phone: phone,
      customer_name: name,
      gst_pct: 0,
      items: [{ name: 'Paneer Tikka', unit_price: amount, qty: 1 }],
    });
    expect(o.status, JSON.stringify(o.body)).toBe(201);
    const p = await api('POST', `/v1/operations/orders/${o.body.data.id}/payments`, { method, amount: o.body.data.total });
    expect(p.status, JSON.stringify(p.body)).toBeLessThan(300);
    return o.body.data;
  }

  beforeAll(async () => {
    w = await makeWorld();
    admin = await login(w, 'admin@spicybistro.test');
    other = await login(w, 'admin@burgerexpress.test');
    delhi = w.spicy.locationIds[0]!;
  }, 90_000);
  afterAll(() => w.close());

  describe('who may open what', () => {
    it('a branch manager has customers and finance; restaurant-wide sections are the owners', async () => {
      await addStaff(w, w.spicy, 'bm.business@spicybistro.test', 'location_manager');
      const bm = await login(w, 'bm.business@spicybistro.test');
      expect((await api('GET', '/v1/crm/customers', undefined, bm)).status).toBe(200);
      expect((await api('GET', '/v1/finance/dashboard', undefined, bm)).status).toBe(200);
      for (const p of ['/v1/marketing/dashboard', '/v1/settings/overview', '/v1/integrations/overview', '/v1/tasks/tasks']) {
        expect((await api('GET', p, undefined, bm)).status, p).toBe(403);
      }
      await addStaff(w, w.spicy, 'cashier.business@spicybistro.test', 'biller');
      const cashier = await login(w, 'cashier.business@spicybistro.test');
      for (const p of ['/v1/crm/customers', '/v1/finance/dashboard', '/v1/marketing/dashboard']) {
        expect((await api('GET', p, undefined, cashier)).status, p).toBe(403);
      }
    });
  });

  describe('customers & CRM', () => {
    let vaishnavi: string;

    it('adds a customer (phone kept as digits) and refuses the same phone twice', async () => {
      const r = await api('POST', '/v1/crm/customers', {
        first_name: 'Vaishnavi',
        last_name: 'Karkera',
        phone: '+91 85302 30230',
        email: 'vaishnavi@example.com',
        date_of_birth: '1995-02-13',
        preferred_dining: 'dine_in',
        location_id: delhi,
        tags: ['VIP', 'Weekend', 'VIP'],
        allow_whatsapp: true,
        allow_sms: false,
      });
      expect(r.status, JSON.stringify(r.body)).toBe(201);
      vaishnavi = r.body.data.id;
      expect(r.body.data.phone).toBe('8530230230');
      expect(r.body.data.tags).toEqual(['VIP', 'Weekend']);
      const dup = await api('POST', '/v1/crm/customers', { first_name: 'Again', phone: '8530230230' });
      expect(dup.status).toBe(409);
      expect((await api('POST', '/v1/crm/customers', { first_name: 'Short', phone: '12345' })).status).toBe(422);
    });

    it('links paid bills by phone, credits loyalty points once, and reports them', async () => {
      await paidOrder('85302 30230', 'Vaishnavi', 300);
      await paidOrder('8530230230', 'Vaishnavi', 141);
      // Opening the customer straight away already shows the bills' points.
      expect((await api('GET', `/v1/crm/customers/${vaishnavi}`)).body.data.points).toBe(20);
      const list = await api('GET', '/v1/crm/customers?q=vaish');
      expect(list.status).toBe(200);
      const v = list.body.data.find((c: { id: string }) => c.id === vaishnavi);
      expect(v.orders).toBe(2);
      expect(v.spent).toBe(441);
      expect(v.points).toBe(20); // 5 points per ₹100 on 300 and 141 → 15 + 5
      expect(v.tier).toBe('Silver');
      // Reading again does not credit the same bills twice.
      await api('GET', '/v1/crm/loyalty');
      const again = await api('GET', `/v1/crm/customers/${vaishnavi}`);
      expect(again.body.data.points).toBe(20);
      expect(again.body.data.recent_orders).toHaveLength(2);
      expect(again.body.data.loyalty_ledger.every((l: { entry_type: string }) => l.entry_type === 'earn')).toBe(true);

      const dash = await api('GET', '/v1/crm/dashboard');
      expect(dash.body.data.total_customers).toBe(1);
      expect(dash.body.data.lifetime_revenue).toBe(441);
      expect(dash.body.data.repeat_customers).toBe(1);
      expect(dash.body.data.top_customers[0].name).toBe('Vaishnavi Karkera');
      expect(dash.body.data.channel_mix[0].channel).toBe('dine_in');
    });

    it('edits and imports customers, skipping bad rows', async () => {
      const p = await api('PATCH', `/v1/crm/customers/${vaishnavi}`, { notes: 'Likes window seat', tags: ['VIP'] });
      expect(p.status).toBe(200);
      expect(p.body.data.notes).toBe('Likes window seat');
      const imp = await api('POST', '/v1/crm/customers/import', {
        customers: [
          { first_name: 'Garu', last_name: 'Reddy', phone: '8175294023', email: 'garu@example.com' },
          { first_name: 'Dup', phone: '8530230230' },
          { first_name: '', phone: '9000000001' },
        ],
      });
      expect(imp.status).toBe(200);
      expect(imp.body.data.added).toBe(1);
      expect(imp.body.data.skipped.map((s: { row: number }) => s.row)).toEqual([2, 3]);
    });

    it('segments: system counts, a custom segment and its members', async () => {
      const s = await api('GET', '/v1/crm/segments');
      const count = (k: string) => s.body.data.system.find((x: { key: string }) => x.key === k).count;
      expect(count('dine_in_only')).toBe(1);
      expect(count('new')).toBe(2);
      expect(count('birthday')).toBe(new Date().getMonth() === 1 ? 1 : 0);
      const seg = await api('POST', '/v1/crm/segments', { name: 'VIP regulars', rules: { tags: ['vip'], min_orders: 2 } });
      expect(seg.status).toBe(201);
      const members = await api('GET', `/v1/crm/segments/${seg.body.data.id}/customers`);
      expect(members.body.data.map((m: { first_name: string }) => m.first_name)).toEqual(['Vaishnavi']);
      expect((await api('DELETE', `/v1/crm/segments/${seg.body.data.id}`)).status).toBe(204);
    });

    it('loyalty rules and a manual redemption; points never go negative', async () => {
      const put = await api('PUT', '/v1/crm/loyalty', { min_redeem_points: 10, tiers: [{ name: 'Silver', min_spend: 0 }, { name: 'Gold', min_spend: 400 }] });
      expect(put.status).toBe(200);
      expect((await api('GET', `/v1/crm/customers/${vaishnavi}`)).body.data.tier).toBe('Gold');
      expect((await api('POST', '/v1/crm/loyalty/entries', { customer_id: vaishnavi, entry_type: 'redeem', points: 50 })).status).toBe(422);
      const ok = await api('POST', '/v1/crm/loyalty/entries', { customer_id: vaishnavi, entry_type: 'redeem', points: 15, note: 'Dessert' });
      expect(ok.status).toBe(201);
      expect(ok.body.data.balance_after).toBe(5);
      const l = await api('GET', '/v1/crm/loyalty');
      expect(l.body.data.points_redeemed).toBe(15);
      expect(l.body.data.points_outstanding).toBe(5);
    });

    it('wallet: top-up and redeem, never below zero', async () => {
      expect((await api('POST', '/v1/crm/wallet/entries', { customer_id: vaishnavi, entry_type: 'topup', amount: 500, method: 'upi' })).status).toBe(201);
      expect((await api('POST', '/v1/crm/wallet/entries', { customer_id: vaishnavi, entry_type: 'redeem', amount: 600 })).status).toBe(422);
      const r = await api('POST', '/v1/crm/wallet/entries', { customer_id: vaishnavi, entry_type: 'redeem', amount: 120.5 });
      expect(Number(r.body.data.balance_after)).toBe(379.5);
      const wal = await api('GET', '/v1/crm/wallet');
      expect(wal.body.data).toMatchObject({ float: 379.5, active_wallets: 1, topups_30d: 500, redemptions_30d: 120.5 });
      expect((await api('GET', '/v1/crm/wallet/ledger')).body.data).toHaveLength(2);
    });

    it('feedback CRUD and ideas from real sales', async () => {
      const f = await api('POST', '/v1/crm/feedback', { customer_id: vaishnavi, customer_name: 'Vaishnavi', rating: 4, comment: 'Great tikka' });
      expect(f.status, JSON.stringify(f.body)).toBe(201);
      expect((await api('POST', '/v1/crm/feedback', { rating: 7 })).status).toBe(422);
      expect((await api('PATCH', `/v1/crm/feedback/${f.body.data.id}`, { status: 'resolved', response: 'Thank you!' })).body.data.status).toBe('resolved');
      const ideas = await api('GET', '/v1/crm/ideas');
      expect(ideas.body.data.top_items[0]).toMatchObject({ name: 'Paneer Tikka', qty: 2 });
    });

    it('another restaurant sees none of it', async () => {
      expect((await api('GET', `/v1/crm/customers/${vaishnavi}`, undefined, other)).status).toBe(404);
      expect((await api('GET', '/v1/crm/customers', undefined, other)).body.data).toEqual([]);
    });
  });

  describe('marketing', () => {
    it('a campaign is saved, then queued with its audience — and says nothing was sent', async () => {
      const aud = await api('GET', '/v1/marketing/audience?segment=all&channel=whatsapp');
      expect(aud.body.data).toEqual({ total: 2, reachable: 2 });
      const draft = await api('POST', '/v1/marketing/campaigns', {
        name: 'We miss you',
        channel: 'sms',
        segment: 'all',
        message: 'Hi {name}, 20% off with MISSYOU20',
        action: 'draft',
      });
      expect(draft.status, JSON.stringify(draft.body)).toBe(201);
      expect(draft.body.data.status).toBe('draft');
      const sent = await api('POST', `/v1/marketing/campaigns/${draft.body.data.id}/send`);
      expect(sent.body.data.status).toBe('queued');
      expect(sent.body.data.audience_count).toBe(1); // Vaishnavi opted out of SMS
      expect(sent.body.data.status_note).toMatch(/Not sent: SMS Gateway is not connected/);
      // Lists name the segment, never its key or id.
      const list = await api('GET', '/v1/marketing/campaigns');
      expect(list.body.data.find((c: { name: string }) => c.name === 'We miss you').segment_name).toBe('All customers');
      expect((await api('PATCH', `/v1/marketing/campaigns/${draft.body.data.id}`, { name: 'x' })).status).toBe(409);
      const bad = await api('POST', '/v1/marketing/campaigns', { name: 'Later', channel: 'push', message: 'x', action: 'schedule' });
      expect(bad.status).toBe(422);
    });

    it('a promotion is an offer in Master → Offers too', async () => {
      const r = await api('POST', '/v1/marketing/promotions', {
        title: 'Monsoon Feast Special',
        offer_type: 'promo_code',
        code: 'monsoon50',
        discount_type: 'percent',
        discount_value: 50,
        max_discount: 150,
        min_order: 350,
        channels: ['pos', 'qr', 'app'],
      });
      expect(r.status, JSON.stringify(r.body)).toBe(201);
      expect(r.body.data).toMatchObject({ code: 'MONSOON50', discount_rule: '50% OFF (Upto ₹150)', state: 'active', status: 'Active' });
      const promos = await api('GET', '/v1/marketing/promotions');
      expect(promos.body.data.find((p: { code: string }) => p.code === 'MONSOON50').target_segment_name).toBe('All customers');
      const master = await api('GET', '/v1/master/offers');
      expect(master.body.data.map((o: { code: string }) => o.code)).toContain('MONSOON50');
      expect((await api('POST', '/v1/marketing/promotions', { title: 'Copy', offer_type: 'promo_code', code: 'MONSOON50', discount_type: 'flat', discount_value: 10, channels: ['pos'] })).status).toBe(409);
      const later = await api('POST', '/v1/marketing/promotions', {
        title: 'Diwali',
        offer_type: 'auto_apply',
        discount_type: 'flat',
        discount_value: 100,
        channels: ['pos'],
        start_date: new Date(Date.now() + 5 * 86_400_000).toISOString(),
      });
      expect(later.body.data.state).toBe('scheduled');
      expect((await api('GET', '/v1/marketing/promotions?state=active')).body.data).toHaveLength(1);
      expect((await api('DELETE', `/v1/marketing/promotions/${later.body.data.id}`)).status).toBe(204);
      expect((await api('GET', '/v1/master/offers')).body.data.map((o: { title: string }) => o.title)).not.toContain('Diwali');
      const dash = await api('GET', '/v1/marketing/dashboard');
      expect(dash.body.data).toMatchObject({ live_coupons: 1, campaigns: 1, queued_campaigns: 1 });
    });

    it('ad requests wait for review and can be withdrawn while pending', async () => {
      const ad = await api('POST', '/v1/marketing/ads', { title: 'Weekend brunch push', discount_text: '20% OFF', placement: 'home_carousel' });
      expect(ad.body.data.status).toBe('pending');
      expect((await api('GET', '/v1/marketing/ads')).body.data).toHaveLength(1);
      expect((await api('DELETE', `/v1/marketing/ads/${ad.body.data.id}`)).status).toBe(204);
      expect((await api('GET', '/v1/marketing/ads')).body.data).toHaveLength(0);
    });
  });

  describe('finance', () => {
    it('entries, approvals and balances add up with POS collections', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const e = await api('POST', '/v1/finance/entries', { direction: 'out', kind: 'expense', account: 'cash', category: 'Packaging', amount: 150, entry_date: today });
      expect(e.status, JSON.stringify(e.body)).toBe(201);
      const topup = await api('POST', '/v1/finance/entries', { direction: 'in', kind: 'top_up', account: 'bank', amount: 1000, status: 'pending', party: 'Owner' });
      expect((await api('POST', '/v1/finance/entries', { direction: 'in', kind: 'expense', amount: 10 })).status).toBe(422);
      let d = await api('GET', '/v1/finance/dashboard');
      expect(d.body.data.pending_top_ups).toBe(1000);
      expect((await api('POST', `/v1/finance/entries/${topup.body.data.id}/approve`)).status).toBe(200);
      expect((await api('POST', `/v1/finance/entries/${topup.body.data.id}/approve`)).status).toBe(409);
      d = await api('GET', '/v1/finance/dashboard');
      // Cash: two cash bills (300 + 141) minus the 150 expense.
      expect(d.body.data.cash_in_hand).toBe(291);
      expect(d.body.data.bank_balance).toBe(1000);
      expect(d.body.data.today_expense).toBe(150);
      expect(d.body.data.today_sales).toBe(441);
      expect(d.body.data.money_in).toBe(1441);
      expect(d.body.data.money_out).toBe(150);
      expect(d.body.data.expense_breakdown).toEqual([{ category: 'Packaging', amount: 150 }]);
      const exp = await api('GET', '/v1/finance/expenses/summary');
      expect(exp.body.data.total).toBe(150);
    });

    it('payments list POS bills with their status; a UPI bill waits for verification', async () => {
      const o = await api('POST', '/v1/operations/orders', { channel: 'pickup', gst_pct: 0, items: [{ name: 'Chai', unit_price: 30, qty: 2 }] });
      await api('POST', `/v1/operations/orders/${o.body.data.id}/payments`, { method: 'upi', amount: 60 });
      const r = await api('GET', '/v1/finance/payments');
      expect(r.status).toBe(200);
      expect(r.body.summary).toMatchObject({ gross: 441, pos: 441, cash: 441, pending: 60 });
      expect(r.body.data.find((p: { method: string }) => p.method === 'upi').status).toBe('pending_verification');
      // An online order shows a readable number and the customer's name.
      await w.db.query(
        `insert into ol_orders (organization_id, status, subtotal, total, delivery_address, payment_status)
         values ($1, 'placed', 400, 420, '{"name":"Priya Nair"}', 'paid')`,
        [w.spicy.organizationId],
      );
      const online = (await api('GET', '/v1/finance/payments?source=online')).body.data;
      expect(online).toHaveLength(1);
      expect(online[0].reference).toMatch(/^OL-[0-9A-F]{8}$/);
      expect(online[0].customer_name).toBe('Priya Nair');
    });

    it('settlements get a number and a summary; documents track expiry', async () => {
      const s = await api('POST', '/v1/finance/settlements', { source: 'zomato', amount: 12800, status: 'completed', utr: 'UTR9283746501' });
      expect(s.status, JSON.stringify(s.body)).toBe(201);
      expect(s.body.data.settlement_no).toMatch(/^STL-\d{8}-001$/);
      expect(s.body.data.settled_at).toBeTruthy();
      await api('POST', '/v1/finance/settlements', { source: 'swiggy', amount: 8450, expected_on: '2030-01-01' });
      const sum = await api('GET', '/v1/finance/settlements-summary');
      expect(sum.body.data).toMatchObject({ total_settled: 12800, pending_amount: 8450, counts: { all: 2, completed: 1, pending: 1, failed: 0 } });
      expect(sum.body.data.next.amount).toBe(8450);
      const soon = new Date(Date.now() + 20 * 86_400_000).toISOString().slice(0, 10);
      await api('POST', '/v1/finance/documents', { name: 'FSSAI Food License', doc_type: 'food_safety', doc_no: '11521999000285', expiry_date: '2030-12-31' });
      await api('POST', '/v1/finance/documents', { name: 'Fire Safety Certificate', doc_type: 'safety', expiry_date: soon });
      await api('POST', '/v1/finance/documents', { name: 'Liquor License', doc_type: 'liquor', expiry_date: '2025-03-31' });
      expect((await api('POST', '/v1/finance/documents', { name: 'Bad', issue_date: '2026-01-02', expiry_date: '2026-01-01' })).status).toBe(422);
      const docs = await api('GET', '/v1/finance/documents-summary');
      expect(docs.body.data).toMatchObject({ total: 3, active: 1, expiring_soon: 1, expired: 1 });
      // The completed Zomato settlement lands in the bank balance.
      expect((await api('GET', '/v1/finance/dashboard')).body.data.bank_balance).toBe(13800);
    });
  });

  describe('integrations', () => {
    it('a connection request stays pending; its sync jobs fail with the reason', async () => {
      const apps = await api('GET', '/v1/integrations/apps?category=payments');
      expect(apps.body.data.map((a: { key: string }) => a.key)).toContain('phonepe_business');
      const r = await api('POST', '/v1/integrations/apps/tally_prime/connect', { account_ref: 'TALLY-001' });
      expect(r.status).toBe(200);
      expect(r.body.data.status).toBe('pending');
      await api('POST', '/v1/integrations/sync-jobs', { provider: 'tally_prime', resource: 'menu', mode: 'delta' });
      const run = await api('POST', '/v1/integrations/sync-jobs/run');
      expect(run.body.data).toEqual({ ran: 1, succeeded: 0, failed: 1 });
      const jobs = await api('GET', '/v1/integrations/sync-jobs');
      expect(jobs.body.data[0]).toMatchObject({ status: 'failed', attempts: 1, error: 'Tally Prime is not connected.' });
      const ov = await api('GET', '/v1/integrations/overview');
      expect(ov.body.data).toMatchObject({ pending: 1, connected: 0, sync_success_rate: 0, sync_failed: 1 });
      expect(ov.body.data.attention[0].source).toBe('Tally Prime');
    });

    it('API keys: shown once, stored only as a hash, rotated and revoked', async () => {
      const k = await api('POST', '/v1/integrations/api-keys', { name: 'Accounting export', scopes: ['payments:read', 'reports:read'] });
      expect(k.status).toBe(201);
      const key = k.body.data.key as string;
      expect(key).toMatch(/^pv_live_/);
      const stored = await w.pg.query<{ key_hash: string; prefix: string }>('select key_hash, prefix from pos_api_keys where id = $1', [k.body.data.id]);
      expect(stored.rows[0]!.key_hash).not.toContain(key);
      expect(key.startsWith(stored.rows[0]!.prefix)).toBe(true);
      const list = await api('GET', '/v1/integrations/api-keys');
      expect(JSON.stringify(list.body)).not.toContain(key);
      const rot = await api('POST', `/v1/integrations/api-keys/${k.body.data.id}/rotate`);
      expect(rot.body.data.key).not.toBe(key);
      const after = await api('GET', '/v1/integrations/api-keys');
      expect(after.body.data.map((x: { status: string }) => x.status).sort()).toEqual(['active', 'revoked']);
      expect(after.body.audit.map((a: { action: string }) => a.action)).toEqual(['Rotated key', 'Generated key']);
      expect((await api('POST', `/v1/integrations/api-keys/${rot.body.data.id}/revoke`)).status).toBe(200);
    });

    it('webhooks only go to public https hosts; a failed test delivery is logged', async () => {
      for (const url of ['http://example.com/hook', 'https://localhost/hook', 'https://192.168.1.4/hook', 'https://10.0.0.1/x']) {
        expect((await api('POST', '/v1/integrations/webhooks', { name: 'x', url, events: ['order.created'] })).status, url).toBe(422);
      }
      const h = await api('POST', '/v1/integrations/webhooks', { name: 'Order events', url: 'https://hooks.invalid/kds', events: ['order.created', 'order.status_changed'] });
      expect(h.status).toBe(201);
      expect(h.body.data.signing_secret).toMatch(/^whsec_/);
      expect((await api('GET', '/v1/integrations/webhooks')).body.data[0].signing_secret).toBeUndefined();
      const t = await api('POST', `/v1/integrations/webhooks/${h.body.data.id}/test`);
      expect(t.body.data.status).toBe('failed');
      const logs = await api('GET', '/v1/integrations/logs');
      expect(logs.body.total).toBe(2);
      expect(logs.body.data.map((l: { kind: string }) => l.kind).sort()).toEqual(['sync', 'webhook']);
      expect((await api('DELETE', `/v1/integrations/webhooks/${h.body.data.id}`)).status).toBe(204);
    });
  });

  describe('task manager', () => {
    let staffId: string;
    let second: string;

    beforeAll(async () => {
      const a = await api('POST', '/v1/staff/employees', { full_name: 'Raju Patil', designation: 'Captain', location_id: delhi });
      const b = await api('POST', '/v1/staff/employees', { full_name: 'Suresh Kumar', designation: 'Kitchen Staff', location_id: delhi });
      staffId = a.body.data.id;
      second = b.body.data.id;
    });

    it('assign → start → checklist → submit → fail → reassign → approve, with a timeline', async () => {
      expect((await api('POST', '/v1/tasks/tasks', { title: 'No one' })).status).toBe(422);
      const t = await api('POST', '/v1/tasks/tasks', {
        title: 'Fire Extinguisher Monthly Check',
        priority: 'high',
        category: 'Safety & Compliance',
        assignee_staff_id: staffId,
        due_date: '2030-01-25',
        cadence: 'monthly',
        photo_required: true,
        checklist_required: true,
        approval_required: true,
        checklist: [{ text: 'Check expiry tag' }, { text: 'Verify pressure gauge' }],
      });
      expect(t.status, JSON.stringify(t.body)).toBe(201);
      const id = t.body.data.id;
      expect(t.body.data).toMatchObject({ status: 'assigned', assignee_name: 'Raju Patil', assignee_role: 'Captain' });
      expect((await api('POST', `/v1/tasks/tasks/${id}/start`)).body.data.status).toBe('in_progress');
      await api('POST', `/v1/tasks/tasks/${id}/checklist`, { index: 0, done: true });
      expect((await api('POST', `/v1/tasks/tasks/${id}/submit`, { evidence_url: 'https://example.com/p.jpg' })).status).toBe(422);
      await api('POST', `/v1/tasks/tasks/${id}/checklist`, { index: 1, done: true });
      expect((await api('POST', `/v1/tasks/tasks/${id}/submit`, {})).status).toBe(422);
      const sub = await api('POST', `/v1/tasks/tasks/${id}/submit`, { evidence_url: 'https://example.com/p.jpg' });
      expect(sub.body.data.status).toBe('submitted');
      expect((await api('POST', `/v1/tasks/tasks/${id}/verify`, { approved: false })).status).toBe(422);
      const failed = await api('POST', `/v1/tasks/tasks/${id}/verify`, { approved: false, failure_reason: 'Photo was blurry' });
      expect(failed.body.data.status).toBe('failed');
      const re = await api('POST', `/v1/tasks/tasks/${id}/reassign`, { assignee_staff_id: second, note: 'Re-examine the kitchen unit' });
      expect(re.body.data).toMatchObject({ status: 'reassigned', assignee_name: 'Suresh Kumar' });
      expect(re.body.data.checklist.every((i: { done: boolean }) => !i.done)).toBe(true);
      await api('POST', `/v1/tasks/tasks/${id}/checklist`, { index: 0, done: true });
      await api('POST', `/v1/tasks/tasks/${id}/checklist`, { index: 1, done: true });
      await api('POST', `/v1/tasks/tasks/${id}/submit`, { evidence_url: 'https://example.com/p2.jpg' });
      const ok = await api('POST', `/v1/tasks/tasks/${id}/verify`, { approved: true, note: 'Clear photo now' });
      expect(ok.body.data.status).toBe('completed');
      const detail = await api('GET', `/v1/tasks/tasks/${id}`);
      expect(detail.body.data.events.map((e: { event: string }) => e.event)).toEqual([
        'Task created',
        'Task assigned',
        'Task started',
        'Task executed',
        'Evidence uploaded',
        'Submitted for sign-off',
        'Verification failed',
        'Corrective action initiated',
        'Task reassigned',
        'Task started',
        'Task executed',
        'Evidence uploaded',
        'Submitted for sign-off',
        'Verification approved',
        'Task completed',
      ]);
      expect((await api('PATCH', `/v1/tasks/tasks/${id}`, { title: 'x' })).status).toBe(409);
    });

    it('lists by tab with a summary; drafts need no assignee; overdue counts as failed', async () => {
      const d = await api('POST', '/v1/tasks/tasks', { title: 'Inventory audit', draft: true });
      expect(d.body.data.status).toBe('draft');
      await api('POST', '/v1/tasks/tasks', { title: 'Sanitize tables', assignee_staff_id: staffId, due_date: '2020-01-01' });
      const all = await api('GET', '/v1/tasks/tasks');
      expect(all.body.summary).toMatchObject({ completed: 1, failed_or_overdue: 1 });
      expect((await api('GET', '/v1/tasks/tasks?tab=failed')).body.data.map((t: { title: string }) => t.title)).toEqual(['Sanitize tables']);
      expect((await api('GET', '/v1/tasks/assignees')).body.data.map((s: { full_name: string }) => s.full_name)).toEqual(['Raju Patil', 'Suresh Kumar']);
      expect((await api('DELETE', `/v1/tasks/tasks/${d.body.data.id}`)).status).toBe(204);
    });
  });

  describe('settings', () => {
    it('outlet profile renames the restaurant; bill format reaches the POS bill settings', async () => {
      const o = await api('PUT', '/v1/settings/outlet', {
        name: 'Spicy Bistro Latur',
        phone: '+91 90123 45678',
        cuisine: 'North Indian',
        email: 'hello@spicybistro.test',
        address: 'Gandhi Road, Latur 413512',
        business_category: 'Casual Dining',
      });
      expect(o.status, JSON.stringify(o.body)).toBe(200);
      const me = await call(w, 'GET', '/v1/auth/me', { token: admin });
      expect(me.body.data.organization.name).toBe('Spicy Bistro Latur');
      expect((await api('PUT', '/v1/settings/bill-format', { store_name: 'X', address: 'Y', phone: '1', gstin: 'BAD' })).status).toBe(400);
      const b = await api('PUT', '/v1/settings/bill-format', {
        store_name: 'Spicy Bistro',
        branch_label: 'Main Branch',
        address: 'Gandhi Road, Latur',
        phone: '+91 90123 45678',
        gstin: '27AAAAA0000A1Z5',
        bill_prefix: 'BIL-',
        show_cashier: false,
      });
      expect(b.status, JSON.stringify(b.body)).toBe(200);
      const pos = await api('GET', '/v1/operations/bill-settings');
      expect(pos.body.data).toMatchObject({ legal_name: 'Spicy Bistro', gstin: '27AAAAA0000A1Z5', phone: '+91 90123 45678' });
      expect((await api('GET', '/v1/settings/bill-format')).body.data).toMatchObject({ branch_label: 'Main Branch', show_cashier: false, paper_size: '80mm' });
    });

    it('devices and printers CRUD; a test print says plainly it cannot print', async () => {
      const d = await api('POST', '/v1/settings/devices', { name: 'KDS Tandoor', device_type: 'kds', station: 'Main - tandoor', ip: '192.168.1.32' });
      expect(d.status, JSON.stringify(d.body)).toBe(201);
      const p = await api('POST', '/v1/settings/printers', { name: 'Niks Billing', printer_type: 'receipt', station: 'Counter', address: '192.168.1.14:9100' });
      expect(p.status).toBe(201);
      expect((await api('POST', '/v1/settings/printers', { name: 'Odd', paper_mm: 70 })).status).toBe(422);
      const test = await api('POST', `/v1/settings/printers/${p.body.data.id}/test`);
      expect(test.status).toBe(409);
      expect(test.body.error.message).toMatch(/Nothing was printed/);
      expect((await api('PATCH', `/v1/settings/devices/${d.body.data.id}`, { active: false })).body.data.active).toBe(false);
      expect((await api('GET', '/v1/settings/printers')).body.data).toHaveLength(1);
    });

    it('KDS, update and notification preferences are saved', async () => {
      expect((await api('GET', '/v1/settings/kds')).body.data.saved).toBe(false);
      expect((await api('PUT', '/v1/settings/kds', { enabled: true, server_ip: '999.1.1.1' })).status).toBe(400);
      expect((await api('PUT', '/v1/settings/kds', { enabled: true, server_ip: '192.168.1.1', subnet: '192.168.1.0/24' })).status).toBe(200);
      expect((await api('GET', '/v1/settings/kds')).body.data).toMatchObject({ enabled: true, server_ip: '192.168.1.1', port: 8787, saved: true });
      expect((await api('PUT', '/v1/settings/updates', { channel: 'beta' })).status).toBe(200);
      expect((await api('PUT', '/v1/settings/notifications', { daily_summary: true, recipients: ['owner@spicybistro.test'] })).status).toBe(200);
      expect((await api('GET', '/v1/settings/notifications')).body.data.recipients).toEqual(['owner@spicybistro.test']);
      expect((await api('GET', '/v1/settings/version')).body.data.server).toMatch(/\d/);
    });

    it('a plan request waits for the Proviyaa team; the overview reflects the setup', async () => {
      const sub = await api('GET', '/v1/settings/subscription');
      expect(sub.body.data.current).toBeNull();
      expect(sub.body.data.plans).toHaveLength(8);
      const r = await api('POST', '/v1/settings/subscription/requests', { plan_key: 'premium_3' });
      expect(r.status).toBe(201);
      expect(r.body.message).toMatch(/no payment was taken/);
      expect((await api('POST', '/v1/settings/subscription/requests', { plan_key: 'standard_1' })).status).toBe(409);
      const ov = await api('GET', '/v1/settings/overview');
      const done = Object.fromEntries(ov.body.data.checklist.map((i: { key: string; done: boolean }) => [i.key, i.done]));
      expect(done).toMatchObject({ outlet: true, bill: true, printers: true, devices: true, notifications: true, tables: false });
      expect(ov.body.data.alerts.map((a: { title: string }) => a.title).join(' ')).toMatch(/document\(s\) expired/);
      const ops = await api('GET', '/v1/settings/operations-centre');
      expect(ops.body.data.printers).toMatchObject({ total: 1, active: 1 });
      expect(ops.body.data.incidents.length).toBeGreaterThan(0);
    });
  });
});

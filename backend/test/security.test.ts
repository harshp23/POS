import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { SignJWT } from 'jose';
import { createApp } from '../src/app.js';
import { addStaff, call, JWT_SECRET, login, makeWorld, PASSWORD, type World } from './helpers.js';

/// Sessions (sign-out, password change, admin reset, lifetime, rate limit),
/// branch isolation for branch-bound roles, who may take orders / payments,
/// and that nobody manages someone above them.
describe('security', () => {
  let w: World;
  let admin: string;
  let delhi: string;
  let noida: string;

  beforeAll(async () => {
    w = await makeWorld();
    admin = await login(w, 'admin@spicybistro.test');
    [delhi, noida] = w.spicy.locationIds as [string, string];
  }, 60_000);
  afterAll(() => w.close());

  describe('sessions', () => {
    it('signing out revokes that token only', async () => {
      await addStaff(w, w.spicy, 'twodevices@spicybistro.test', 'location_manager');
      const a = await login(w, 'twodevices@spicybistro.test');
      await new Promise((r) => setTimeout(r, 5));
      const b = await login(w, 'twodevices@spicybistro.test');
      expect((await call(w, 'POST', '/v1/auth/logout', { token: a })).status).toBe(204);
      expect((await call(w, 'GET', '/v1/auth/me', { token: a })).status).toBe(401);
      expect((await call(w, 'POST', '/v1/auth/refresh', { body: { refresh_token: a } })).status).toBe(401);
      expect((await call(w, 'GET', '/v1/auth/me', { token: b })).status).toBe(200);
    });

    it('changing the password signs out every other session and returns a new one', async () => {
      await addStaff(w, w.spicy, 'changer@spicybistro.test', 'location_manager');
      const phone = await login(w, 'changer@spicybistro.test');
      const till = await login(w, 'changer@spicybistro.test');
      const r = await call(w, 'POST', '/v1/auth/change-password', { token: till, body: { current_password: PASSWORD, new_password: 'Brand-New-Pass-1' } });
      expect(r.status).toBe(200);
      expect((await call(w, 'GET', '/v1/auth/me', { token: phone })).status).toBe(401);
      expect((await call(w, 'GET', '/v1/auth/me', { token: till })).status).toBe(401);
      expect((await call(w, 'GET', '/v1/auth/me', { token: r.body.data.session.access_token })).status).toBe(200);
      // A wrong current password is refused.
      const bad = await call(w, 'POST', '/v1/auth/change-password', { token: r.body.data.session.access_token, body: { current_password: 'nope', new_password: 'Another-Pass-2' } });
      expect(bad.status).toBe(400);
    });

    it('an admin password reset signs the person out everywhere', async () => {
      const seeded = await call(w, 'POST', '/v1/staff/roles/seed', { token: admin });
      const biller = seeded.body.data.find((r: { name: string }) => r.name === 'Cashier');
      const created = await call(w, 'POST', '/v1/staff/logins', {
        token: admin,
        body: { email: 'resetme@spicybistro.test', password: 'Reset-Me-2026', role_id: biller.id, first_name: 'Re', last_name: 'Set' },
      });
      expect(created.status).toBe(201);
      const staffToken = await login(w, 'resetme@spicybistro.test', 'Reset-Me-2026');
      await new Promise((r) => setTimeout(r, 5));
      expect((await call(w, 'POST', `/v1/staff/logins/${created.body.data.user_id}/reset-password`, { token: admin, body: { password: 'Temp-Pass-2026' } })).status).toBe(204);
      expect((await call(w, 'GET', '/v1/auth/me', { token: staffToken })).status).toBe(401);
      expect((await login(w, 'resetme@spicybistro.test', 'Temp-Pass-2026')).length).toBeGreaterThan(20);
    });

    it('a sign-in older than 30 days cannot be refreshed', async () => {
      const [u] = await w.db.query<{ id: string }>(`select id from users where email = 'admin@spicybistro.test'`);
      const old = Math.floor(Date.now() / 1000) - 31 * 86_400;
      const token = await new SignJWT({ userId: u!.id, email: 'admin@spicybistro.test', iat_ms: Date.now(), auth_time: old })
        .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
        .setIssuedAt()
        .setExpirationTime('1h')
        .sign(new TextEncoder().encode(JWT_SECRET));
      expect((await call(w, 'GET', '/v1/auth/me', { token })).status).toBe(200);
      expect((await call(w, 'POST', '/v1/auth/refresh', { body: { refresh_token: token } })).status).toBe(401);
    });

    it('rate-limits sign-in attempts', async () => {
      const app = createApp(w.platform, { auth: { loginLimitPerEmail: 3, loginLimitPerIp: 100 } });
      const attempt = () =>
        app.request('/v1/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: 'nobody@spicybistro.test', password: 'x' }),
        });
      for (let i = 0; i < 3; i++) expect((await attempt()).status).toBe(401);
      const limited = await attempt();
      expect(limited.status).toBe(429);
      expect(limited.headers.get('retry-after')).toBeTruthy();
    });
  });

  describe('branch isolation', () => {
    let delhiCashier: string;
    let noidaOrder: string;

    beforeAll(async () => {
      const r = await call(w, 'POST', '/v1/operations/orders', { token: admin, location: noida, body: { items: [{ name: 'Noida Thali', qty: 1, unit_price: 200 }] } });
      noidaOrder = r.body.data.id;
      const id = await (await import('../src/db/local-database.js')).addAccount(w.db, w.spicy.organizationId, {
        email: 'delhi-cashier@spicybistro.test',
        password: PASSWORD,
        posRole: 'biller',
        locationId: delhi,
      });
      expect(id).toBeTruthy();
      delhiCashier = await login(w, 'delhi-cashier@spicybistro.test');
    });

    it('a branch cashier sees only their branch', async () => {
      const me = await call(w, 'GET', '/v1/auth/me', { token: delhiCashier });
      expect(me.body.data.locations.map((l: { id: string }) => l.id)).toEqual([delhi]);
      expect((await call(w, 'GET', '/v1/operations/orders', { token: delhiCashier, location: noida })).status).toBe(403);
      expect((await call(w, 'GET', `/v1/operations/orders?location_id=${noida}`, { token: delhiCashier })).status).toBe(403);
      const own = await call(w, 'GET', '/v1/operations/orders', { token: delhiCashier });
      expect(own.status).toBe(200);
      expect(own.body.data.every((o: { location_id: string | null }) => o.location_id === delhi || o.location_id === null)).toBe(true);
    });

    it("cannot open, pay or change another branch's order by id", async () => {
      expect((await call(w, 'GET', `/v1/operations/orders/${noidaOrder}`, { token: delhiCashier })).status).toBe(403);
      expect((await call(w, 'POST', `/v1/operations/orders/${noidaOrder}/payments`, { token: delhiCashier, body: { method: 'cash', amount: 1 } })).status).toBe(403);
      expect((await call(w, 'POST', `/v1/operations/orders/${noidaOrder}/status`, { token: delhiCashier, body: { status: 'cancelled' } })).status).toBe(403);
    });

    it("cannot take over another branch's order through sync", async () => {
      const push = await call(w, 'POST', '/v1/sync/push', {
        token: delhiCashier,
        body: {
          changes: [
            {
              change_id: 'takeover-1',
              resource: 'orders',
              op: 'upsert',
              row: {
                client_order_id: noidaOrder, location_id: 'x', currency_code: 'INR', status: 'pendingUpload',
                order_type: 'dineIn', table_label: null, created_at: new Date().toISOString(), ops_status: 'open', channel: 'dineIn',
                source: 'POS', guests: 1, server_name: '', notes: 'hijack', discount_pct: 0, tax_pct: 5, bill_no: null,
                payment_method: null, settled_at: null, customer_name: '',
              },
            },
          ],
        },
      });
      expect(push.status).toBe(200);
      const result = push.body.data.results[0];
      expect(result.status).toBe('rejected');
      expect(result.error.code).toBe('forbidden');
      const [o] = await w.db.query<{ location_id: string }>(`select location_id from orders where id = $1`, [noidaOrder]);
      expect(o!.location_id).toBe(noida);
    });

    it('chain views are for organization-level roles', async () => {
      await (await import('../src/db/local-database.js')).addAccount(w.db, w.spicy.organizationId, {
        email: 'branch-manager@spicybistro.test',
        password: PASSWORD,
        posRole: 'location_manager',
        locationId: delhi,
      });
      const bm = await login(w, 'branch-manager@spicybistro.test');
      expect((await call(w, 'GET', '/v1/franchise/overview', { token: bm })).status).toBe(403);
      expect((await call(w, 'GET', '/v1/operations/orders', { token: bm })).status).toBe(200);
      expect((await call(w, 'GET', '/v1/franchise/overview', { token: admin })).status).toBe(200);
    });
  });

  describe('who may take orders and money', () => {
    it('the kitchen cannot place orders; captains and waiters cannot take payments', async () => {
      await addStaff(w, w.spicy, 'chef@spicybistro.test', 'kitchen');
      await addStaff(w, w.spicy, 'captain@spicybistro.test', 'captain');
      const chef = await login(w, 'chef@spicybistro.test');
      const captain = await login(w, 'captain@spicybistro.test');
      const body = { items: [{ name: 'Tea', qty: 1, unit_price: 20 }] };
      expect((await call(w, 'POST', '/v1/operations/orders', { token: chef, body })).status).toBe(403);
      const order = await call(w, 'POST', '/v1/operations/orders', { token: captain, body });
      expect(order.status).toBe(201);
      expect((await call(w, 'POST', `/v1/operations/orders/${order.body.data.id}/payments`, { token: captain, body: { method: 'cash', amount: 21 } })).status).toBe(403);
      expect((await call(w, 'POST', `/v1/operations/orders/${order.body.data.id}/payments`, { token: admin, body: { method: 'cash', amount: 21 } })).status).toBe(201);
    });

    it('the cashier records UPI; only a manager verifies it', async () => {
      await addStaff(w, w.spicy, 'till@spicybistro.test', 'biller');
      await addStaff(w, w.spicy, 'branchmgr@spicybistro.test', 'location_manager');
      const till = await login(w, 'till@spicybistro.test');
      const manager = await login(w, 'branchmgr@spicybistro.test');
      const body = { items: [{ name: 'Coffee', qty: 1, unit_price: 50 }], gst_pct: 0 };
      const order = (await call(w, 'POST', '/v1/operations/orders', { token: till, body })).body.data;
      const paid = await call(w, 'POST', `/v1/operations/orders/${order.id}/payments`, { token: till, body: { method: 'upi', amount: 50 } });
      expect(paid.body.data.status).toBe('awaiting_payment');
      expect((await call(w, 'POST', `/v1/operations/orders/${order.id}/verify-payment`, { token: till, body: {} })).status).toBe(403);
      const verified = await call(w, 'POST', `/v1/operations/orders/${order.id}/verify-payment`, { token: manager, body: { reference: 'UTR 4455' } });
      expect(verified.status).toBe(200);
      expect(verified.body.data.status).toBe('paid');
    });

    it('an old back-office role has no access until it gets one of the six roles', async () => {
      await addStaff(w, w.spicy, 'marketing@spicybistro.test', 'marketing_manager');
      const t = await login(w, 'marketing@spicybistro.test');
      const me = (await call(w, 'GET', '/v1/auth/me', { token: t })).body.data;
      expect(me.screens).toEqual([]);
      expect(me.member.role_name).toBe('No role — ask your restaurant admin');
      expect((await call(w, 'GET', '/v1/master/menu-items', { token: t })).status).toBe(403);
    });

    it('a menu item bills at its menu price, whatever the till sends', async () => {
      const item = await call(w, 'POST', '/v1/master/menu-items', { token: admin, body: { name: 'Masala Dosa', price: 120 } });
      const o = await call(w, 'POST', '/v1/operations/orders', { token: admin, body: { gst_pct: 0, items: [{ menu_item_id: item.body.data.id, qty: 2, unit_price: 1 }] } });
      expect(Number(o.body.data.subtotal)).toBe(240);
    });
  });

  describe('managing people above you', () => {
    it('a branch manager cannot reset or suspend an admin; the owner is protected from admins', async () => {
      await addStaff(w, w.spicy, 'hr@spicybistro.test', 'location_manager');
      const hr = await login(w, 'hr@spicybistro.test');
      const logins = (await call(w, 'GET', '/v1/staff/logins', { token: admin })).body.data;
      const asha = logins.find((l: { email: string }) => l.email === 'admin@spicybistro.test');
      expect((await call(w, 'POST', `/v1/staff/logins/${asha.user_id}/reset-password`, { token: hr, body: { password: 'Taken-Over-2026' } })).status).toBe(403);
      expect((await call(w, 'PATCH', `/v1/staff/logins/${asha.user_id}`, { token: hr, body: { status: 'Suspended' } })).status).toBe(403);

      await addStaff(w, w.spicy, 'owner@spicybistro.test', 'org_owner');
      const refreshed = (await call(w, 'GET', '/v1/staff/logins', { token: admin })).body.data;
      const owner = refreshed.find((l: { email: string }) => l.email === 'owner@spicybistro.test');
      expect((await call(w, 'POST', `/v1/staff/logins/${owner.user_id}/reset-password`, { token: admin, body: { password: 'Taken-Over-2026' } })).status).toBe(403);
    });
  });
});

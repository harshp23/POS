import { readFileSync } from 'node:fs';
import { SignJWT } from 'jose';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addStaff, call, JWT_SECRET, login, makeWorld, PASSWORD, type World } from './helpers.js';

let w: World;
beforeAll(async () => {
  w = await makeWorld();
});
afterAll(async () => w.close());

describe('sign-in (master-admin users table + JWT)', () => {
  it('signs a restaurant account in and returns its organization, role, panel and branches', async () => {
    const r = await call(w, 'POST', '/v1/auth/login', { body: { email: 'admin@spicybistro.test', password: PASSWORD } });
    expect(r.status).toBe(200);
    const me = r.body.data.me;
    expect(me.organization).toMatchObject({ id: w.spicy.organizationId, name: 'Spicy Bistro', status: 'Active' });
    expect(me.member).toMatchObject({ role: 'org_admin', full_name: 'Asha Admin' });
    expect(me.panel).toBe('vendor');
    expect(me.platform_admin).toBe(false);
    expect(me.locations.map((l: { name: string }) => l.name)).toEqual(['Delhi - Connaught Place', 'Noida Sector 62']);
    expect(me.capabilities.franchise).toEqual(['read', 'write', 'delete']);
  });

  it('accepts a token master-admin issued (same secret, same { userId, email } payload)', async () => {
    const [u] = await w.db.query<{ id: string }>(`select id from users where email = 'admin@spicybistro.test'`);
    const masterAdminToken = await new SignJWT({ userId: u!.id, email: 'admin@spicybistro.test' })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuedAt()
      .setExpirationTime('7d')
      .sign(new TextEncoder().encode(JWT_SECRET));
    const me = await call(w, 'GET', '/v1/auth/me', { token: masterAdminToken });
    expect(me.status).toBe(200);
    expect(me.body.data.organization.name).toBe('Spicy Bistro');
  });

  it('rejects a wrong password or unknown email the same way', async () => {
    for (const body of [{ email: 'admin@spicybistro.test', password: 'nope' }, { email: 'ghost@nowhere.test', password: PASSWORD }]) {
      const r = await call(w, 'POST', '/v1/auth/login', { body });
      expect(r.status).toBe(401);
      expect(r.body.error.code).toBe('invalid_credentials');
    }
  });

  it('refuses a platform account that is neither linked to a restaurant nor a super admin', async () => {
    await w.db.query(
      `insert into users (first_name, last_name, email, phone_number, password, status)
       select 'Plain', 'User', 'plain@proviyaa.test', '+91 91111 22222', password, 'Active' from users where email = 'admin@spicybistro.test'`,
    );
    const r = await call(w, 'POST', '/v1/auth/login', { body: { email: 'plain@proviyaa.test', password: PASSWORD } });
    expect(r.status).toBe(403);
  });

  it('refuses a deactivated account and a suspended restaurant', async () => {
    await addStaff(w, w.spicy, 'leaver@spicybistro.test', 'biller');
    const token = await login(w, 'leaver@spicybistro.test');
    await w.db.query(`update users set status = 'Inactive' where email = 'leaver@spicybistro.test'`);
    expect((await call(w, 'GET', '/v1/auth/me', { token })).status).toBe(403);
    expect((await call(w, 'POST', '/v1/auth/login', { body: { email: 'leaver@spicybistro.test', password: PASSWORD } })).status).toBe(403);

    await addStaff(w, w.burger, 'cook@burgerexpress.test', 'kitchen');
    await w.db.query(`update organizations set status = 'Suspended' where id = $1`, [w.burger.organizationId]);
    const r = await call(w, 'POST', '/v1/auth/login', { body: { email: 'cook@burgerexpress.test', password: PASSWORD } });
    expect(r.status).toBe(403);
    await w.db.query(`update organizations set status = 'Active' where id = $1`, [w.burger.organizationId]);
  });

  it('refreshes a session and rejects a missing or bogus token', async () => {
    const token = await login(w, 'admin@spicybistro.test');
    const refreshed = await call(w, 'POST', '/v1/auth/refresh', { body: { refresh_token: token } });
    expect(refreshed.status).toBe(200);
    expect((await call(w, 'GET', '/v1/auth/me', { token: refreshed.body.data.session.access_token })).status).toBe(200);
    expect((await call(w, 'GET', '/v1/auth/me')).status).toBe(401);
    expect((await call(w, 'GET', '/v1/auth/me', { token: 'not-a-token' })).status).toBe(401);
    const forged = await new SignJWT({ userId: 'x', email: 'x' }).setProtectedHeader({ alg: 'HS256' }).sign(new TextEncoder().encode('wrong-secret-wrong-secret'));
    expect((await call(w, 'GET', '/v1/auth/me', { token: forged })).status).toBe(401);
  });

  it('sends floor staff to the POS panel with no franchise access', async () => {
    await addStaff(w, w.spicy, 'biller@spicybistro.test', 'biller');
    const token = await login(w, 'biller@spicybistro.test');
    const me = await call(w, 'GET', '/v1/auth/me', { token });
    expect(me.body.data.panel).toBe('pos');
    expect(me.body.data.capabilities.franchise).toEqual([]);
    expect((await call(w, 'GET', '/v1/franchise/overview', { token })).status).toBe(403);
  });
});

describe('platform super admin', () => {
  it('lists every organization and opens the one it picks, as owner', async () => {
    const r = await call(w, 'POST', '/v1/auth/login', { body: { email: 'super@proviyaa.test', password: PASSWORD } });
    expect(r.status).toBe(200);
    const me = r.body.data.me;
    expect(me.platform_admin).toBe(true);
    expect(me.organization).toBeNull();
    expect(me.organizations.map((o: { name: string }) => o.name)).toEqual(expect.arrayContaining(['Burger Express', 'Spicy Bistro']));
    const token = r.body.data.session.access_token;

    expect((await call(w, 'GET', '/v1/master/menu-items', { token })).body.error.code).toBe('organization_required');
    const opened = await call(w, 'GET', '/v1/auth/me', { token, org: w.burger.organizationId });
    expect(opened.body.data).toMatchObject({ organization: { name: 'Burger Express' }, member: { role: 'org_owner' } });
    expect((await call(w, 'GET', '/v1/franchise/branches', { token, org: w.burger.organizationId })).status).toBe(200);
  });

  it("doesn't let a restaurant account open another restaurant", async () => {
    const token = await login(w, 'admin@spicybistro.test');
    expect((await call(w, 'GET', '/v1/auth/me', { token, org: w.burger.organizationId })).status).toBe(403);
    expect((await call(w, 'GET', '/v1/master/menu-items', { token, org: w.burger.organizationId })).status).toBe(403);
  });
});

describe('tenant isolation (enforced by the backend — it connects as owner)', () => {
  it("never shows or changes another organization's records", async () => {
    const spicy = await login(w, 'admin@spicybistro.test');
    const burger = await login(w, 'admin@burgerexpress.test');
    const created = await call(w, 'POST', '/v1/master/menu-items', { token: spicy, body: { name: 'Spicy Butter Chicken', price: 380 } });
    expect(created.status).toBe(201);
    const id = created.body.data.id;

    const list = await call(w, 'GET', '/v1/master/menu-items', { token: burger });
    expect(list.body.data.map((i: { id: string }) => i.id)).not.toContain(id);
    expect((await call(w, 'GET', `/v1/master/menu-items/${id}`, { token: burger })).status).toBe(404);
    expect((await call(w, 'PATCH', `/v1/master/menu-items/${id}`, { token: burger, body: { price: 1 } })).status).toBe(404);
    expect((await call(w, 'DELETE', `/v1/master/menu-items/${id}`, { token: burger })).status).toBe(404);
    expect((await call(w, 'GET', `/v1/master/menu-items/${id}`, { token: spicy })).body.data.price).toBe(380);
  });

  it("refuses references to another organization's rows", async () => {
    const spicy = await login(w, 'admin@spicybistro.test');
    const burger = await login(w, 'admin@burgerexpress.test');
    const cat = (await call(w, 'POST', '/v1/master/menu-categories', { token: spicy, body: { name: 'Mains' } })).body.data.id;
    const r = await call(w, 'POST', '/v1/master/menu-items', { token: burger, body: { name: 'Stolen', price: 1, category_id: cat } });
    expect(r.status).toBe(422);
    const t = await call(w, 'POST', '/v1/operations/dining-tables', { token: burger, body: { label: 'X1', location_id: w.spicy.locationIds[0] } });
    expect(t.status).toBe(403);
    const rec = await call(w, 'POST', '/v1/franchise/records', { token: burger, body: { record_type: 'incident', location_id: w.spicy.locationIds[0] } });
    expect(rec.status).toBe(403);
  });

  it("can't overwrite another tenant's rows by pushing their UUIDs from a device", async () => {
    const spicy = await login(w, 'admin@spicybistro.test');
    const burger = await login(w, 'admin@burgerexpress.test');
    const t0 = '2026-09-28T12:00:00.000Z';
    const item = await call(w, 'POST', '/v1/master/menu-items', { token: spicy, body: { name: 'Paneer Tikka', price: 290 } });
    const itemId = item.body.data.id as string;
    const order = await call(w, 'POST', '/v1/operations/orders', {
      token: spicy,
      body: { items: [{ menu_item_id: itemId, qty: 1 }] },
    });
    const orderId = order.body.data.id as string;
    const offer = await call(w, 'PUT', '/v1/master/offers', {
      token: spicy,
      body: {
        id: 'OFF-1', title: 'Fest', code: 'FEST', campaign_type: 'Flat', discount_rule: '10%', min_order: 0, max_discount: 0,
        start_date: null, end_date: null, channels: '', linked_items: '', status: 'Active', usage_count: 0, updated_at: t0,
      },
    });
    const offerRowId = offer.body.data.row_id as string;

    const attack = await call(w, 'POST', '/v1/sync/push', {
      token: burger,
      body: {
        changes: [
          {
            change_id: 'a1', resource: 'menu-items', op: 'upsert',
            row: {
              id: itemId, category_id: 'x', name: 'HACKED', price_minor: 1, is_veg: true, is_bestseller: false, available: true,
              unavailable_reason: null, created_at: t0, sku: '', hsn: '', food_cost_minor: 0, channels: '', kitchen_station: '',
              menu_status: 'Active', availability_label: '', image_url: '', diet_type: 'veg', details_json: '{}',
            },
          },
          {
            change_id: 'a2', resource: 'order-lines', op: 'upsert',
            row: { client_order_id: orderId, item_id: 'x', name: 'HACK', unit_minor: 1, quantity: 1, station: '', is_veg: true, kitchen_done: false },
          },
          { change_id: 'a3', resource: 'order-lines', op: 'delete', row: { client_order_id: orderId, item_id: itemId } },
          {
            change_id: 'a4', resource: 'offers', op: 'upsert',
            row: {
              id: offerRowId, title: 'HACKED', code: 'X', campaign_type: 'X', discount_rule: 'X', min_order: 0, max_discount: 0,
              start_date: null, end_date: null, channels: '', linked_items: '', status: 'Active', usage_count: 0, updated_at: t0,
            },
          },
          {
            change_id: 'a5', resource: 'payments', op: 'upsert',
            row: { payment_id: 'p', client_order_id: orderId, method: 'cash', amount_minor: 100, received_minor: 100, recorded_at: t0 },
          },
        ],
      },
    });
    expect(attack.body.data.results.map((r: { status: string }) => r.status)).toEqual(['rejected', 'rejected', 'rejected', 'rejected', 'rejected']);
    const [mi] = await w.db.query<{ name: string; organization_id: string }>(`select name, organization_id from menu_items where id = $1`, [itemId]);
    expect(mi).toEqual({ name: 'Paneer Tikka', organization_id: w.spicy.organizationId });
    const lines = await w.db.query(`select name from order_items where order_id = $1`, [orderId]);
    expect(lines).toEqual([{ name: 'Paneer Tikka' }]);
    const [of] = await w.db.query<{ title: string }>(`select title from pos_offers where row_id = $1`, [offerRowId]);
    expect(of!.title).toBe('Fest');
    expect(await w.db.query(`select 1 from payments where order_id = $1`, [orderId])).toEqual([]);
  });

  it("refuses another organization's branch in X-Location-Id", async () => {
    const spicy = await login(w, 'admin@spicybistro.test');
    const r = await call(w, 'GET', '/v1/operations/orders', { token: spicy, location: w.burger.locationIds[0] });
    expect(r.status).toBe(403);
  });
});

describe('migration safety', () => {
  it('master-admin migrations 001-008 are recorded like its own runner does', async () => {
    const rows = await w.db.query<{ name: string }>(`select name from _migrations order by name`);
    expect(rows.map((r) => r.name)).toEqual([
      '001_create_users_table.sql', '002_add_user_roles_and_status.sql', '003_drop_business_and_last_login.sql',
      '004_create_organizations_table.sql', '005_create_locations_table.sql', '006_create_security_roles_table.sql',
      '007_drop_role_and_panel_from_users.sql', '008_link_users_to_restaurants.sql',
    ]);
    const [sa] = await w.db.query<{ key: string }>(`select sr.key from users u join security_roles sr on sr.id = u.role_id where u.email = 'superadmin@onlatur.com'`);
    expect(sa!.key).toBe('super_admin');
  });

  it('re-runs the combined SQL cleanly on a database that already has it', async () => {
    const sql = readFileSync(new URL('../../supabase/RUN-IN-SUPABASE.sql', import.meta.url), 'utf8');
    await expect(w.pg.exec(sql)).resolves.toBeDefined();
  });

  it('turns RLS on for every new table and gives the publishable (anon) key nothing', async () => {
    const tables = await w.db.query<{ tablename: string; rowsecurity: boolean }>(
      `select tablename, rowsecurity from pg_tables where schemaname = 'public' and tablename like 'pos\\_%'`,
    );
    // 21 sync/franchise tables + 13 Staff & Users tables + token revocations,
    // + 24 for CRM, marketing, finance, integrations, tasks and settings (20260930).
    expect(tables.length).toBe(59);
    expect(tables.every((t) => t.rowsecurity)).toBe(true);
    for (const { tablename } of tables) {
      await expect(
        w.pg.transaction(async (tx) => {
          await tx.exec('set local role anon');
          await tx.query(`select 1 from public.${tablename} limit 1`);
        }),
      ).rejects.toThrow(/permission denied/);
    }
  });

  it('lets two branches of one organization both have a table "T1"', async () => {
    const spicy = await login(w, 'admin@spicybistro.test');
    for (const loc of w.spicy.locationIds) {
      const r = await call(w, 'POST', '/v1/operations/dining-tables', { token: spicy, location: loc, body: { label: 'T1', seats: 4 } });
      expect(r.status).toBe(201);
      expect(r.body.data.location_id).toBe(loc);
    }
    const dup = await call(w, 'POST', '/v1/operations/dining-tables', { token: spicy, location: w.spicy.locationIds[0], body: { label: 'T1' } });
    expect(dup.status).toBe(409);
  });
});

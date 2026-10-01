import { mkdirSync, readdirSync, readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';
import { hashPassword } from '../auth/master-admin.js';
import type { Db } from './types.js';

const read = (rel: string) => readFileSync(new URL(rel, import.meta.url), 'utf8');
const MASTER_ADMIN_MIGRATIONS = new URL('../../../master-admin/backend/migrations/', import.meta.url);

/// A local stand-in for the Supabase database: the Supabase platform
/// stubs, master-admin's own migrations (users, organizations,
/// org_locations, security_roles …, recorded in master-admin's
/// `_migrations` table), the Proviyaa OS tables the POS uses, and the POS
/// migration. Only ever used for development and tests.
export async function openLocalPglite(dir?: string): Promise<PGlite> {
  if (dir) mkdirSync(dir, { recursive: true });
  const pg = dir ? new PGlite(dir) : new PGlite();
  await pg.waitReady;
  await pg.exec(`create table if not exists public._pos_local_bootstrap (
    name text primary key, applied_at timestamptz not null default now())`);
  const once = async (name: string, sql: () => string) => {
    const done = await pg.query('select 1 from public._pos_local_bootstrap where name = $1', [name]);
    if (done.rows.length) return;
    await pg.exec(sql());
    await pg.query('insert into public._pos_local_bootstrap (name) values ($1)', [name]);
  };

  await once('00_supabase_stubs', () => read('../../sql/local/00_supabase_stubs.sql'));

  // master-admin migrations, exactly as its `npm run migrate` applies them.
  await pg.exec(`create table if not exists _migrations (
    id serial primary key, name varchar(255) unique not null, executed_at timestamptz not null default now())`);
  const applied = new Set((await pg.query<{ name: string }>('select name from _migrations')).rows.map((r) => r.name));
  for (const file of readdirSync(MASTER_ADMIN_MIGRATIONS).filter((f) => f.endsWith('.sql')).sort()) {
    if (applied.has(file)) continue;
    await pg.transaction(async (tx) => {
      await tx.exec(readFileSync(new URL(file, MASTER_ADMIN_MIGRATIONS), 'utf8'));
      await tx.query('insert into _migrations (name) values ($1)', [file]);
    });
  }

  await once('10_os_tables', () => read('../../sql/local/10_live_schema_snapshot.sql'));
  await pg.exec(read('../../../supabase/migrations/20260928_pos_vendor_backend.sql'));
  await pg.exec(read('../../../supabase/migrations/20260930_pos_vendor_business.sql'));
  return pg;
}

/// Serves [pg] over the Postgres wire protocol so node-postgres clients
/// (this backend, master-admin's backend) connect with a DATABASE_URL.
export async function serveLocalPglite(pg: PGlite, port: number): Promise<{ url: string; stop: () => Promise<void> }> {
  const server = new PGLiteSocketServer({ db: pg, port, host: '127.0.0.1', maxConnections: 20 });
  await server.start();
  return { url: `postgresql://postgres:postgres@127.0.0.1:${port}/postgres`, stop: () => server.stop() };
}

// ── seeding helpers (local mode + tests) ────────────────────────────────

export interface AccountSpec {
  email: string;
  password: string;
  firstName?: string;
  lastName?: string;
  phone?: string;
  posRole?: string;
  locationIndex?: number;
}

export interface CreatedOrganization {
  organizationId: string;
  locationIds: string[];
  userIds: Record<string, string>;
}

let phoneSeq = 0;
const nextPhone = () => `+91 90000 ${String(Date.now() % 100000).padStart(5, '0')}${++phoneSeq}`;

/// A partner organization with branches and restaurant accounts — the rows
/// master-admin's onboarding (organizations → locations → accounts) makes.
export async function createOrganization(
  db: Db,
  o: { businessName: string; email: string; locations: { name: string; code: string; area?: string }[]; accounts: AccountSpec[] },
): Promise<CreatedOrganization> {
  const [org] = await db.query<{ id: string }>(
    `insert into organizations (business_name, domain, status, email, phone_number)
     values ($1, 'Restaurant', 'Active', $2, $3) returning id`,
    [o.businessName, o.email, nextPhone()],
  );
  const locationIds: string[] = [];
  for (const l of o.locations) {
    const [loc] = await db.query<{ id: string }>(
      `insert into org_locations (org_id, name, area, code, type, status) values ($1, $2, $3, $4, 'Restaurant', 'Active') returning id`,
      [org!.id, l.name, l.area ?? null, l.code],
    );
    locationIds.push(loc!.id);
  }
  const userIds: Record<string, string> = {};
  for (const a of o.accounts) {
    userIds[a.email] = await addAccount(db, org!.id, { ...a, locationId: a.locationIndex === undefined ? null : locationIds[a.locationIndex]! });
  }
  return { organizationId: org!.id, locationIds, userIds };
}

export async function addAccount(
  db: Db,
  organizationId: string,
  a: AccountSpec & { locationId?: string | null },
): Promise<string> {
  const [u] = await db.query<{ id: string }>(
    `insert into users (first_name, last_name, email, phone_number, password, status, organization_id, location_id, pos_role)
     values ($1, $2, lower($3), $4, $5, 'Active', $6, $7, $8)
     on conflict (email) do update set password = excluded.password, organization_id = excluded.organization_id,
       location_id = excluded.location_id, pos_role = excluded.pos_role, status = 'Active'
     returning id`,
    [a.firstName ?? 'Restaurant', a.lastName ?? 'Admin', a.email, a.phone ?? nextPhone(), await hashPassword(a.password), organizationId, a.locationId ?? null, a.posRole ?? 'org_admin'],
  );
  return u!.id;
}

/// A Proviyaa platform super admin (no organization, security role super_admin).
export async function ensurePlatformAdmin(db: Db, email: string, password: string): Promise<string> {
  const [role] = await db.query<{ id: string }>(`select id from security_roles where key = 'super_admin'`);
  const [u] = await db.query<{ id: string }>(
    `insert into users (first_name, last_name, email, phone_number, password, status, role_id)
     values ('Proviyaa', 'Super Admin', lower($1), $2, $3, 'Active', $4)
     on conflict (email) do update set password = excluded.password, role_id = excluded.role_id, status = 'Active'
     returning id`,
    [email, nextPhone(), await hashPassword(password), role!.id],
  );
  return u!.id;
}

/// First local start: a platform super admin, and the Spicy Bistro partner
/// with three branches, an owner account, sales channels and two One Latur
/// orders waiting for acceptance.
export async function seedLocalDemo(
  db: Db,
  seed: { platformEmail: string; platformPassword: string; vendorEmail: string; vendorPassword: string },
): Promise<void> {
  await ensurePlatformAdmin(db, seed.platformEmail, seed.platformPassword);
  const existing = await db.query(`select 1 from organizations where business_name = 'Spicy Bistro' limit 1`);
  if (existing.length) return;
  const { organizationId } = await createOrganization(db, {
    businessName: 'Spicy Bistro',
    email: 'hello@spicybistro.com',
    locations: [
      { name: 'Delhi - Connaught Place', code: 'DEL-CP', area: 'Connaught Place, New Delhi' },
      { name: 'Noida Sector 62', code: 'NOI-62', area: 'Sector 62, Noida' },
      { name: 'Bengaluru Indiranagar', code: 'BLR-IND', area: '100ft Road, Indiranagar' },
    ],
    accounts: [{ email: seed.vendorEmail, password: seed.vendorPassword, firstName: 'Spicy', lastName: 'Bistro Owner', posRole: 'org_owner' }],
  });
  await db.query(
    `insert into org_bill_settings (organization_id, legal_name, gstin, phone) values ($1, 'Spicy Bistro Foods Pvt Ltd', '07AABCS1234F1Z5', '+91 98100 00000')`,
    [organizationId],
  );
  await db.query(
    `insert into channel_integrations (organization_id, channel, display_name, is_connected)
     values ($1, 'swiggy', 'Swiggy', true), ($1, 'zomato', 'Zomato', true), ($1, 'website', 'One Latur', true)`,
    [organizationId],
  );
  const orders = [
    { name: 'Priya Nair', items: [['Spicy Butter Chicken', 380, 1], ['Garlic Butter Naan', 60, 2]] },
    { name: 'Arjun Mehta', items: [['Paneer Butter Masala', 340, 1], ['Mango Lassi', 180, 2]] },
  ] as const;
  for (const o of orders) {
    const subtotal = o.items.reduce((s, [, p, q]) => s + p * q, 0);
    const gst = Math.round(subtotal * 5) / 100;
    const [row] = await db.query<{ id: string }>(
      `insert into ol_orders (organization_id, status, subtotal, gst, total, payment_method, payment_status, items, delivery_address, customer_hash)
       values ($1, 'placed', $2, $3, $4, 'upi', 'paid', $5, $6, $7) returning id`,
      [organizationId, subtotal, gst, subtotal + gst, JSON.stringify(o.items.map(([n, , q]) => ({ name: n, qty: q }))),
        JSON.stringify({ name: o.name, line1: 'Latur' }), `cust-${o.name.split(' ')[0]!.toLowerCase()}`],
    );
    for (const [name, price, qty] of o.items) {
      await db.query(`insert into ol_order_items (order_id, name, price, qty, line_total) values ($1, $2, $3, $4, $5)`, [row!.id, name, price, qty, price * qty]);
    }
  }
}

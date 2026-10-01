import type { PGlite } from '@electric-sql/pglite';
import { createApp } from '../src/app.js';
import { forgetMembership } from '../src/context.js';
import { addAccount, createOrganization, ensurePlatformAdmin, openLocalPglite, type CreatedOrganization } from '../src/db/local-database.js';
import { PgliteDb } from '../src/db/pglite.js';
import { createPlatform, type Platform } from '../src/platform.js';

export const PASSWORD = 'Test-Password-2026';
export const JWT_SECRET = 'test-secret-shared-with-master-admin-0123456789';

export interface World {
  pg: PGlite;
  db: PgliteDb;
  platform: Platform;
  app: ReturnType<typeof createApp>;
  spicy: CreatedOrganization;
  burger: CreatedOrganization;
  close(): Promise<void>;
}

/// Two partner organizations on one in-memory copy of the live schema
/// (master-admin migrations + OS tables + POS migration):
///   Spicy Bistro   — org_admin admin@spicybistro.test (Asha Admin), branches Delhi CP + Noida
///   Burger Express — org_admin admin@burgerexpress.test, branch Bandra
/// plus a platform super admin, super@proviyaa.test.
export async function makeWorld(): Promise<World> {
  forgetMembership();
  const pg = await openLocalPglite();
  const db = new PgliteDb(pg);
  const platform = createPlatform(db, JWT_SECRET);
  const spicy = await createOrganization(db, {
    businessName: 'Spicy Bistro',
    email: 'hello@spicybistro.test',
    locations: [
      { name: 'Delhi - Connaught Place', code: 'DEL-CP' },
      { name: 'Noida Sector 62', code: 'NOI-62' },
    ],
    accounts: [{ email: 'admin@spicybistro.test', password: PASSWORD, firstName: 'Asha', lastName: 'Admin', posRole: 'org_admin' }],
  });
  const burger = await createOrganization(db, {
    businessName: 'Burger Express',
    email: 'hello@burgerexpress.test',
    locations: [{ name: 'Mumbai - Bandra', code: 'MUM-BAN' }],
    accounts: [{ email: 'admin@burgerexpress.test', password: PASSWORD, firstName: 'Bala', lastName: 'Admin', posRole: 'org_admin' }],
  });
  await ensurePlatformAdmin(db, 'super@proviyaa.test', PASSWORD);
  const app = createApp(platform);
  return { pg, db, platform, app, spicy, burger, close: () => pg.close() };
}

export async function addStaff(w: World, org: CreatedOrganization, email: string, role: string) {
  return addAccount(w.db, org.organizationId, { email, password: PASSWORD, posRole: role, firstName: role, lastName: 'Staff' });
}

export interface ApiResponse<T = any> {
  status: number;
  body: T;
}

export async function call<T = any>(
  w: World,
  method: string,
  path: string,
  opts: { token?: string; body?: unknown; location?: string; org?: string; headers?: Record<string, string> } = {},
): Promise<ApiResponse<T>> {
  const headers: Record<string, string> = { ...(opts.headers ?? {}) };
  if (opts.token) headers.Authorization = `Bearer ${opts.token}`;
  if (opts.location) headers['X-Location-Id'] = opts.location;
  if (opts.org) headers['X-Organization-Id'] = opts.org;
  if (opts.body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await w.app.request(path, {
    method,
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

export async function login(w: World, email: string, password = PASSWORD): Promise<string> {
  const r = await call(w, 'POST', '/v1/auth/login', { body: { email, password } });
  if (r.status !== 200) throw new Error(`login ${email} failed: ${r.status} ${JSON.stringify(r.body)}`);
  return r.body.data.session.access_token as string;
}

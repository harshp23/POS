// `npm run start:local`: a local Postgres (PGlite, served on LOCAL_DB_PORT)
// with master-admin's schema, the OS tables and the POS migration, seeded
// with a platform super admin and the Spicy Bistro partner — then the POS
// backend on top of it. Point master-admin's backend at the printed
// DATABASE_URL (and the same JWT_SECRET) to run the whole platform locally.
// Nothing here contacts Supabase.
import { openLocalPglite, seedLocalDemo, serveLocalPglite } from './db/local-database.js';
import { PgDb } from './db/pg.js';

const dir = process.env.LOCAL_DATA_DIR ?? '.data/pglite';
const port = Number(process.env.LOCAL_DB_PORT ?? 55432);

const pg = await openLocalPglite(dir);
const { url } = await serveLocalPglite(pg, port);

const seedDb = new PgDb(url, 1);
await seedLocalDemo(seedDb, {
  platformEmail: process.env.LOCAL_PLATFORM_EMAIL ?? 'superadmin@onlatur.com',
  platformPassword: process.env.LOCAL_PLATFORM_PASSWORD ?? 'Proviyaa@2026',
  vendorEmail: process.env.LOCAL_SEED_EMAIL ?? 'admin@spicybistro.com',
  vendorPassword: process.env.LOCAL_SEED_PASSWORD ?? 'SpicyBistro@2026',
});
await seedDb.close();

process.env.DATABASE_URL = url;
process.env.JWT_SECRET ??= 'local-development-only-jwt-secret-not-for-production';
console.log(`Local database: ${url}   (use this DATABASE_URL + JWT_SECRET for master-admin/backend too)`);
await import('./server.js');

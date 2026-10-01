import { existsSync } from 'node:fs';
import { serve } from '@hono/node-server';
import { Server as HttpServer } from 'node:http';
import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { PgDb } from './db/pg.js';
import { createPlatform } from './platform.js';

if (existsSync('.env')) process.loadEnvFile('.env');

const config = loadConfig();
const log = (line: string) => console.log(`${new Date().toISOString()} ${line}`);

const db = new PgDb(config.DATABASE_URL, config.DB_POOL_MAX);
await db.query('select 1').catch((e: Error) => {
  console.error(`Cannot reach the database in DATABASE_URL: ${e.message}`);
  process.exit(1);
});
const platform = createPlatform(db, config.JWT_SECRET, config.JWT_EXPIRES_IN);
const app = createApp(platform, { corsOrigins: config.corsOrigins, log });

const server = serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  log(`Proviyaa POS backend listening on http://localhost:${info.port}`);
});
// Keep idle connections open longer than clients reuse them (Dart's
// HttpClient: 15 s, browsers: up to 60 s). Node's 5 s default closes
// connections clients are about to reuse, and their next request fails.
if (server instanceof HttpServer) {
  server.keepAliveTimeout = 65_000;
  server.headersTimeout = 66_000;
}

const shutdown = async () => {
  server.close();
  await platform.close();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

/// Runs a command against a fresh local Postgres (PGlite over the wire
/// protocol) that has the same schema as the live project: master-admin's
/// migrations, the OS tables and the POS migration. The command gets
/// DATABASE_URL in its environment.
///
///   npx tsx scripts/with-local-db.ts -- npm --prefix ../master-admin/backend test
import { spawn } from 'node:child_process';
import { openLocalPglite, serveLocalPglite } from '../src/db/local-database.js';

const sep = process.argv.indexOf('--');
const cmd = sep >= 0 ? process.argv.slice(sep + 1) : [];
if (!cmd.length) {
  console.error('usage: tsx scripts/with-local-db.ts -- <command> [args…]');
  process.exit(2);
}

const pg = await openLocalPglite();
const port = 56000 + Math.floor(Math.random() * 4000);
const { url, stop } = await serveLocalPglite(pg, port);
console.log(`local database ready: ${url}`);

const child = spawn(cmd[0]!, cmd.slice(1), {
  stdio: 'inherit',
  shell: process.platform === 'win32',
  env: { ...process.env, DATABASE_URL: url },
});
const code: number = await new Promise((resolve) => child.on('exit', (c) => resolve(c ?? 1)));
await stop();
await pg.close();
process.exit(code);

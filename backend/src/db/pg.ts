import pg from 'pg';
import type { Db, Row } from './types.js';
import { asDbError, isoTimestamp, SqlDb, toParam } from './sql.js';

const { Pool, types } = pg;

/// Result parsing matched to the Db value conventions.
const parsers = {
  getTypeParser(oid: number, format?: 'text' | 'binary') {
    switch (oid) {
      case 1700: // numeric
      case 20: // int8
        return (v: string) => Number(v);
      case 1184: // timestamptz
        return (v: string) => isoTimestamp(v);
      case 1114: // timestamp
        return (v: string) => v.replace(' ', 'T');
      case 1082: // date
        return (v: string) => v;
      default:
        return types.getTypeParser(oid, format);
    }
  },
};

/// Builds pool settings from DATABASE_URL the way master-admin does:
/// Supabase's direct db.<ref>.supabase.co host (IPv6-only on many
/// networks) is rewritten to the IPv4 session pooler; anything not on
/// localhost uses TLS.
export function poolConfig(databaseUrl: string, max = 10): pg.PoolConfig {
  const url = databaseUrl.trim();
  const direct = /postgresql:\/\/([^:]+):(.*)@db\.([a-z0-9]+)\.supabase\.co:?(\d+)?\/(.*)/.exec(url);
  if (direct) {
    const [, , password, ref, , dbRaw] = direct;
    return {
      host: process.env.SUPABASE_POOLER_HOST ?? 'aws-0-ap-south-1.pooler.supabase.com',
      port: 5432,
      user: `postgres.${ref}`,
      password: decodeURIComponent(password!),
      database: dbRaw ? dbRaw.split('?')[0] : 'postgres',
      ssl: { rejectUnauthorized: false },
      max,
      idleTimeoutMillis: 30_000,
      types: parsers,
    };
  }
  const local = /localhost|127\.0\.0\.1/.test(url);
  return { connectionString: url, ssl: local ? false : { rejectUnauthorized: false }, max, idleTimeoutMillis: 30_000, types: parsers };
}

class PgClientDb extends SqlDb {
  constructor(private readonly client: pg.PoolClient) {
    super();
  }

  protected async run(sql: string, params: unknown[]): Promise<Row[]> {
    try {
      return (await this.client.query(sql, params.map(toParam))).rows;
    } catch (e) {
      throw asDbError(e);
    }
  }

  async transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T> {
    // Already inside one: nested work joins it.
    return fn(this);
  }
}

/// Postgres through node-postgres — production (Supabase) and local
/// (PGlite served over the wire protocol).
export class PgDb extends SqlDb {
  readonly pool: pg.Pool;

  constructor(databaseUrl: string, max = 10) {
    super();
    this.pool = new Pool(poolConfig(databaseUrl, max));
    this.pool.on('error', (e) => console.error('Postgres pool error', e.message));
  }

  protected async run(sql: string, params: unknown[]): Promise<Row[]> {
    try {
      return (await this.pool.query(sql, params.map(toParam))).rows;
    } catch (e) {
      throw asDbError(e);
    }
  }

  async transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('begin');
      const out = await fn(new PgClientDb(client));
      await client.query('commit');
      return out;
    } catch (e) {
      await client.query('rollback').catch(() => undefined);
      throw e;
    } finally {
      client.release();
    }
  }

  close(): Promise<void> {
    return this.pool.end();
  }
}

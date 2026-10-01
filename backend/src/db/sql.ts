import { DbError } from '../lib/errors.js';
import { assertIdent, type Db, type Filter, type Row, type SelectOptions } from './types.js';

const q = (ident: string) => `"${assertIdent(ident)}"`;

/// A text[] parameter (in-filters). Any other array/object is jsonb.
export class TextArray {
  constructor(readonly values: string[]) {}
}

export function toParam(v: unknown): unknown {
  if (v === undefined) return null;
  if (v instanceof TextArray) return v.values;
  if (v instanceof Date) return v.toISOString();
  if (v instanceof Uint8Array) return Buffer.isBuffer(v) ? v : Buffer.from(v);
  if (v !== null && typeof v === 'object') return JSON.stringify(v);
  return v;
}

/// "2026-09-28 14:22:08.818123+00" → "2026-09-28T14:22:08.818123+00:00".
/// Keeping microseconds matters: sync cursors compare timestamps exactly.
export function isoTimestamp(s: string): string {
  let out = s.replace(' ', 'T');
  const tz = /([+-]\d{2})(:?\d{2})?$/.exec(out);
  if (tz && !tz[2]) out = `${out}:00`;
  return out;
}

export function asDbError(e: unknown): DbError {
  if (e instanceof DbError) return e;
  const err = e as { code?: string; message?: string; detail?: string; hint?: string };
  return new DbError(err.code ?? 'XX000', err.message ?? String(e), err.detail, err.hint);
}

/// Builds parameterized SQL for the Db interface; drivers supply `run`.
export abstract class SqlDb implements Db {
  protected abstract run(sql: string, params: unknown[]): Promise<Row[]>;
  abstract transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T>;

  query<T = Row>(sql: string, params: unknown[] = []): Promise<T[]> {
    return this.run(sql, params) as Promise<T[]>;
  }

  private where(filters: Filter[] = [], params: unknown[]): string {
    if (filters.length === 0) return '';
    const parts = filters.map((f) => {
      const c = q(f.col);
      switch (f.op) {
        case 'is':
          return f.value === null ? `${c} is null` : `${c} is ${f.value ? 'true' : 'false'}`;
        case 'in':
          params.push(new TextArray((f.value as unknown[]).map((v) => String(v))));
          return `${c}::text = any($${params.length}::text[])`;
        case 'eq':
          if (f.value === null) return `${c} is null`;
          params.push(f.value);
          return `${c} = $${params.length}`;
        default: {
          const op = { neq: '<>', gt: '>', gte: '>=', lt: '<', lte: '<=', ilike: 'ilike' }[f.op];
          params.push(f.value);
          return `${c} ${op} $${params.length}`;
        }
      }
    });
    return ` where ${parts.join(' and ')}`;
  }

  async select<T = Row>(table: string, opts: SelectOptions = {}): Promise<T[]> {
    const params: unknown[] = [];
    let sql = `select ${opts.columns?.map(q).join(', ') ?? '*'} from public.${q(table)}`;
    sql += this.where(opts.filters, params);
    if (opts.order?.length) sql += ` order by ${opts.order.map((o) => `${q(o.col)} ${o.ascending === false ? 'desc' : 'asc'}`).join(', ')}`;
    if (opts.limit !== undefined) sql += ` limit ${Math.max(0, Math.floor(opts.limit))}`;
    if (opts.offset) sql += ` offset ${Math.max(0, Math.floor(opts.offset))}`;
    return (await this.run(sql, params)) as T[];
  }

  private insertSql(table: string, rows: Row[], params: unknown[]): { sql: string; columns: string[] } {
    const columns = [...new Set(rows.flatMap((r) => Object.keys(r)))];
    const values = rows.map(
      (r) =>
        `(${columns
          .map((c) => {
            if (!(c in r)) return 'default';
            params.push(r[c]);
            return `$${params.length}`;
          })
          .join(', ')})`,
    );
    return { sql: `insert into public.${q(table)} (${columns.map(q).join(', ')}) values ${values.join(', ')}`, columns };
  }

  async insert<T = Row>(table: string, rows: Row[]): Promise<T[]> {
    if (rows.length === 0) return [];
    const params: unknown[] = [];
    const { sql } = this.insertSql(table, rows, params);
    return (await this.run(`${sql} returning *`, params)) as T[];
  }

  async upsert<T = Row>(table: string, rows: Row[], onConflict: string[], guardColumn?: string): Promise<T[]> {
    if (rows.length === 0) return [];
    const params: unknown[] = [];
    const { sql, columns } = this.insertSql(table, rows, params);
    const updates = columns.filter((c) => !onConflict.includes(c)).map((c) => `${q(c)} = excluded.${q(c)}`);
    let action = updates.length ? `do update set ${updates.join(', ')}` : 'do nothing';
    if (guardColumn && updates.length) action += ` where public.${q(table)}.${q(guardColumn)} = excluded.${q(guardColumn)}`;
    return (await this.run(`${sql} on conflict (${onConflict.map(q).join(', ')}) ${action} returning *`, params)) as T[];
  }

  async update<T = Row>(table: string, patch: Row, filters: Filter[]): Promise<T[]> {
    if (filters.length === 0) throw new Error('Refusing an unfiltered update');
    const params: unknown[] = [];
    const sets = Object.entries(patch).map(([k, v]) => {
      params.push(v);
      return `${q(k)} = $${params.length}`;
    });
    if (sets.length === 0) return this.select<T>(table, { filters });
    const sql = `update public.${q(table)} set ${sets.join(', ')}${this.where(filters, params)} returning *`;
    return (await this.run(sql, params)) as T[];
  }

  async delete<T = Row>(table: string, filters: Filter[]): Promise<T[]> {
    if (filters.length === 0) throw new Error('Refusing an unfiltered delete');
    const params: unknown[] = [];
    const sql = `delete from public.${q(table)}${this.where(filters, params)} returning *`;
    return (await this.run(sql, params)) as T[];
  }

  async rpc<T = unknown>(fn: string, args: Row): Promise<T> {
    const params: unknown[] = [];
    const named = Object.entries(args).map(([k, v]) => {
      params.push(v);
      return `${q(k)} => $${params.length}`;
    });
    const rows = await this.run(`select public.${q(fn)}(${named.join(', ')}) as result`, params);
    return rows[0]?.result as T;
  }
}

/// The repository layer's only way into the database.
///
/// The backend connects as the database owner (DATABASE_URL — the same
/// connection master-admin uses), which bypasses RLS. Tenant isolation is
/// therefore enforced here, in code: every service filters on the
/// caller's organization, and upserts can be guarded so a conflicting row
/// of another tenant is never overwritten (see `upsert`'s `guardColumn`).
///
/// Value conventions: timestamps come back as ISO strings with full
/// precision, numeric/bigint as numbers, jsonb parsed, bytea as bytes.

export type Row = Record<string, unknown>;

export type FilterOp = 'eq' | 'neq' | 'gt' | 'gte' | 'lt' | 'lte' | 'in' | 'is' | 'ilike';

export interface Filter {
  col: string;
  op: FilterOp;
  value: unknown;
}

export const eq = (col: string, value: unknown): Filter => ({ col, op: 'eq', value });
export const neq = (col: string, value: unknown): Filter => ({ col, op: 'neq', value });
export const gt = (col: string, value: unknown): Filter => ({ col, op: 'gt', value });
export const gte = (col: string, value: unknown): Filter => ({ col, op: 'gte', value });
export const lt = (col: string, value: unknown): Filter => ({ col, op: 'lt', value });
export const lte = (col: string, value: unknown): Filter => ({ col, op: 'lte', value });
export const isIn = (col: string, value: unknown[]): Filter => ({ col, op: 'in', value });
export const is = (col: string, value: null | boolean): Filter => ({ col, op: 'is', value });
export const ilike = (col: string, value: string): Filter => ({ col, op: 'ilike', value });

export interface OrderBy {
  col: string;
  ascending?: boolean;
}

export interface SelectOptions {
  columns?: string[];
  filters?: Filter[];
  order?: OrderBy[];
  limit?: number;
  offset?: number;
}

export interface Db {
  select<T = Row>(table: string, opts?: SelectOptions): Promise<T[]>;
  insert<T = Row>(table: string, rows: Row[]): Promise<T[]>;
  /// INSERT … ON CONFLICT (onConflict) DO UPDATE. With [guardColumn], a
  /// conflicting row is only updated when its guardColumn equals the new
  /// row's (e.g. organization_id): another tenant's row is left untouched
  /// and that row is simply missing from the result.
  upsert<T = Row>(table: string, rows: Row[], onConflict: string[], guardColumn?: string): Promise<T[]>;
  update<T = Row>(table: string, patch: Row, filters: Filter[]): Promise<T[]>;
  delete<T = Row>(table: string, filters: Filter[]): Promise<T[]>;
  rpc<T = unknown>(fn: string, args: Row): Promise<T>;
  /// Parameterized raw SQL ($1, $2 …) — for joins and aggregates.
  query<T = Row>(sql: string, params?: unknown[]): Promise<T[]>;
  /// Runs [fn] in one database transaction.
  transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T>;
}

export const IDENT = /^[a-z_][a-z0-9_]*$/;

export function assertIdent(name: string): string {
  if (!IDENT.test(name)) throw new Error(`Invalid SQL identifier "${name}"`);
  return name;
}

export function decodeBytea(v: unknown): Uint8Array | null {
  if (v == null) return null;
  if (v instanceof Uint8Array) return v;
  if (typeof v === 'string' && v.startsWith('\\x')) return new Uint8Array(Buffer.from(v.slice(2), 'hex'));
  throw new Error('Unexpected bytea value');
}

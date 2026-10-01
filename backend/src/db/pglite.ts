import type { PGlite, Results, Transaction } from '@electric-sql/pglite';
import type { Db, Row } from './types.js';
import { asDbError, isoTimestamp, SqlDb, toParam } from './sql.js';

const PARSERS = {
  1184: (v: string) => isoTimestamp(v),
  1114: (v: string) => v.replace(' ', 'T'),
  1082: (v: string) => v,
};

function normalize(res: Results<Row>): Row[] {
  const kinds = new Map(res.fields.map((f) => [f.name, f.dataTypeID]));
  return res.rows.map((row) => {
    const out: Row = {};
    for (const [k, v] of Object.entries(row)) {
      const t = kinds.get(k);
      out[k] = v === null || v === undefined ? null : t === 1700 || t === 20 ? Number(v) : v;
    }
    return out;
  });
}

type Runner = Pick<PGlite, 'query'> | Transaction;

class PgliteTxDb extends SqlDb {
  constructor(private readonly tx: Runner) {
    super();
  }

  protected async run(sql: string, params: unknown[]): Promise<Row[]> {
    try {
      return normalize(await this.tx.query<Row>(sql, params.map(toParam), { parsers: PARSERS }));
    } catch (e) {
      throw asDbError(e);
    }
  }

  async transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T> {
    return fn(this);
  }
}

/// Postgres in-process (PGlite) — the backend's own tests. Same SQL, same
/// owner-level access as production.
export class PgliteDb extends SqlDb {
  private readonly direct: PgliteTxDb;

  constructor(readonly pg: PGlite) {
    super();
    this.direct = new PgliteTxDb(pg);
  }

  protected run(sql: string, params: unknown[]): Promise<Row[]> {
    return this.direct.query(sql, params);
  }

  transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T> {
    return this.pg.transaction((tx) => fn(new PgliteTxDb(tx)));
  }
}

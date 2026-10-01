import type { Db, Filter, Row } from '../../db/types.js';
import { eq, gt } from '../../db/types.js';

/// Keyset pagination over (timestamp column, id column). A bulk write
/// stamps many rows with the same timestamp, so "timestamp > cursor"
/// alone would skip rows at a page boundary; the id breaks the tie.
/// Cursor format: "<timestamp>|<id>".
export async function keysetPage(
  db: Db,
  table: string,
  base: Filter[],
  tsCol: string,
  idCol: string,
  cursor: string | null,
  limit: number,
): Promise<{ rows: Row[]; cursor: string | null; more: boolean }> {
  const order = [{ col: tsCol }, { col: idCol }];
  let rows: Row[];
  if (!cursor) {
    rows = await db.select(table, { filters: base, order, limit });
  } else {
    const sep = cursor.lastIndexOf('|');
    const ts = sep > 0 ? cursor.slice(0, sep) : cursor;
    const id = sep > 0 ? cursor.slice(sep + 1) : '';
    const sameInstant = id
      ? await db.select(table, { filters: [...base, eq(tsCol, ts), gt(idCol, id)], order, limit })
      : [];
    const later =
      sameInstant.length < limit
        ? await db.select(table, { filters: [...base, gt(tsCol, ts)], order, limit: limit - sameInstant.length })
        : [];
    rows = [...sameInstant, ...later];
  }
  const last = rows[rows.length - 1];
  return {
    rows,
    cursor: last ? `${last[tsCol] as string}|${last[idCol] as string}` : cursor,
    more: rows.length === limit,
  };
}

import type { Context, Hono } from 'hono';
import { assertBranchAccess, listBranch, requireCan } from '../context.js';
import { eq, is, type Filter } from '../db/types.js';
import { ctxOf, intParam, type Env } from '../http.js';
import { notFound } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import type { MirroredResource } from '../schema/resources.js';
import { MirroredAdapter } from './sync/mirrored.js';

/// REST access to a pos_* mirror table, in device-row shape plus the
/// envelope (row_id, location_id, server_updated_at). Writes go through
/// the same adapter the device sync uses, so both paths produce identical
/// rows.
export function mountMirroredResource(app: Hono<Env>, info: MirroredResource): void {
  const adapter = new MirroredAdapter(info);
  const base = `/${info.resource}`;

  const scope = (c: Context<Env>): Filter[] => {
    const ctx = ctxOf(c);
    const f: Filter[] = [eq('organization_id', ctx.m.organization_id), is('deleted_at', null)];
    if (info.scope !== 'location') return f; // the chain's shared catalogue
    const branch = listBranch(ctx, c.req.query('location_id'));
    if (branch === null) f.push(is('location_id', null));
    else if (branch) f.push(eq('location_id', branch));
    else if (ctx.location) f.push(eq('location_id', ctx.location.id));
    return f;
  };

  const view = (r: Record<string, unknown>) => ({
    row_id: r.row_id,
    location_id: r.location_id,
    server_updated_at: r.server_updated_at,
    ...adapter.toDevice(r),
  });

  app.get(base, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, adapter.module, 'read');
    const limit = intParam(c.req.query('limit'), 100, 500);
    const offset = intParam(c.req.query('offset'), 0, 1_000_000);
    const rows = await ctx.db.select(adapter.table, {
      filters: scope(c),
      order: [{ col: 'server_updated_at', ascending: false }],
      limit,
      offset,
    });
    return c.json({ data: rows.map(view), limit, offset });
  });

  app.get(`${base}/:rowId`, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, adapter.module, 'read');
    const rowId = c.req.param('rowId');
    if (!isUuid(rowId)) throw notFound('This record was not found. It may have been deleted.');
    const [row] = await ctx.db.select(adapter.table, { filters: [...scope(c), eq('row_id', rowId)] });
    if (!row) throw notFound('This record was not found. It may have been deleted.');
    return c.json({ data: view(row) });
  });

  /// Create or replace by device key (the body is a full device row).
  app.put(base, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, adapter.module, 'write');
    const body = (await c.req.json().catch(() => null)) as Record<string, unknown> | null;
    const out = await adapter.upsert(ctx, null, body ?? {});
    const [row] = await ctx.db.select(adapter.table, { filters: [eq('row_id', out.server_id)] });
    return c.json({ data: row ? view(row) : out });
  });

  app.delete(`${base}/:rowId`, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, adapter.module, 'delete');
    const rowId = c.req.param('rowId');
    if (!isUuid(rowId)) throw notFound('This record was not found. It may have been deleted.');
    const [current] = await ctx.db.select(adapter.table, {
      columns: ['location_id'],
      filters: [eq('organization_id', ctx.m.organization_id), eq('row_id', rowId), is('deleted_at', null)],
    });
    if (!current) throw notFound('This record was not found. It may have been deleted.');
    assertBranchAccess(ctx, current.location_id);
    const rows = await ctx.db.update(adapter.table, { deleted_at: new Date().toISOString(), updated_by: ctx.user.id }, [
      eq('organization_id', ctx.m.organization_id),
      eq('row_id', rowId),
      is('deleted_at', null),
    ]);
    if (!rows.length) throw notFound('This record was not found. It may have been deleted.');
    return c.body(null, 204);
  });
}

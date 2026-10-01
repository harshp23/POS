import type { Hono } from 'hono';
import { z } from 'zod';
import { assertBranchAccess, assertOwned, listBranch, requireCan, type RequestContext } from '../context.js';
import { eq, is, type Filter, type OrderBy, type Row } from '../db/types.js';
import { ctxOf, intParam, parseWith, readJson, type Env } from '../http.js';
import { ApiError, conflict, notFound } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import type { Module } from '../permissions.js';

/// Column DSL: "type", "type!" (required on create), "enum:a|b|c" — plus
/// "?" for nullable. Types: text uuid int numeric bool timestamp date json.
export type ColumnSpec = string;
export type Columns = Record<string, ColumnSpec>;

function zodFor(spec: ColumnSpec): { schema: z.ZodTypeAny; required: boolean } {
  let s = spec.trim();
  const required = s.endsWith('!');
  if (required) s = s.slice(0, -1);
  const nullable = s.endsWith('?');
  if (nullable) s = s.slice(0, -1);
  let schema: z.ZodTypeAny;
  if (s.startsWith('enum:')) schema = z.enum(s.slice(5).split('|') as [string, ...string[]]);
  else {
    switch (s) {
      case 'text':
        schema = z.string().max(20_000);
        break;
      case 'uuid':
        schema = z.string().uuid();
        break;
      case 'int':
        schema = z.number().int();
        break;
      case 'numeric':
        schema = z.number().finite();
        break;
      case 'bool':
        schema = z.boolean();
        break;
      case 'timestamp':
        schema = z.string().datetime({ offset: true });
        break;
      case 'date':
        schema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'expected YYYY-MM-DD');
        break;
      case 'json':
        schema = z.any();
        break;
      default:
        throw new Error(`Unknown column spec "${spec}"`);
    }
  }
  return { schema: nullable ? schema.nullable() : schema, required };
}

export function bodySchemas(cols: Columns) {
  const create: Record<string, z.ZodTypeAny> = {};
  const update: Record<string, z.ZodTypeAny> = {};
  for (const [name, spec] of Object.entries(cols)) {
    const { schema, required } = zodFor(spec);
    create[name] = required ? schema : schema.optional();
    update[name] = schema.optional();
  }
  return { create: z.object(create).strict(), update: z.object(update).strict() };
}

export interface TableResource {
  /// URL segment under the module, e.g. "menu-items".
  path: string;
  table: string;
  module: Module;
  /// Tenancy column: organization_id on OS/POS tables, org_id on org_locations.
  orgColumn?: string;
  idColumn?: string;
  columns: Columns;
  /// Branch column: new rows default to the request's branch, and
  /// ?location_id=… filters on it.
  locationColumn?: string;
  /// Columns a client may filter on with ?col=value.
  filters?: string[];
  order?: OrderBy[];
  /// hard = DELETE, soft = set deleted_at, none = 405.
  remove?: 'hard' | 'soft' | 'none';
  /// Column holding the last-change time, for If-Match concurrency checks.
  versionColumn?: string;
  /// Foreign keys a client may send: each value must be a row of that table
  /// owned by the caller's organization (the backend bypasses RLS).
  refs?: Record<string, { table: string; orgColumn?: string }>;
  beforeCreate?: (ctx: RequestContext, row: Row) => Promise<Row> | Row;
  beforeUpdate?: (ctx: RequestContext, patch: Row, existing: Row) => Promise<Row> | Row;
  afterWrite?: (ctx: RequestContext, row: Row) => Promise<void> | void;
}

/// Mounts list / get / create / update / delete for one table. Every
/// query is filtered to the caller's organization *and* runs under the
/// caller's RLS policies — two independent fences.
export function mountTableResource(app: Hono<Env>, r: TableResource): void {
  const org = r.orgColumn ?? 'organization_id';
  const id = r.idColumn ?? 'id';
  const bodies = bodySchemas(r.columns);
  const base = `/${r.path}`;

  const scope = (ctx: RequestContext): Filter[] => {
    const f = [eq(org, ctx.m.organization_id)];
    if (r.remove === 'soft') f.push(is('deleted_at', null));
    return f;
  };

  const findOne = async (ctx: RequestContext, key: string): Promise<Row> => {
    if (!isUuid(key)) throw notFound('This record was not found. It may have been deleted.');
    const [row] = await ctx.db.select(r.table, { filters: [...scope(ctx), eq(id, key)] });
    if (!row) throw notFound('This record was not found. It may have been deleted.');
    if (r.locationColumn) assertBranchAccess(ctx, row[r.locationColumn]);
    return row;
  };

  app.get(base, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, r.module, 'read');
    const filters = scope(ctx);
    for (const col of r.filters ?? []) {
      if (col === r.locationColumn) continue;
      const v = c.req.query(col);
      if (v !== undefined) filters.push(v === 'null' ? is(col, null) : eq(col, v));
    }
    if (r.locationColumn) {
      const branch = listBranch(ctx, c.req.query(r.locationColumn));
      if (branch !== undefined) filters.push(branch === null ? is(r.locationColumn, null) : eq(r.locationColumn, branch));
    }
    const limit = intParam(c.req.query('limit'), 100, 500);
    const offset = intParam(c.req.query('offset'), 0, 1_000_000);
    const rows = await ctx.db.select(r.table, { filters, order: r.order, limit, offset });
    return c.json({ data: rows, limit, offset });
  });

  app.get(`${base}/:id`, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, r.module, 'read');
    return c.json({ data: await findOne(ctx, c.req.param('id')) });
  });

  app.post(base, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, r.module, 'write');
    let row: Row = { ...(await readJson(c, bodies.create)) };
    row[org] = ctx.m.organization_id;
    if (r.locationColumn && row[r.locationColumn] === undefined && ctx.location) row[r.locationColumn] = ctx.location.id;
    if (r.locationColumn) assertBranchAccess(ctx, row[r.locationColumn]);
    await checkRefs(ctx, r, row);
    if (r.beforeCreate) row = await r.beforeCreate(ctx, row);
    const [created] = await ctx.db.insert(r.table, [row]);
    if (!created) throw new ApiError(403, 'forbidden', 'The database did not accept this record for your organization.');
    await r.afterWrite?.(ctx, created);
    return c.json({ data: created }, 201);
  });

  app.patch(`${base}/:id`, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, r.module, 'write');
    const key = c.req.param('id');
    const existing = await findOne(ctx, key);
    const ifMatch = c.req.header('if-match');
    if (ifMatch && r.versionColumn && String(existing[r.versionColumn]) !== ifMatch) {
      throw conflict('This record was changed by someone else. Reload and try again.', { current: existing });
    }
    let patch: Row = { ...(await readJson(c, bodies.update)) };
    await checkRefs(ctx, r, patch);
    if (r.beforeUpdate) patch = await r.beforeUpdate(ctx, patch, existing);
    const [updated] = await ctx.db.update(r.table, patch, [...scope(ctx), eq(id, key)]);
    if (!updated) throw new ApiError(403, 'forbidden', 'Your role cannot change this record.');
    await r.afterWrite?.(ctx, updated);
    return c.json({ data: updated });
  });

  app.delete(`${base}/:id`, async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, r.module, 'delete');
    const key = c.req.param('id');
    await findOne(ctx, key);
    if (r.remove === 'none' || !r.remove) {
      throw new ApiError(405, 'not_deletable', `${r.path} records cannot be deleted; change their status instead.`);
    }
    const rows =
      r.remove === 'soft'
        ? await ctx.db.update(r.table, { deleted_at: new Date().toISOString() }, [...scope(ctx), eq(id, key)])
        : await ctx.db.delete(r.table, [...scope(ctx), eq(id, key)]);
    if (!rows.length) throw new ApiError(403, 'forbidden', 'Your role cannot delete this record.');
    return c.body(null, 204);
  });
}

async function checkRefs(ctx: RequestContext, r: TableResource, row: Row): Promise<void> {
  for (const [col, ref] of Object.entries(r.refs ?? {})) {
    if (row[col] !== undefined && row[col] !== null) await assertOwned(ctx, ref.table, row[col], ref.orgColumn);
  }
}

export { parseWith };

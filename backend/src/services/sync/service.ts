import { z } from 'zod';
import type { RequestContext } from '../../context.js';
import { eq, isIn, type Row } from '../../db/types.js';
import { ApiError, DbError, fromDbError } from '../../lib/errors.js';
import { canonicalJson, sha256 } from '../../lib/ids.js';
import { can } from '../../permissions.js';
import { recomputeOrders } from './mapped/orders.js';
import { adapterFor, adapters, resourceRank } from './registry.js';
import { SyncSession } from './session.js';
import { SyncConflict, type PullPage, type PushChange, type PushResult } from './types.js';

export const MAX_PUSH = 500;

export const pushSchema = z.object({
  changes: z
    .array(
      z.object({
        change_id: z.string().min(1).max(200),
        resource: z.string().min(1),
        op: z.enum(['upsert', 'delete']),
        row: z.record(z.string(), z.unknown()),
        base_version: z.string().nullable().optional(),
      }),
    )
    .max(MAX_PUSH),
});

export const pullSchema = z.object({
  resources: z.array(z.string()).optional(),
  cursors: z.record(z.string(), z.string().nullable()).optional(),
});

function errorOf(e: unknown): { code: string; message: string } {
  if (e instanceof DbError) {
    const api = fromDbError(e);
    return { code: api.code, message: `${api.message} (${e.message})` };
  }
  if (e instanceof ApiError) return { code: e.code, message: e.message };
  return { code: 'internal', message: e instanceof Error ? e.message : String(e) };
}

/// Applies a batch of device changes. Every change gets its own result —
/// one rejected change never blocks the rest (PRD §6) — and a receipt, so
/// a retried change id is answered as "duplicate" with no second effect.
export async function push(ctx: RequestContext, changes: PushChange[]): Promise<PushResult[]> {
  const org = ctx.m.organization_id;
  const results = new Map<string, PushResult>();
  const hashes = new Map(changes.map((c) => [c.change_id, sha256(canonicalJson([c.resource, c.op, c.row]))]));

  const receipts = new Map<string, Row>();
  const ids = changes.map((c) => c.change_id);
  for (let i = 0; i < ids.length; i += 200) {
    const rows = await ctx.db.select('pos_sync_receipts', {
      filters: [eq('organization_id', org), isIn('change_id', ids.slice(i, i + 200))],
    });
    for (const r of rows) receipts.set(r.change_id as string, r);
  }

  const session = new SyncSession(ctx);
  const ordered = [...changes].sort((a, b) => resourceRank(a.resource) - resourceRank(b.resource));
  const fresh: PushResult[] = [];

  for (const change of ordered) {
    const base = { change_id: change.change_id, resource: change.resource };
    const prior = receipts.get(change.change_id);
    if (prior) {
      results.set(
        change.change_id,
        prior.payload_hash === hashes.get(change.change_id)
          ? { ...(prior.result as PushResult), ...base, status: 'duplicate' }
          : { ...base, status: 'rejected', error: { code: 'change_id_reused', message: 'This change id was already used for a different change.' } },
      );
      continue;
    }
    const adapter = adapterFor(change.resource);
    if (!adapter) {
      results.set(change.change_id, { ...base, status: 'rejected', error: { code: 'unknown_resource', message: `Unknown resource ${change.resource}.` } });
      continue;
    }
    const action = change.op === 'delete' ? 'delete' : 'write';
    if (!can(ctx.m.role, adapter.module, action)) {
      const r: PushResult = { ...base, status: 'rejected', error: { code: 'forbidden', message: `Your role (${ctx.m.role_name}) cannot ${action} ${adapter.module} data.` } };
      results.set(change.change_id, r);
      fresh.push(r);
      continue;
    }
    try {
      // Each change is atomic: the record, its extras and its side rows
      // commit together or not at all.
      const out = await ctx.db.transaction((tx) => {
        session.db = tx;
        const txCtx = { ...ctx, db: tx };
        return change.op === 'delete'
          ? adapter.remove(txCtx, session, change.row)
          : adapter.upsert(txCtx, session, change.row, change.base_version ?? null);
      });
      session.db = ctx.db;
      const r: PushResult = { ...base, status: 'accepted', server_id: out?.server_id, version: out?.version ?? null };
      results.set(change.change_id, r);
      fresh.push(r);
    } catch (e) {
      session.db = ctx.db;
      const r: PushResult =
        e instanceof SyncConflict
          ? { ...base, status: 'conflict', error: { code: e.code, message: e.message } }
          : { ...base, status: 'rejected', error: errorOf(e) };
      results.set(change.change_id, r);
      fresh.push(r);
    }
  }

  // Totals / kitchen status of the orders this batch touched; their new
  // versions go back to the device so its next edit isn't a false conflict.
  if (session.touchedOrders.size) {
    const versions = await recomputeOrders(ctx, session.touchedOrders);
    for (const r of fresh) {
      if (r.resource === 'orders' && r.server_id && versions.has(r.server_id)) r.version = versions.get(r.server_id)!;
    }
  }

  // Receipts for accepted changes only: a rejected or conflicting change
  // must be re-evaluated when the device retries it (the order it needed
  // may have arrived, the conflict may have been resolved).
  const receiptRows = fresh
    .filter((r) => r.status === 'accepted')
    .map((r) => ({
      organization_id: org,
      change_id: r.change_id,
      payload_hash: hashes.get(r.change_id)!,
      resource: r.resource,
      status: 'accepted',
      result: r,
      location_id: ctx.location?.id ?? null,
      created_by: ctx.user.id,
    }));
  for (let i = 0; i < receiptRows.length; i += 200) {
    try {
      await ctx.db.upsert('pos_sync_receipts', receiptRows.slice(i, i + 200), ['organization_id', 'change_id']);
    } catch {
      // A missing receipt only costs a "duplicate" label on retry: every
      // change is an idempotent upsert keyed by a stable id.
    }
  }

  return changes.map((c) => results.get(c.change_id)!);
}

/// Everything changed centrally since the device's cursors, per resource,
/// limited to the modules the caller's role may read.
export async function pull(
  ctx: RequestContext,
  wanted: string[] | undefined,
  cursors: Record<string, string | null>,
): Promise<Record<string, PullPage | { error: { code: string; message: string } }>> {
  const out: Record<string, PullPage | { error: { code: string; message: string } }> = {};
  for (const adapter of adapters) {
    if (wanted && !wanted.includes(adapter.resource)) continue;
    if (!can(ctx.m.role, adapter.module, 'read')) continue;
    try {
      out[adapter.resource] = await adapter.pull(ctx, cursors[adapter.resource] ?? null);
    } catch (e) {
      out[adapter.resource] = { error: errorOf(e) };
    }
  }
  return out;
}

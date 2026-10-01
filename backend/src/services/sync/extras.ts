import type { RequestContext } from '../../context.js';
import { eq, isIn, type Row } from '../../db/types.js';
import { forbidden } from '../../lib/errors.js';

export interface Extra {
  client_key: string | null;
  data: Record<string, unknown>;
}

/// Device fields an OS table has no column for, kept in pos_entity_extras
/// (one row per central record) and merged back on pull. Also remembers
/// the device's own key for each record, so a record created on the device
/// keeps its "ORD-9981" / "T1" id on every device.
export async function loadExtras(ctx: RequestContext, entity: string, ids: string[]): Promise<Map<string, Extra>> {
  const out = new Map<string, Extra>();
  for (let i = 0; i < ids.length; i += 200) {
    const rows = await ctx.db.select<{ entity_id: string; client_key: string | null; data: Record<string, unknown> }>(
      'pos_entity_extras',
      {
        columns: ['entity_id', 'client_key', 'data'],
        filters: [eq('entity', entity), eq('organization_id', ctx.m.organization_id), isIn('entity_id', ids.slice(i, i + 200))],
      },
    );
    for (const r of rows) out.set(r.entity_id, { client_key: r.client_key, data: r.data ?? {} });
  }
  return out;
}

/// Upsert guarded by organization: another tenant's row is never touched.
export async function saveExtra(
  ctx: RequestContext,
  entity: string,
  entityId: string,
  clientKey: string | null,
  data: Record<string, unknown>,
): Promise<void> {
  const saved = await ctx.db.upsert(
    'pos_entity_extras',
    [
      {
        entity,
        entity_id: entityId,
        organization_id: ctx.m.organization_id,
        location_id: ctx.location?.id ?? null,
        client_key: clientKey,
        data,
        updated_by: ctx.user.id,
      } satisfies Row,
    ],
    ['entity', 'entity_id'],
    'organization_id',
  );
  if (!saved.length) throw forbidden('That record belongs to another organization.');
}

export async function mergeExtra(ctx: RequestContext, entity: string, entityId: string, patch: Record<string, unknown>): Promise<void> {
  const current = (await loadExtras(ctx, entity, [entityId])).get(entityId);
  await saveExtra(ctx, entity, entityId, current?.client_key ?? null, { ...(current?.data ?? {}), ...patch });
}

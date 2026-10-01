import type { RequestContext } from '../../context.js';
import { eq, is, type Filter, type Row } from '../../db/types.js';
import { keysetPage } from './keyset.js';
import { forbidden } from '../../lib/errors.js';
import { contractTable, type ContractTable } from '../../schema/contract.js';
import { mirrorColumnName, type MirroredResource } from '../../schema/resources.js';
import { coerceDeviceRow, deviceKey, keyColumns, toWireValue } from './device-rows.js';
import { centralId } from './session.js';
import type { DeviceRow, PullPage, SyncAdapter, WriteOutcome } from './types.js';

const PAGE = 1000;

/// Stores a device table column for column in its pos_* mirror. Only the
/// storage envelope is added: row_id, organization, branch, timestamps and
/// a soft-delete tombstone the other devices pick up on pull.
export class MirroredAdapter implements SyncAdapter {
  readonly resource: string;
  readonly module: 'master' | 'operations';
  private readonly t: ContractTable;

  constructor(private readonly info: MirroredResource) {
    this.resource = info.resource;
    this.t = contractTable(info.resource);
    this.module = this.t.module;
  }

  get table(): string {
    return this.info.table;
  }

  rowId(ctx: RequestContext, row: Row): string {
    return centralId(ctx, this.info.scope, this.resource, deviceKey(this.t, row));
  }

  private scopeFilters(ctx: RequestContext): Filter[] {
    const f = [eq('organization_id', ctx.m.organization_id)];
    if (this.info.scope === 'location') f.push(ctx.location ? eq('location_id', ctx.location.id) : is('location_id', null));
    return f;
  }

  /// Device row → mirror row (columns renamed where they clash with the envelope).
  toServer(ctx: RequestContext, device: Row): Row {
    const out: Row = {
      row_id: this.rowId(ctx, device),
      organization_id: ctx.m.organization_id,
      location_id: ctx.location?.id ?? null,
      updated_by: ctx.user.id,
      deleted_at: null,
    };
    for (const c of this.t.columns) out[mirrorColumnName(c.name)] = device[c.name];
    return out;
  }

  toDevice(server: Row): DeviceRow {
    const out: DeviceRow = {};
    for (const c of this.t.columns) out[c.name] = toWireValue(c, server[mirrorColumnName(c.name)]);
    return out;
  }

  async upsert(ctx: RequestContext, _s: unknown, row: DeviceRow): Promise<WriteOutcome> {
    const device = coerceDeviceRow(this.t, row);
    const [saved] = await ctx.db.upsert(this.table, [this.toServer(ctx, device)], ['row_id'], 'organization_id');
    if (!saved) throw forbidden('That record belongs to another organization.');
    return { server_id: String(saved.row_id), version: (saved.server_updated_at as string) ?? null };
  }

  async remove(ctx: RequestContext, _s: unknown, key: DeviceRow): Promise<WriteOutcome | null> {
    const k = coerceDeviceRow(this.t, key, true);
    const rowId = this.rowId(ctx, k);
    const [row] = await ctx.db.update(
      this.table,
      { deleted_at: new Date().toISOString(), updated_by: ctx.user.id },
      [...this.scopeFilters(ctx), eq('row_id', rowId)],
    );
    return row ? { server_id: rowId, version: (row.server_updated_at as string) ?? null } : null;
  }

  async pull(ctx: RequestContext, cursor: string | null): Promise<PullPage> {
    const res = await keysetPage(ctx.db, this.table, this.scopeFilters(ctx), 'server_updated_at', 'row_id', cursor, PAGE);
    const page: PullPage = { rows: [], deleted: [], snapshot: false, cursor: res.cursor, versions: {}, more: res.more };
    for (const r of res.rows) {
      const device = this.toDevice(r);
      if (r.deleted_at) page.deleted.push(keyColumns(this.t, device));
      else {
        page.rows.push(device);
        page.versions[deviceKey(this.t, device)] = r.server_updated_at as string;
      }
    }
    return page;
  }
}

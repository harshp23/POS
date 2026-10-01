import type { RequestContext } from '../../../context.js';
import { eq, type Row } from '../../../db/types.js';
import { forbidden } from '../../../lib/errors.js';
import { contractTable } from '../../../schema/contract.js';
import { coerceDeviceRow } from '../device-rows.js';
import { loadExtras, saveExtra } from '../extras.js';
import { branchFilter, centralId, type SyncSession } from '../session.js';
import type { DeviceRow, PullPage, SyncAdapter, WriteOutcome } from '../types.js';

const TABLE = 'dining_table';
const AREA = 'dining_area';
const FLOORS = ['Ground Floor', 'First Floor', 'Terrace', 'Private Cabanas'];

const labelNumber = (label: string) => Number.parseInt(label.replace(/[^0-9]/g, ''), 10) || 0;

/// restaurant_tables ↔ public.dining_tables (+ dining_areas for floors),
/// one floor plan per branch. The plan (label, seats, floor) lives in the
/// OS tables; the device's live seating state (status, guests, server,
/// open order) rides along in pos_entity_extras.
export class TablesAdapter implements SyncAdapter {
  readonly resource = 'tables';
  readonly module = 'operations' as const;
  private readonly t = contractTable(this.resource);

  private async ensureArea(ctx: RequestContext, floor: string): Promise<string> {
    // The branch's area of that name — it may have been made in the back
    // office (its own id) rather than by a device (a derived id).
    const [named] = await ctx.db.select<Row>('dining_areas', {
      columns: ['id'],
      filters: [eq('organization_id', ctx.m.organization_id), branchFilter(ctx), eq('name', floor)],
      limit: 1,
    });
    if (named) return named.id as string;
    const id = centralId(ctx, 'location', AREA, floor);
    const found = await ctx.db.select('dining_areas', {
      columns: ['id'],
      filters: [eq('id', id), eq('organization_id', ctx.m.organization_id)],
    });
    if (!found.length) {
      const idx = FLOORS.indexOf(floor);
      await ctx.db.insert('dining_areas', [
        {
          id,
          organization_id: ctx.m.organization_id,
          location_id: ctx.location?.id ?? null,
          name: floor,
          sort_order: idx < 0 ? FLOORS.length : idx,
        },
      ]);
    }
    return id;
  }

  async upsert(ctx: RequestContext, s: SyncSession, input: DeviceRow): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const id = centralId(ctx, 'location', TABLE, String(row.id));
    const areaId = await this.ensureArea(ctx, String(row.floor || 'Ground Floor'));
    const saved = await ctx.db.upsert(
      'dining_tables',
      [
        {
          id,
          organization_id: ctx.m.organization_id,
          location_id: ctx.location?.id ?? null,
          area_id: areaId,
          label: String(row.label),
          seats: Math.max(1, Number(row.seats)),
          is_active: true,
          sort_order: labelNumber(String(row.label)),
          created_at: row.created_at,
        },
      ],
      ['id'],
      'organization_id',
    );
    if (!saved.length) throw forbidden('That table belongs to another organization.');
    s.forgetTable(String(row.label));
    await saveExtra(ctx, TABLE, id, String(row.id), {
      zone: row.zone,
      status: row.status,
      floor: row.floor,
      shape: row.shape,
      guest_count: row.guest_count,
      elapsed_minutes: row.elapsed_minutes,
      order_total_minor: row.order_total_minor,
      reserved_by_name: row.reserved_by_name,
      reserved_at: row.reserved_at,
      server_name: row.server_name,
      payment_pending: row.payment_pending,
      current_order_id: row.current_order_id,
      seated_at: row.seated_at,
      last_cleaned_at: row.last_cleaned_at,
    });
    return { server_id: id, version: null };
  }

  async remove(ctx: RequestContext, _s: SyncSession, key: DeviceRow): Promise<WriteOutcome | null> {
    const id = centralId(ctx, 'location', TABLE, String(key.id));
    const rows = await ctx.db.delete('dining_tables', [eq('organization_id', ctx.m.organization_id), eq('id', id)]);
    return rows.length ? { server_id: id, version: null } : null;
  }

  async pull(ctx: RequestContext): Promise<PullPage> {
    const scope = [eq('organization_id', ctx.m.organization_id), branchFilter(ctx)];
    const [tables, areas] = await Promise.all([
      ctx.db.select<Row>('dining_tables', { filters: [...scope, eq('is_active', true)], order: [{ col: 'sort_order' }] }),
      ctx.db.select<Row>('dining_areas', { columns: ['id', 'name'], filters: scope }),
    ]);
    const areaName = new Map(areas.map((a) => [a.id as string, a.name as string]));
    const extras = await loadExtras(ctx, TABLE, tables.map((t) => t.id as string));
    const rows = tables.map((t) => {
      const x = extras.get(t.id as string);
      const d = x?.data ?? {};
      const floor = (d.floor as string) ?? areaName.get(t.area_id as string) ?? 'Ground Floor';
      return {
        id: x?.client_key ?? (t.id as string),
        label: t.label,
        seats: t.seats,
        zone: (d.zone as string) ?? (floor === 'Terrace' ? 'outdoor' : 'indoor'),
        status: (d.status as string) ?? 'available',
        guest_count: (d.guest_count as number) ?? null,
        elapsed_minutes: (d.elapsed_minutes as number) ?? null,
        order_total_minor: (d.order_total_minor as number) ?? null,
        reserved_by_name: (d.reserved_by_name as string) ?? null,
        reserved_at: (d.reserved_at as string) ?? null,
        created_at: new Date(t.created_at as string).toISOString(),
        floor,
        shape: (d.shape as string) ?? 'square',
        server_name: (d.server_name as string) ?? '',
        payment_pending: (d.payment_pending as boolean) ?? false,
        current_order_id: (d.current_order_id as string) ?? null,
        seated_at: (d.seated_at as string) ?? null,
        last_cleaned_at: (d.last_cleaned_at as string) ?? null,
      };
    });
    return { rows, deleted: [], snapshot: true, cursor: null, versions: {}, more: false };
  }
}

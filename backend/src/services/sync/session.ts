import type { RequestContext } from '../../context.js';
import { eq, is, isIn, type Db, type Row } from '../../db/types.js';
import { ApiError } from '../../lib/errors.js';
import { stableId } from '../../lib/ids.js';
import type { Scope } from '../../schema/resources.js';

/// Central id of a device record: see stableId.
export function centralId(ctx: RequestContext, scope: Scope, entity: string, deviceKey: string): string {
  return stableId(ctx.m.organization_id, scope === 'location' ? ctx.locationKey : null, entity, deviceKey);
}

/// Filter for "this branch" on OS tables that got a nullable location_id.
export function branchFilter(ctx: RequestContext, col = 'location_id') {
  return ctx.location ? eq(col, ctx.location.id) : is(col, null);
}

/// State shared by the changes of one push request.
export class SyncSession {
  /// Orders whose lines, KOTs or payments changed: totals and kitchen
  /// status are recomputed once at the end of the batch.
  readonly touchedOrders = new Set<string>();
  private readonly menuItems = new Map<string, boolean>();
  private readonly tablesByLabel = new Map<string, string | null>();
  private readonly ownedOrders = new Set<string>();

  /// The handle lookups run on — the current change's transaction during a
  /// push, so reads see that change's own writes.
  db: Db;

  constructor(private readonly ctx: RequestContext) {
    this.db = ctx.db;
  }

  async menuItemExists(id: string): Promise<boolean> {
    if (!this.menuItems.has(id)) {
      const rows = await this.db.select('menu_items', {
        columns: ['id'],
        filters: [eq('id', id), eq('organization_id', this.ctx.m.organization_id)],
      });
      this.menuItems.set(id, rows.length > 0);
    }
    return this.menuItems.get(id)!;
  }

  async prefetchMenuItems(ids: string[]): Promise<void> {
    const missing = ids.filter((i) => !this.menuItems.has(i));
    for (let i = 0; i < missing.length; i += 200) {
      const chunk = missing.slice(i, i + 200);
      const rows = await this.db.select<{ id: string }>('menu_items', {
        columns: ['id'],
        filters: [isIn('id', chunk), eq('organization_id', this.ctx.m.organization_id)],
      });
      const found = new Set(rows.map((r) => r.id));
      for (const id of chunk) this.menuItems.set(id, found.has(id));
    }
  }

  /// dining_tables.id for a label in this branch (device orders only carry
  /// the table label).
  async tableIdByLabel(label: string): Promise<string | null> {
    if (!this.tablesByLabel.has(label)) {
      const rows = await this.db.select<Row>('dining_tables', {
        columns: ['id'],
        filters: [eq('organization_id', this.ctx.m.organization_id), branchFilter(this.ctx), eq('label', label)],
        limit: 1,
      });
      this.tablesByLabel.set(label, (rows[0]?.id as string) ?? null);
    }
    return this.tablesByLabel.get(label)!;
  }

  /// The central order [orderId] must exist and belong to the caller's
  /// organization before lines / KOTs / payments may reference it.
  async ownOrder(orderId: string): Promise<void> {
    if (this.ownedOrders.has(orderId)) return;
    const [o] = await this.db.select<{ organization_id: string; location_id: string | null }>('orders', {
      columns: ['organization_id', 'location_id'],
      filters: [eq('id', orderId)],
    });
    if (!o) throw new ApiError(422, 'reference_missing', 'The order has not reached the server yet.');
    if (o.organization_id !== this.ctx.m.organization_id) throw new ApiError(403, 'forbidden', 'That order belongs to another organization.');
    if (o.location_id && o.location_id !== (this.ctx.location?.id ?? null)) {
      throw new ApiError(403, 'forbidden', 'That order belongs to another branch.');
    }
    this.ownedOrders.add(orderId);
  }

  forgetTable(label: string): void {
    this.tablesByLabel.delete(label);
  }
}

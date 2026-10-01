import type { RequestContext } from '../../../context.js';
import { eq, type Row } from '../../../db/types.js';
import { forbidden } from '../../../lib/errors.js';
import { toMinor, toRupees } from '../../../lib/money.js';
import { contractTable } from '../../../schema/contract.js';
import { coerceDeviceRow } from '../device-rows.js';
import { loadExtras, saveExtra } from '../extras.js';
import { centralId, type SyncSession } from '../session.js';
import type { DeviceRow, PullPage, SyncAdapter, WriteOutcome } from '../types.js';

const CATEGORY = 'menu_category';
const ITEM = 'menu_item';

const humanize = (key: string) =>
  key
    .replace(/[_-]+/g, ' ')
    .trim()
    .replace(/\b\w/g, (ch) => ch.toUpperCase()) || 'Uncategorized';

/// menu_categories_table ↔ public.menu_categories (chain-wide).
export class MenuCategoriesAdapter implements SyncAdapter {
  readonly resource = 'menu-categories';
  readonly module = 'master' as const;
  private readonly t = contractTable(this.resource);

  async upsert(ctx: RequestContext, _s: SyncSession, input: DeviceRow): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const id = centralId(ctx, 'org', CATEGORY, String(row.id));
    const saved = await ctx.db.upsert(
      'menu_categories',
      [{ id, organization_id: ctx.m.organization_id, name: String(row.name).trim() || humanize(String(row.id)), created_at: row.created_at }],
      ['id'],
      'organization_id',
    );
    if (!saved.length) throw forbidden('That category belongs to another organization.');
    await saveExtra(ctx, CATEGORY, id, String(row.id), {});
    return { server_id: id, version: null };
  }

  async remove(ctx: RequestContext, _s: SyncSession, key: DeviceRow): Promise<WriteOutcome | null> {
    const id = centralId(ctx, 'org', CATEGORY, String(key.id));
    const rows = await ctx.db.delete('menu_categories', [eq('organization_id', ctx.m.organization_id), eq('id', id)]);
    return rows.length ? { server_id: id, version: null } : null;
  }

  async pull(ctx: RequestContext): Promise<PullPage> {
    const cats = await ctx.db.select<Row>('menu_categories', {
      filters: [eq('organization_id', ctx.m.organization_id)],
      order: [{ col: 'sort_order' }, { col: 'name' }],
    });
    const extras = await loadExtras(ctx, CATEGORY, cats.map((c) => c.id as string));
    return {
      rows: cats.map((c) => ({
        id: extras.get(c.id as string)?.client_key ?? (c.id as string),
        name: c.name,
        created_at: new Date(c.created_at as string).toISOString(),
      })),
      deleted: [],
      snapshot: true,
      cursor: null,
      versions: {},
      more: false,
    };
  }
}

function foodType(dietType: string): 'veg' | 'non_veg' | 'egg' {
  if (dietType === 'non-veg' || dietType === 'non_veg' || dietType === 'nonveg') return 'non_veg';
  if (dietType === 'egg') return 'egg';
  return 'veg';
}

function parseDetails(json: unknown): Record<string, unknown> {
  try {
    const v = JSON.parse(String(json ?? '{}'));
    return v && typeof v === 'object' && !Array.isArray(v) ? v : {};
  } catch {
    return {};
  }
}

/// menu_items_table ↔ public.menu_items (chain-wide). Master-only fields
/// (HSN, food cost, channels, menu status, the Add/Edit form details) live
/// in pos_entity_extras.
export class MenuItemsAdapter implements SyncAdapter {
  readonly resource = 'menu-items';
  readonly module = 'master' as const;
  private readonly t = contractTable(this.resource);

  private async ensureCategory(ctx: RequestContext, deviceCategoryId: string): Promise<string> {
    const id = centralId(ctx, 'org', CATEGORY, deviceCategoryId);
    const found = await ctx.db.select('menu_categories', {
      columns: ['id'],
      filters: [eq('id', id), eq('organization_id', ctx.m.organization_id)],
    });
    if (!found.length) {
      await ctx.db.insert('menu_categories', [{ id, organization_id: ctx.m.organization_id, name: humanize(deviceCategoryId) }]);
      await saveExtra(ctx, CATEGORY, id, deviceCategoryId, {});
    }
    return id;
  }

  async upsert(ctx: RequestContext, _s: SyncSession, input: DeviceRow): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const id = centralId(ctx, 'org', ITEM, String(row.id));
    const categoryId = await this.ensureCategory(ctx, String(row.category_id));
    const details = parseDetails(row.details_json);
    const category = String(row.category_id).toLowerCase();
    const prep = Number(details.prepTime ?? details.prep_time ?? details.prepMinutes);
    const [saved] = await ctx.db.upsert(
      'menu_items',
      [
        {
          id,
          organization_id: ctx.m.organization_id,
          category_id: categoryId,
          name: String(row.name).trim(),
          description: typeof details.description === 'string' ? details.description : null,
          sku: row.sku ? String(row.sku) : null,
          price: toRupees(Number(row.price_minor)),
          image_url: row.image_url ? String(row.image_url) : null,
          is_available: Boolean(row.available),
          is_recommended: Boolean(row.is_bestseller),
          station: String(row.kitchen_station || 'main'),
          course: /beverage|drink|lassi|juice|bar/.test(category) ? 'drink' : 'eat',
          food_type: foodType(String(row.diet_type)),
          prep_minutes: Number.isFinite(prep) && prep > 0 ? Math.round(prep) : 10,
          created_at: row.created_at,
        },
      ],
      ['id'],
      'organization_id',
    );
    if (!saved) throw forbidden('That menu item belongs to another organization.');
    await saveExtra(ctx, ITEM, id, String(row.id), {
      category_key: row.category_id,
      hsn: row.hsn,
      food_cost_minor: row.food_cost_minor,
      channels: row.channels,
      kitchen_station: row.kitchen_station,
      menu_status: row.menu_status,
      availability_label: row.availability_label,
      unavailable_reason: row.unavailable_reason,
      diet_type: row.diet_type,
      is_veg: row.is_veg,
      details_json: row.details_json,
    });
    return { server_id: id, version: (saved?.updated_at as string) ?? null };
  }

  async remove(ctx: RequestContext, _s: SyncSession, key: DeviceRow): Promise<WriteOutcome | null> {
    const id = centralId(ctx, 'org', ITEM, String(key.id));
    const rows = await ctx.db.delete('menu_items', [eq('organization_id', ctx.m.organization_id), eq('id', id)]);
    return rows.length ? { server_id: id, version: null } : null;
  }

  async pull(ctx: RequestContext): Promise<PullPage> {
    const org = [eq('organization_id', ctx.m.organization_id)];
    const [items, cats] = await Promise.all([
      ctx.db.select<Row>('menu_items', { filters: org, order: [{ col: 'sort_order' }, { col: 'name' }] }),
      ctx.db.select<Row>('menu_categories', { columns: ['id', 'name'], filters: org }),
    ]);
    const [extras, catExtras] = await Promise.all([
      loadExtras(ctx, ITEM, items.map((i) => i.id as string)),
      loadExtras(ctx, CATEGORY, cats.map((c) => c.id as string)),
    ]);
    const catKey = (id: unknown) => (id ? (catExtras.get(id as string)?.client_key ?? (id as string)) : 'uncategorized');
    const page: PullPage = { rows: [], deleted: [], snapshot: true, cursor: null, versions: {}, more: false };
    for (const i of items) {
      const x = extras.get(i.id as string);
      const d = x?.data ?? {};
      const key = x?.client_key ?? (i.id as string);
      const food = String(i.food_type);
      page.rows.push({
        id: key,
        category_id: (d.category_key as string) ?? catKey(i.category_id),
        name: i.name,
        price_minor: toMinor(i.price),
        is_veg: (d.is_veg as boolean) ?? food === 'veg',
        is_bestseller: Boolean(i.is_recommended),
        available: Boolean(i.is_available),
        unavailable_reason: (d.unavailable_reason as string) ?? null,
        created_at: new Date(i.created_at as string).toISOString(),
        sku: (i.sku as string) ?? '',
        hsn: (d.hsn as string) ?? '',
        food_cost_minor: (d.food_cost_minor as number) ?? 0,
        channels: (d.channels as string) ?? 'POS',
        kitchen_station: (d.kitchen_station as string) ?? (i.station === 'main' ? '' : (i.station as string)),
        menu_status: (d.menu_status as string) ?? 'Active',
        availability_label: (d.availability_label as string) ?? 'In Stock',
        image_url: (i.image_url as string) ?? '',
        diet_type: (d.diet_type as string) ?? (food === 'non_veg' ? 'non-veg' : food),
        details_json:
          (d.details_json as string) ??
          JSON.stringify({ ...(i.description ? { description: i.description } : {}), prepTime: i.prep_minutes }),
      });
      page.versions[key] = i.updated_at as string;
    }
    return page;
  }
}

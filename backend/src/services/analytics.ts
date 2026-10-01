import type { RequestContext } from '../context.js';
import { eq, gte, is, isIn, lt, lte, type Row } from '../db/types.js';
import { badRequest } from '../lib/errors.js';
import { toMinor } from '../lib/money.js';
import { DEFAULT_TIME_ZONE, localDate, localToEpoch, tzOf } from '../lib/time.js';
import { loadExtras } from './sync/extras.js';

/// Chain analytics, computed from the records the POS writes centrally.
/// Where the data can't support a figure (labour cost without a labour
/// input, customer rating with no ratings source) the value is null —
/// never an invented number.

export interface Period {
  from: string;
  to: string;
  days: number;
}

const DAY = 24 * 3600 * 1000;

/// A reporting period. Plain dates (YYYY-MM-DD) and the default "today"
/// are days on the branch's clock ([tz]).
export function periodOf(fromQ?: string, toQ?: string, tz = DEFAULT_TIME_ZONE): Period {
  const parse = (q: string) => (/^\d{4}-\d{2}-\d{2}$/.test(q) ? new Date(localToEpoch(tz, q)) : new Date(q));
  const from = fromQ ? parse(fromQ) : new Date(localToEpoch(tz, localDate(tz)));
  const to = toQ ? parse(toQ) : new Date(from.getTime() + DAY);
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || to <= from) {
    throw badRequest('from/to must be dates with from < to.');
  }
  if (to.getTime() - from.getTime() > 400 * DAY) throw badRequest('Periods are limited to 400 days.');
  return { from: from.toISOString(), to: to.toISOString(), days: (to.getTime() - from.getTime()) / DAY };
}

export const previousPeriod = (p: Period): Period => {
  const len = new Date(p.to).getTime() - new Date(p.from).getTime();
  return { from: new Date(new Date(p.from).getTime() - len).toISOString(), to: p.from, days: p.days };
};

export interface BranchStats {
  location_id: string | null;
  orders: number;
  paid_orders: number;
  /// All money in paise.
  sales_minor: number;
  net_sales_minor: number;
  food_cost_minor: number;
}

const blank = (location_id: string | null): BranchStats => ({
  location_id,
  orders: 0,
  paid_orders: 0,
  sales_minor: 0,
  net_sales_minor: 0,
  food_cost_minor: 0,
});

/// Sales and food cost per branch for a period. Sales = settled orders'
/// totals; food cost = Σ qty × the menu item's Master food cost.
export async function branchStats(ctx: RequestContext, p: Period): Promise<Map<string | null, BranchStats>> {
  const orders = await ctx.db.select<Row>('orders', {
    columns: ['id', 'location_id', 'status', 'total', 'subtotal', 'discount'],
    filters: [eq('organization_id', ctx.m.organization_id), gte('created_at', p.from), lt('created_at', p.to)],
    limit: 20000,
  });
  const stats = new Map<string | null, BranchStats>();
  const paidIds: string[] = [];
  const locOf = new Map<string, string | null>();
  for (const o of orders) {
    const loc = (o.location_id as string) ?? null;
    const s = stats.get(loc) ?? blank(loc);
    stats.set(loc, s);
    if (o.status === 'cancelled') continue;
    s.orders++;
    if (o.status === 'paid' || o.status === 'delivered') {
      s.paid_orders++;
      s.sales_minor += toMinor(o.total);
      s.net_sales_minor += toMinor(o.subtotal) - toMinor(o.discount);
      paidIds.push(o.id as string);
      locOf.set(o.id as string, loc);
    }
  }
  const items: Row[] = [];
  for (let i = 0; i < paidIds.length; i += 200) {
    items.push(
      ...(await ctx.db.select<Row>('order_items', {
        columns: ['order_id', 'menu_item_id', 'qty'],
        filters: [isIn('order_id', paidIds.slice(i, i + 200))],
      })),
    );
  }
  const menuIds = [...new Set(items.map((i) => i.menu_item_id).filter(Boolean))] as string[];
  const costs = await loadExtras(ctx, 'menu_item', menuIds);
  for (const i of items) {
    const cost = Number(costs.get(i.menu_item_id as string)?.data.food_cost_minor ?? 0);
    const s = stats.get(locOf.get(i.order_id as string) ?? null);
    if (s) s.food_cost_minor += cost * Number(i.qty);
  }
  return stats;
}

export interface BranchTarget {
  sales_minor: number;
  orders: number;
  aov_minor: number | null;
  food_cost_target_pct: number | null;
  labour_cost_pct: number | null;
  operating_expense_minor: number | null;
}

/// Targets overlapping the period, prorated by overlapping days.
export async function targetsByBranch(ctx: RequestContext, p: Period): Promise<Map<string, BranchTarget>> {
  // Target periods are whole days on the branch's clock.
  const tz = tzOf(ctx);
  const rows = await ctx.db.select<Row>('pos_branch_targets', {
    filters: [
      eq('organization_id', ctx.m.organization_id),
      lte('period_start', localDate(tz, new Date(new Date(p.to).getTime() - 1))),
      gte('period_end', localDate(tz, new Date(p.from))),
    ],
  });
  const out = new Map<string, BranchTarget>();
  for (const t of rows) {
    const start = localToEpoch(tz, t.period_start as string);
    const end = localToEpoch(tz, t.period_end as string) + DAY;
    const overlap = Math.max(0, Math.min(end, new Date(p.to).getTime()) - Math.max(start, new Date(p.from).getTime()));
    const share = overlap / (end - start);
    const cur = out.get(t.location_id as string) ?? {
      sales_minor: 0,
      orders: 0,
      aov_minor: null,
      food_cost_target_pct: null,
      labour_cost_pct: null,
      operating_expense_minor: null,
    };
    cur.sales_minor += toMinor(t.sales_target) * share;
    cur.orders += Number(t.orders_target) * share;
    if (Number(t.aov_target) > 0) cur.aov_minor = toMinor(t.aov_target);
    cur.food_cost_target_pct = Number(t.food_cost_target_pct);
    if (t.labour_cost_pct !== null) cur.labour_cost_pct = Number(t.labour_cost_pct);
    if (t.operating_expense !== null) cur.operating_expense_minor = (cur.operating_expense_minor ?? 0) + toMinor(t.operating_expense) * share;
    out.set(t.location_id as string, cur);
  }
  return out;
}

export interface MaterialAtBranch {
  row_id: string;
  location_id: string | null;
  material_id: string;
  code: string;
  name: string;
  category: string;
  unit: string;
  stock_qty: number;
  reorder_level: number;
  max_capacity: number;
  purchase_cost: number;
  status: 'Critical' | 'Low' | 'Normal' | 'Surplus' | 'Excess';
}

export function stockStatus(stock: number, reorder: number, max: number): MaterialAtBranch['status'] {
  if (reorder > 0 && stock <= reorder) return 'Critical';
  if (reorder > 0 && stock <= reorder * 1.5) return 'Low';
  if (max > 0 && stock >= max * 0.9) return 'Excess';
  if (reorder > 0 && stock >= reorder * 3) return 'Surplus';
  return 'Normal';
}

export async function materialsAcrossBranches(ctx: RequestContext): Promise<MaterialAtBranch[]> {
  const rows = await ctx.db.select<Row>('pos_raw_materials', {
    filters: [eq('organization_id', ctx.m.organization_id), is('deleted_at', null), eq('active', true)],
    limit: 20000,
  });
  return rows.map((r) => {
    const stock = Number(r.stock_qty);
    const reorder = Number(r.reorder_level);
    const max = Number(r.max_capacity);
    return {
      row_id: r.row_id as string,
      location_id: (r.location_id as string) ?? null,
      material_id: r.id as string,
      code: r.code as string,
      name: r.name as string,
      category: r.category as string,
      unit: r.unit as string,
      stock_qty: stock,
      reorder_level: reorder,
      max_capacity: max,
      purchase_cost: Number(r.purchase_cost),
      status: stockStatus(stock, reorder, max),
    };
  });
}

export interface TransferSuggestion {
  material_id: string;
  material_name: string;
  unit: string;
  from_location_id: string | null;
  to_location_id: string | null;
  quantity: number;
  reason: string;
  impact_minor: number;
}

/// Lateral transfers: a branch at/below reorder level, fed from a branch
/// holding comfortably more than it needs of the same material.
export function transferSuggestions(materials: MaterialAtBranch[]): TransferSuggestion[] {
  const byMaterial = new Map<string, MaterialAtBranch[]>();
  for (const m of materials) byMaterial.set(m.material_id, [...(byMaterial.get(m.material_id) ?? []), m]);
  const out: TransferSuggestion[] = [];
  for (const rows of byMaterial.values()) {
    const short = rows.filter((r) => r.status === 'Critical').sort((a, b) => a.stock_qty - b.stock_qty);
    const donors = rows
      .filter((r) => r.status === 'Surplus' || r.status === 'Excess')
      .sort((a, b) => b.stock_qty - b.reorder_level * 2 - (a.stock_qty - a.reorder_level * 2));
    for (const need of short) {
      const donor = donors.find((d) => d.stock_qty - d.reorder_level * 2 > 0);
      if (!donor) break;
      const spare = donor.stock_qty - donor.reorder_level * 2;
      const want = need.reorder_level * 2 - need.stock_qty;
      const qty = Math.round(Math.min(spare, want) * 100) / 100;
      if (qty <= 0) continue;
      donor.stock_qty -= qty;
      out.push({
        material_id: need.material_id,
        material_name: need.name,
        unit: need.unit,
        from_location_id: donor.location_id,
        to_location_id: need.location_id,
        quantity: qty,
        reason: `${need.name} at ${need.stock_qty} ${need.unit} (reorder level ${need.reorder_level})`,
        impact_minor: Math.round(qty * need.purchase_cost * 100),
      });
    }
  }
  return out;
}

export function healthIndex(targetMetPct: number | null, foodCostPct: number | null, criticalShare: number | null): number {
  const target = targetMetPct === null ? 0.6 : Math.min(targetMetPct, 120) / 120;
  const food = foodCostPct === null ? 0.6 : Math.max(0, Math.min(1, 1 - Math.max(0, foodCostPct - 28) / 20));
  const stock = criticalShare === null ? 0.6 : 1 - criticalShare;
  return Math.round(10 * (0.5 * target + 0.3 * food + 0.2 * stock) * 10) / 10;
}

export const pct = (part: number, whole: number): number | null => (whole > 0 ? Math.round((part / whole) * 1000) / 10 : null);
export const change = (cur: number, prev: number): number | null => (prev > 0 ? Math.round(((cur - prev) / prev) * 1000) / 10 : null);

import { Hono } from 'hono';
import { z } from 'zod';
import { assertOwned, forgetMembership, requireCan, requireOrgWide, type RequestContext } from '../context.js';
import { hashPassword } from '../auth/master-admin.js';
import { POS_ROLE_NAMES, POS_ROLES } from '../permissions.js';
import { eq, gte, is, isIn, type Row } from '../db/types.js';
import { ctxOf, readJson, type Env } from '../http.js';
import { ApiError, conflict, forbidden, notFound, unprocessable } from '../lib/errors.js';
import { isUuid, stableId } from '../lib/ids.js';
import { toMinor } from '../lib/money.js';
import { localDate, tzOf } from '../lib/time.js';
import {
  branchStats,
  change,
  healthIndex,
  materialsAcrossBranches,
  pct,
  periodOf,
  previousPeriod,
  stockStatus,
  targetsByBranch,
  transferSuggestions,
} from './analytics.js';
import { mountTableResource } from './crud.js';

const branchName = (ctx: RequestContext, id: string | null) =>
  id ? (ctx.m.locations.find((l) => l.id === id)?.name ?? 'Unknown branch') : 'Unassigned (no branch)';

async function branchPerformance(ctx: RequestContext, from?: string, to?: string) {
  const p = periodOf(from, to, tzOf(ctx));
  const [stats, targets, materials] = await Promise.all([branchStats(ctx, p), targetsByBranch(ctx, p), materialsAcrossBranches(ctx)]);
  const ids = new Set<string | null>([...ctx.m.locations.map((l) => l.id), ...stats.keys()]);
  const rows = [...ids].map((id) => {
    const s = stats.get(id);
    const t = id ? targets.get(id) : undefined;
    const mats = materials.filter((m) => m.location_id === id);
    const critical = mats.filter((m) => m.status === 'Critical').length;
    const sales = s?.sales_minor ?? 0;
    const targetMet = t && t.sales_minor > 0 ? pct(sales, t.sales_minor) : null;
    const foodCost = s ? pct(s.food_cost_minor, s.net_sales_minor) : null;
    const health = healthIndex(targetMet, foodCost, mats.length ? critical / mats.length : null);
    const loc = ctx.m.locations.find((l) => l.id === id);
    return {
      location_id: id,
      branch_name: branchName(ctx, id),
      code: loc?.code ?? null,
      status_label: loc?.status ?? null,
      revenue_minor: sales,
      orders: s?.orders ?? 0,
      target_minor: t ? Math.round(t.sales_minor) : null,
      target_met_pct: targetMet,
      aov_minor: s && s.paid_orders ? Math.round(sales / s.paid_orders) : null,
      food_cost_pct: foodCost,
      critical_items: critical,
      health_index: health,
      status: health >= 7 ? 'Success' : health >= 5 ? 'Warning' : 'Critical',
    };
  });
  rows.sort((a, b) => b.revenue_minor - a.revenue_minor);
  return { period: p, branches: rows.filter((r) => r.location_id !== null || r.orders > 0) };
}

export function franchiseRoutes(): Hono<Env> {
  const app = new Hono<Env>();
  // Chain management: organization-level roles only.
  app.use('*', async (c, next) => {
    requireOrgWide(ctxOf(c));
    await next();
  });

  // ── organization & branches ──────────────────────────────────────────
  app.get('/organization', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'read');
    const [org] = await ctx.db.select('organizations', { filters: [eq('id', ctx.m.organization_id)] });
    return c.json({
      data: org ?? { id: ctx.m.organization_id, business_name: ctx.m.organization_name, status: ctx.m.organization_status },
    });
  });

  app.patch('/organization', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'delete');
    const body = await readJson(
      c,
      z.object({ business_name: z.string().min(1).max(200).optional(), email: z.string().email().optional() }).strict(),
    );
    const [org] = await ctx.db.update('organizations', body, [eq('id', ctx.m.organization_id)]);
    if (!org) throw forbidden('Only an organization admin can edit the organization profile.');
    forgetMembership();
    return c.json({ data: org });
  });

  mountTableResource(app, {
    path: 'branches',
    table: 'org_locations',
    module: 'franchise',
    orgColumn: 'org_id',
    // Same fields and vocabulary as master-admin's location API.
    columns: {
      name: 'text!',
      area: 'text?',
      code: 'text?',
      type: 'enum:Restaurant|Cloud Kitchen|Delivery Hub|Warehouse|Retail Outlet|Other',
      status: 'enum:Active|Pending|Inactive|Draft',
      time_zone: 'text',
      currency: 'text',
    },
    filters: ['status', 'type'],
    order: [{ col: 'name' }],
    versionColumn: 'updated_at',
    remove: 'none',
    beforeCreate: (ctx, row) => {
      requireCan(ctx, 'franchise', 'delete');
      return row;
    },
    beforeUpdate: (ctx, patch) => {
      requireCan(ctx, 'franchise', 'delete');
      return patch;
    },
    afterWrite: () => forgetMembership(),
  });

  // Staff logins live in the Staff module (/v1/staff/logins), with staff
  // roles and the rule that nobody manages someone above them.

  // ── records, targets, exceptions ─────────────────────────────────────
  mountTableResource(app, {
    path: 'records',
    table: 'pos_franchise_records',
    module: 'franchise',
    columns: {
      record_type: 'enum:stock_transfer|safety_stock_adjustment|target_amendment|audit_report|incident|compliance_task!',
      title: 'text',
      status: 'enum:open|in_progress|completed|cancelled',
      details: 'json',
      location_id: 'uuid?',
    },
    filters: ['record_type', 'status', 'location_id'],
    refs: { location_id: { table: 'org_locations' } },
    order: [{ col: 'created_at', ascending: false }],
    versionColumn: 'updated_at',
    remove: 'soft',
    beforeCreate: (ctx, row) => {
      if (row.location_id && !ctx.m.locations.some((l) => l.id === row.location_id)) throw forbidden('That branch is not in your organization.');
      return { ...row, created_by: ctx.user.id, created_by_name: ctx.m.full_name || ctx.m.email };
    },
  });

  mountTableResource(app, {
    path: 'targets',
    table: 'pos_branch_targets',
    module: 'franchise',
    columns: {
      location_id: 'uuid!',
      period_start: 'date!',
      period_end: 'date!',
      sales_target: 'numeric',
      orders_target: 'int',
      aov_target: 'numeric',
      food_cost_target_pct: 'numeric',
      labour_cost_pct: 'numeric?',
      operating_expense: 'numeric?',
      notes: 'text',
    },
    filters: ['location_id'],
    refs: { location_id: { table: 'org_locations' } },
    order: [{ col: 'period_start', ascending: false }],
    versionColumn: 'updated_at',
    remove: 'hard',
    beforeCreate: (ctx, row) => {
      if (!ctx.m.locations.some((l) => l.id === row.location_id)) throw forbidden('That branch is not in your organization.');
      return { ...row, created_by: ctx.user.id };
    },
  });

  mountTableResource(app, {
    path: 'exceptions',
    table: 'pos_franchise_exceptions',
    module: 'franchise',
    columns: {
      severity: 'enum:info|warning|critical',
      root_cause: 'text!',
      impact: 'text',
      recommended_action: 'text',
      action_type: 'enum:Transfer|Review|Reorder|Other',
      status: 'enum:open|resolved|dismissed',
      location_id: 'uuid?',
    },
    filters: ['status', 'severity', 'location_id'],
    refs: { location_id: { table: 'org_locations' } },
    order: [{ col: 'created_at', ascending: false }],
    versionColumn: 'updated_at',
    remove: 'hard',
    beforeCreate: (ctx, row) => ({ ...row, created_by: ctx.user.id, source: 'manual' }),
    beforeUpdate: (ctx, patch) =>
      patch.status === 'resolved' || patch.status === 'dismissed' ? { ...patch, resolved_at: new Date().toISOString(), resolved_by: ctx.user.id } : patch,
  });

  app.post('/exceptions/resolve-all', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'write');
    const rows = await ctx.db.update(
      'pos_franchise_exceptions',
      { status: 'resolved', resolved_at: new Date().toISOString(), resolved_by: ctx.user.id },
      [eq('organization_id', ctx.m.organization_id), eq('status', 'open')],
    );
    return c.json({ data: { resolved: rows.length } });
  });

  /// Raises one "system" exception per branch material at or below its
  /// reorder level (deduplicated per day), with the transfer suggestion
  /// when another branch can cover it.
  app.post('/exceptions/generate', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'write');
    const materials = await materialsAcrossBranches(ctx);
    const suggestions = transferSuggestions(materials.map((m) => ({ ...m })));
    const day = localDate(tzOf(ctx));
    const candidates = materials
      .filter((m) => m.status === 'Critical')
      .map((m) => {
        const s = suggestions.find((x) => x.material_id === m.material_id && x.to_location_id === m.location_id);
        return {
          organization_id: ctx.m.organization_id,
          location_id: m.location_id,
          severity: m.stock_qty <= 0 ? 'critical' : 'warning',
          root_cause: `Low stock — ${m.name} (${m.stock_qty} ${m.unit}, reorder at ${m.reorder_level})`,
          impact: `₹${Math.round((m.reorder_level * 2 - m.stock_qty) * m.purchase_cost).toLocaleString('en-IN')} of stock to restore par`,
          recommended_action: s
            ? `Transfer ${s.quantity} ${s.unit} from ${branchName(ctx, s.from_location_id)}`
            : `Raise a purchase order for ${m.name}`,
          action_type: s ? 'Transfer' : 'Reorder',
          source: 'system',
          dedupe_key: `stock:${m.location_id ?? 'org'}:${m.material_id}:${day}`,
          created_by: ctx.user.id,
        };
      });
    const existing = candidates.length
      ? await ctx.db.select<Row>('pos_franchise_exceptions', {
          columns: ['dedupe_key'],
          filters: [eq('organization_id', ctx.m.organization_id), isIn('dedupe_key', candidates.map((x) => x.dedupe_key))],
        })
      : [];
    const seen = new Set(existing.map((e) => e.dedupe_key));
    const created = await ctx.db.insert('pos_franchise_exceptions', candidates.filter((x) => !seen.has(x.dedupe_key)));
    return c.json({ data: { created: created.length, exceptions: created } }, 201);
  });

  // ── analytics ────────────────────────────────────────────────────────
  app.get('/overview', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'read');
    const p = periodOf(c.req.query('from'), c.req.query('to'), tzOf(ctx));
    const [cur, prev, targets, materials, openExc] = await Promise.all([
      branchStats(ctx, p),
      branchStats(ctx, previousPeriod(p)),
      targetsByBranch(ctx, p),
      materialsAcrossBranches(ctx),
      ctx.db.select<Row>('pos_franchise_exceptions', {
        columns: ['id'],
        filters: [eq('organization_id', ctx.m.organization_id), eq('status', 'open')],
      }),
    ]);
    const sum = (m: typeof cur, k: 'sales_minor' | 'orders' | 'paid_orders' | 'net_sales_minor' | 'food_cost_minor') =>
      [...m.values()].reduce((s, x) => s + x[k], 0);
    const sales = sum(cur, 'sales_minor');
    const paid = sum(cur, 'paid_orders');
    const aov = paid ? Math.round(sales / paid) : null;
    const prevSales = sum(prev, 'sales_minor');
    const prevPaid = sum(prev, 'paid_orders');
    const foodCostPct = pct(sum(cur, 'food_cost_minor'), sum(cur, 'net_sales_minor'));
    const t = [...targets.values()];
    const salesTarget = t.reduce((s, x) => s + x.sales_minor, 0);
    const aovTargets = t.filter((x) => x.aov_minor !== null);
    const aovTarget = aovTargets.length ? aovTargets.reduce((s, x) => s + x.aov_minor!, 0) / aovTargets.length : null;
    const foodTargets = t.filter((x) => x.food_cost_target_pct !== null);
    const foodTarget = foodTargets.length ? foodTargets.reduce((s, x) => s + x.food_cost_target_pct!, 0) / foodTargets.length : null;
    const labourInputs = t.filter((x) => x.labour_cost_pct !== null);
    const labourPct = labourInputs.length ? labourInputs.reduce((s, x) => s + x.labour_cost_pct!, 0) / labourInputs.length : null;
    const opex = t.reduce((s, x) => s + (x.operating_expense_minor ?? 0), 0);
    const inventoryValue = materials.reduce((s, m) => s + Math.round(m.stock_qty * m.purchase_cost * 100), 0);
    return c.json({
      data: {
        period: p,
        branches: ctx.m.locations.length,
        total_sales_minor: sales,
        sales_vs_target_pct: salesTarget > 0 ? change(sales, salesTarget) : null,
        sales_vs_prior_pct: change(sales, prevSales),
        total_orders: sum(cur, 'orders'),
        orders_vs_prior_pct: change(sum(cur, 'orders'), sum(prev, 'orders')),
        average_order_value_minor: aov,
        aov_vs_target_pct: aov !== null && aovTarget ? change(aov, aovTarget) : null,
        aov_vs_prior_pct: aov !== null && prevPaid ? change(aov, prevSales / prevPaid) : null,
        food_cost_pct: foodCostPct,
        food_cost_vs_target_diff: foodCostPct !== null && foodTarget !== null ? Math.round((foodCostPct - foodTarget) * 10) / 10 : null,
        labour_cost_pct: labourPct,
        operating_profit_minor:
          labourPct !== null ? Math.round(sales - sum(cur, 'food_cost_minor') - (sales * labourPct) / 100 - opex) : null,
        inventory_value_minor: inventoryValue,
        critical_items: materials.filter((m) => m.status === 'Critical').length,
        open_exceptions: openExc.length,
        customer_rating: null,
        total_reviews: null,
      },
    });
  });

  app.get('/branch-performance', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'read');
    return c.json({ data: await branchPerformance(ctx, c.req.query('from'), c.req.query('to')) });
  });

  app.get('/inventory', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'read');
    const materials = await materialsAcrossBranches(ctx);
    const grouped = new Map<string, typeof materials>();
    for (const m of materials) grouped.set(m.material_id, [...(grouped.get(m.material_id) ?? []), m]);
    const rows = [...grouped.values()].map((list) => ({
      material_id: list[0]!.material_id,
      name: list[0]!.name,
      category: list[0]!.category,
      unit: list[0]!.unit,
      chain_stock: Math.round(list.reduce((s, m) => s + m.stock_qty, 0) * 100) / 100,
      chain_target: Math.round(list.reduce((s, m) => s + m.reorder_level * 2, 0) * 100) / 100,
      branches: list.map((m) => ({
        location_id: m.location_id,
        branch_name: branchName(ctx, m.location_id),
        stock_qty: m.stock_qty,
        reorder_level: m.reorder_level,
        status: m.status,
      })),
    }));
    rows.sort((a, b) => a.name.localeCompare(b.name));
    return c.json({
      data: {
        materials: rows,
        transfer_suggestions: transferSuggestions(materials.map((m) => ({ ...m }))).map((s) => ({
          ...s,
          from_branch: branchName(ctx, s.from_location_id),
          to_branch: branchName(ctx, s.to_location_id),
        })),
      },
    });
  });

  app.get('/purchase-requirements', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'read');
    const org = eq('organization_id', ctx.m.organization_id);
    const pos = await ctx.db.select<Row>('pos_purchase_orders', {
      filters: [org, is('deleted_at', null), isIn('status', (c.req.query('status') ?? 'Pending').split(','))],
      order: [{ col: 'order_date', ascending: false }],
      limit: 500,
    });
    if (!pos.length) return c.json({ data: [] });
    const [lines, suppliers, prices] = await Promise.all([
      ctx.db.select<Row>('pos_purchase_order_lines', { filters: [org, is('deleted_at', null), isIn('po_number', pos.map((p) => p.number as string))] }),
      ctx.db.select<Row>('pos_suppliers', { columns: ['id', 'name'], filters: [org, is('deleted_at', null)] }),
      ctx.db.select<Row>('pos_supplier_prices', { filters: [org, is('deleted_at', null)] }),
    ]);
    const supplierName = new Map(suppliers.map((s) => [s.id as string, s.name as string]));
    return c.json({
      data: pos.map((p) => {
        const own = lines.filter((l) => l.po_number === p.number && l.location_id === p.location_id);
        const qty = own.reduce((s, l) => s + Number(l.ordered_qty), 0);
        const amount = own.reduce((s, l) => s + Number(l.ordered_qty) * Number(l.unit_cost), 0);
        const quote = prices.find((q) => q.supplier_id === p.supplier_id && own.some((l) => l.material_id && l.material_id === q.material_id));
        return {
          row_id: p.row_id,
          po_number: p.number,
          location_id: p.location_id,
          branch_name: branchName(ctx, (p.location_id as string) ?? null),
          supplier_id: p.supplier_id,
          supplier_name: supplierName.get(p.supplier_id as string) ?? 'Unknown supplier',
          status: p.status,
          order_date: p.order_date,
          expected_delivery: p.expected_delivery,
          quantity: Math.round(qty * 100) / 100,
          amount_minor: toMinor(amount),
          last_price: quote ? Number(quote.last_price) : null,
          current_price: quote ? Number(quote.current_price) : null,
          variance_pct: quote ? change(Number(quote.current_price), Number(quote.last_price)) : null,
        };
      }),
    });
  });

  app.post('/purchase-orders/:rowId/decision', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'write');
    const rowId = c.req.param('rowId');
    if (!isUuid(rowId)) throw notFound('This purchase order was not found.');
    const { decision } = await readJson(c, z.object({ decision: z.enum(['approve', 'reject']) }));
    const org = eq('organization_id', ctx.m.organization_id);
    const [po] = await ctx.db.select<Row>('pos_purchase_orders', { filters: [org, eq('row_id', rowId), is('deleted_at', null)] });
    if (!po) throw notFound('This purchase order was not found.');
    if (!['Draft', 'Pending'].includes(po.status as string)) throw conflict(`PO ${po.number as string} is ${po.status as string}; it can't be ${decision}d.`);
    const [row] = await ctx.db.update(
      'pos_purchase_orders',
      { status: decision === 'approve' ? 'Approved' : 'Cancelled', updated_at: new Date().toISOString(), updated_by: ctx.user.id },
      [org, eq('row_id', rowId)],
    );
    return c.json({ data: row });
  });

  /// Moves stock of one material between two branches in one transaction:
  /// both branches' on-hand quantities, a Transfer Out / Transfer In stock
  /// movement at each, and a completed stock_transfer record.
  app.post('/stock-transfers', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'write');
    const body = await readJson(
      c,
      z.object({
        material_id: z.string().min(1),
        from_location_id: z.string().uuid(),
        to_location_id: z.string().uuid(),
        quantity: z.number().positive(),
        note: z.string().max(500).optional(),
      }),
    );
    if (body.from_location_id === body.to_location_id) throw unprocessable('Source and destination branch must differ.');
    for (const l of [body.from_location_id, body.to_location_id]) {
      if (!ctx.m.locations.some((x) => x.id === l)) throw forbidden('Both branches must belong to your organization.');
    }
    const record = await ctx.db.transaction((tx) => transferStock({ ...ctx, db: tx }, body));
    return c.json({ data: record }, 201);
  });

  /// Chain-wide stock status of one material (the Branch Detail safety
  /// stock panel).
  app.get('/materials/:materialId', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'franchise', 'read');
    const list = (await materialsAcrossBranches(ctx)).filter((m) => m.material_id === c.req.param('materialId'));
    return c.json({
      data: list.map((m) => ({ ...m, branch_name: branchName(ctx, m.location_id), status: stockStatus(m.stock_qty, m.reorder_level, m.max_capacity) })),
    });
  });

  return app;
}

interface TransferRequest {
  material_id: string;
  from_location_id: string;
  to_location_id: string;
  quantity: number;
  note?: string;
}

async function transferStock(ctx: RequestContext, body: TransferRequest): Promise<Row> {
    const org = ctx.m.organization_id;
    const srcId = stableId(org, body.from_location_id, 'raw-materials', body.material_id);
    const dstId = stableId(org, body.to_location_id, 'raw-materials', body.material_id);
    const [src] = await ctx.db.select<Row>('pos_raw_materials', { filters: [eq('organization_id', org), eq('row_id', srcId), is('deleted_at', null)] });
    if (!src) {
      const [any] = await ctx.db.select<Row>('pos_raw_materials', {
        columns: ['name'],
        filters: [eq('organization_id', org), isIn('row_id', ctx.m.locations.map((l) => stableId(org, l.id, 'raw-materials', body.material_id)))],
      });
      throw notFound(`${(any?.name as string) ?? 'This material'} is not stocked at ${branchName(ctx, body.from_location_id)}.`);
    }
    if (Number(src.stock_qty) < body.quantity) {
      throw conflict(`${branchName(ctx, body.from_location_id)} only has ${Number(src.stock_qty)} ${src.unit as string} of ${src.name as string}.`);
    }

    const [record] = await ctx.db.insert('pos_franchise_records', [
      {
        organization_id: org,
        location_id: body.to_location_id,
        record_type: 'stock_transfer',
        status: 'in_progress',
        title: `Transfer ${body.quantity} ${src.unit as string} ${src.name as string}`,
        details: {
          material_id: body.material_id,
          material_name: src.name,
          unit: src.unit,
          quantity: body.quantity,
          from_location_id: body.from_location_id,
          to_location_id: body.to_location_id,
          from_branch: branchName(ctx, body.from_location_id),
          to_branch: branchName(ctx, body.to_location_id),
          note: body.note ?? '',
        },
        created_by: ctx.user.id,
        created_by_name: ctx.m.full_name || ctx.m.email,
      },
    ]);
    if (!record) throw new ApiError(403, 'forbidden', 'Could not record the transfer.');

    const [dst] = await ctx.db.select<Row>('pos_raw_materials', { filters: [eq('organization_id', org), eq('row_id', dstId)] });
    const now = new Date().toISOString();
    await ctx.db.update('pos_raw_materials', { stock_qty: Number(src.stock_qty) - body.quantity, updated_by: ctx.user.id }, [
      eq('organization_id', org),
      eq('row_id', srcId),
    ]);
    if (dst) {
      await ctx.db.update('pos_raw_materials', { stock_qty: Number(dst.stock_qty) + body.quantity, deleted_at: null, updated_by: ctx.user.id }, [
        eq('organization_id', org),
        eq('row_id', dstId),
      ]);
    } else {
      const copy: Row = { ...src };
      for (const k of ['row_id', 'location_id', 'server_created_at', 'server_updated_at', 'deleted_at', 'updated_by']) delete copy[k];
      await ctx.db.insert('pos_raw_materials', [
        { ...copy, row_id: dstId, location_id: body.to_location_id, stock_qty: body.quantity, updated_by: ctx.user.id },
      ]);
    }
    for (const [loc, delta, reason] of [
      [body.from_location_id, -body.quantity, 'Transfer Out'],
      [body.to_location_id, body.quantity, 'Transfer In'],
    ] as const) {
      // Server-made movements use ids ≥ 1e9 so they never collide with the
      // branch device's own autoincrement ids.
      const [last] = await ctx.db.select<Row>('pos_stock_movements', {
        columns: ['id'],
        filters: [eq('organization_id', org), eq('location_id', loc), gte('id', 1_000_000_000)],
        order: [{ col: 'id', ascending: false }],
        limit: 1,
      });
      const id = last ? Number(last.id) + 1 : 1_000_000_001;
      await ctx.db.insert('pos_stock_movements', [
        {
          row_id: stableId(org, loc, 'stock-movements', String(id)),
          organization_id: org,
          location_id: loc,
          id,
          material_id: body.material_id,
          qty_delta: delta,
          reason,
          reference: `TRF-${(record.id as string).slice(0, 8).toUpperCase()}`,
          unit_cost: Number(src.purchase_cost),
          created_at: now,
          updated_by: ctx.user.id,
        },
      ]);
    }
    const [done] = await ctx.db.update('pos_franchise_records', { status: 'completed' }, [eq('organization_id', org), eq('id', record.id)]);
    return done ?? record;
}

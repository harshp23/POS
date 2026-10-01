import type { RequestContext } from '../../../context.js';
import { eq, gte, isIn, type Row } from '../../../db/types.js';
import { ApiError, unprocessable } from '../../../lib/errors.js';
import { canPlaceOrders, canTakePayments, canVerifyPayments } from '../../../permissions.js';
import { orderTotals, toMinor, toRupees } from '../../../lib/money.js';
import { contractTable } from '../../../schema/contract.js';
import { coerceDeviceRow } from '../device-rows.js';
import { loadExtras, saveExtra, type Extra } from '../extras.js';
import { keysetPage } from '../keyset.js';
import { branchFilter, centralId, type SyncSession } from '../session.js';
import { SyncConflict, type DeviceRow, type PullPage, type SyncAdapter, type WriteOutcome } from '../types.js';

const ORDER = 'order';
const LINE = 'order_line';
const KOT = 'kot';
const PAYMENT = 'payment';

const OPEN_STATUSES = ['new', 'in_billing', 'sent_to_kitchen', 'ready', 'awaiting_payment'];

// ── vocabulary: device ↔ OS CHECK constraints ─────────────────────────────

function osChannel(channel: string, orderType: string): string {
  switch (channel || orderType) {
    case 'dineIn':
      return 'dine_in';
    case 'takeaway':
      return 'pickup';
    case 'delivery':
      return 'delivery';
    default:
      return 'other';
  }
}

function deviceChannel(osChannel: string): string {
  return { dine_in: 'dineIn', pickup: 'takeaway', delivery: 'delivery' }[osChannel] ?? 'takeaway';
}

function orderPaymentMethod(method: unknown): string | null {
  const m = String(method ?? '').toLowerCase();
  if (m.startsWith('split')) return 'split';
  return ['cash', 'upi', 'card'].includes(m) ? m : null;
}

function tenderMethod(method: unknown): string {
  const m = String(method ?? '').toLowerCase();
  if (['cash', 'upi', 'card', 'wallet', 'due'].includes(m)) return m;
  return 'other';
}

const placedBy = (source: unknown) =>
  ({ captain: 'captain', qr: 'guest', online: 'integration' })[String(source ?? '').toLowerCase()] ?? 'pos';

const deviceSource = (placed: unknown) =>
  ({ captain: 'Captain', guest: 'QR', integration: 'Online' })[String(placed)] ?? 'POS';

const kotStatus = (s: unknown) =>
  ({ newTicket: 'new', accepted: 'preparing', preparing: 'preparing', ready: 'ready', completed: 'delivered' })[String(s)] ?? 'new';

const deviceKotStatus = (s: unknown) =>
  ({ new: 'newTicket', preparing: 'preparing', ready: 'ready', delivered: 'completed' })[String(s)] ?? 'newTicket';

function opsStatusFromOs(status: unknown): string {
  switch (status) {
    case 'paid':
    case 'delivered':
      return 'settled';
    case 'cancelled':
      return 'cancelled';
    case 'awaiting_payment':
    case 'in_billing':
      return 'billed';
    default:
      return 'open';
  }
}

const iso = (v: unknown) => (v ? new Date(v as string).toISOString() : null);

// ── order windows shared by the four pulls ────────────────────────────────

interface OrderWindow {
  orders: Row[];
  extras: Map<string, Extra>;
  cursor: string | null;
  more: boolean;
}

/// The orders a device should hold: on first sync every open order plus
/// the last 36 hours; afterwards everything changed since the cursor.
async function orderWindow(ctx: RequestContext, cursor: string | null): Promise<OrderWindow> {
  const scope = [eq('organization_id', ctx.m.organization_id), branchFilter(ctx)];
  let orders: Row[];
  let next: string | null;
  let more = false;
  if (cursor) {
    const page = await keysetPage(ctx.db, 'orders', scope, 'updated_at', 'id', cursor, 500);
    orders = page.rows;
    next = page.cursor;
    more = page.more;
  } else {
    const since = new Date(Date.now() - 36 * 3600 * 1000).toISOString();
    const [recent, open] = await Promise.all([
      ctx.db.select<Row>('orders', { filters: [...scope, gte('created_at', since)], limit: 2000 }),
      ctx.db.select<Row>('orders', { filters: [...scope, isIn('status', OPEN_STATUSES)], limit: 2000 }),
    ]);
    const byId = new Map([...recent, ...open].map((o) => [o.id as string, o]));
    orders = [...byId.values()].sort((a, b) =>
      String(a.updated_at).localeCompare(String(b.updated_at)) || String(a.id).localeCompare(String(b.id)),
    );
    const last = orders[orders.length - 1];
    next = last ? `${last.updated_at as string}|${last.id as string}` : null;
  }
  const extras = await loadExtras(ctx, ORDER, orders.map((o) => o.id as string));
  return { orders, extras, cursor: next, more };
}

const orderKey = (w: OrderWindow, id: string) => w.extras.get(id)?.client_key ?? id;

async function childrenOf(ctx: RequestContext, table: string, orderIds: string[]): Promise<Row[]> {
  const out: Row[] = [];
  for (let i = 0; i < orderIds.length; i += 200) {
    out.push(...(await ctx.db.select<Row>(table, { filters: [isIn('order_id', orderIds.slice(i, i + 200))] })));
  }
  return out;
}

// ── orders ────────────────────────────────────────────────────────────────

/// orders ↔ public.orders. The order number comes from the OS's
/// next_org_seq(); money totals and the kitchen-driven status are
/// recomputed from order_items / kot_tickets once per push (recompute()).
export class OrdersAdapter implements SyncAdapter {
  readonly resource = 'orders';
  readonly module = 'operations' as const;
  private readonly t = contractTable(this.resource);

  async upsert(ctx: RequestContext, s: SyncSession, input: DeviceRow, baseVersion: string | null): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const key = String(row.client_order_id);
    const id = centralId(ctx, 'location', ORDER, key);
    const [existing] = await ctx.db.select<Row>('orders', { filters: [eq('organization_id', ctx.m.organization_id), eq('id', id)] });
    if (!existing && !canPlaceOrders(ctx.m.role)) {
      throw new ApiError(403, 'forbidden', `Your role (${ctx.m.role_name}) cannot place orders.`);
    }
    if (String(row.ops_status) === 'settled' && existing?.status !== 'paid' && !canTakePayments(ctx.m.role)) {
      throw new ApiError(403, 'forbidden', `Your role (${ctx.m.role_name}) cannot settle bills.`);
    }
    // An order never moves between branches: a device of branch A cannot
    // overwrite branch B's order by sending its id.
    if (existing && existing.location_id && existing.location_id !== (ctx.location?.id ?? null)) {
      throw new ApiError(403, 'forbidden', 'That order belongs to another branch.');
    }
    if (existing && baseVersion && existing.updated_at !== baseVersion) {
      throw new SyncConflict(`Order ${key} was changed on another device or in the back office.`, existing);
    }

    const ops = String(row.ops_status);
    // Card / UPI money counts as received only once a manager
    // has verified it; a device may not settle such an order on its own.
    const method = orderPaymentMethod(row.payment_method);
    if (ops === 'settled' && method !== 'cash' && existing?.status !== 'paid' && !canVerifyPayments(ctx.m.role)) {
      throw new ApiError(403, 'verification_required', 'Card / UPI payments must be verified by a manager before the order is settled.');
    }
    // Paid and cancelled are final: a device that has not seen a
    // verification or a back-office cancel yet cannot undo it.
    const final = existing && ['paid', 'cancelled'].includes(existing.status as string) ? (existing.status as string) : null;
    const status =
      final ??
      (ops === 'cancelled'
        ? 'cancelled'
        : ops === 'settled'
          ? 'paid'
          : ops === 'billed'
            ? 'awaiting_payment'
            : existing && ['new', 'sent_to_kitchen', 'ready'].includes(existing.status as string)
              ? existing.status
              : 'new');

    const fields: Row = {
      location_id: ctx.location?.id ?? null,
      channel: osChannel(String(row.channel), String(row.order_type)),
      status,
      table_id: row.table_label ? await s.tableIdByLabel(String(row.table_label)) : null,
      customer_name: row.customer_name ? String(row.customer_name) : null,
      captain_name: row.server_name ? String(row.server_name) : null,
      gst_pct: Number(row.tax_pct),
      payment_method: orderPaymentMethod(row.payment_method),
      placed_by: placedBy(row.source),
      guest_count: Math.max(1, Number(row.guests ?? 1)),
      notes: row.notes ? String(row.notes) : null,
      paid_at: final === 'paid' ? existing!.paid_at : row.settled_at,
    };

    let saved: Row | undefined;
    if (existing) {
      [saved] = await ctx.db.update('orders', fields, [eq('organization_id', ctx.m.organization_id), eq('id', id)]);
    } else {
      const orderNo = await ctx.db.rpc<number>('next_org_seq', { org: ctx.m.organization_id, counter_kind: 'order' });
      [saved] = await ctx.db.insert('orders', [
        {
          ...fields,
          id,
          organization_id: ctx.m.organization_id,
          order_no: orderNo,
          display_no: key,
          created_at: row.created_at,
        },
      ]);
    }
    if (!saved) throw new ApiError(403, 'forbidden', 'The database did not accept this order for your organization.');
    await saveExtra(ctx, ORDER, id, key, {
      device_location: row.location_id,
      currency_code: row.currency_code,
      order_type: row.order_type,
      channel: row.channel,
      source: row.source,
      ops_status: row.ops_status,
      discount_pct: row.discount_pct,
      bill_no: row.bill_no,
      payment_method: row.payment_method,
      table_label: row.table_label,
      recorded_by: ctx.user.id,
    });
    s.touchedOrders.add(id);
    return { server_id: id, version: (saved.updated_at as string) ?? null };
  }

  async remove(): Promise<WriteOutcome | null> {
    throw unprocessable('Orders are never deleted; cancel the order instead.');
  }

  async pull(ctx: RequestContext, cursor: string | null): Promise<PullPage> {
    const w = await orderWindow(ctx, cursor);
    const tableIds = [...new Set(w.orders.map((o) => o.table_id).filter(Boolean))] as string[];
    const tables = tableIds.length
      ? await ctx.db.select<Row>('dining_tables', { columns: ['id', 'label'], filters: [isIn('id', tableIds)] })
      : [];
    const label = new Map(tables.map((t) => [t.id as string, t.label as string]));
    const page: PullPage = { rows: [], deleted: [], snapshot: false, cursor: w.cursor, versions: {}, more: w.more };
    for (const o of w.orders) {
      const d = w.extras.get(o.id as string)?.data ?? {};
      const key = orderKey(w, o.id as string);
      const subtotal = Number(o.subtotal);
      page.rows.push({
        client_order_id: key,
        location_id: (d.device_location as string) ?? 'location-demo',
        currency_code: (d.currency_code as string) ?? 'INR',
        status: 'synchronized',
        order_type: (d.order_type as string) ?? (o.channel === 'dine_in' ? 'dineIn' : 'takeaway'),
        table_label: (d.table_label as string) ?? (o.table_id ? (label.get(o.table_id as string) ?? null) : null),
        created_at: iso(o.created_at),
        // Paid / cancelled on the server (a verification, a back-office
        // cancel) win over the status the device last sent.
        ops_status: ['paid', 'cancelled'].includes(String(o.status))
          ? opsStatusFromOs(o.status)
          : ((d.ops_status as string) ?? opsStatusFromOs(o.status)),
        channel: (d.channel as string) ?? deviceChannel(String(o.channel)),
        source: (d.source as string) ?? deviceSource(o.placed_by),
        guests: o.guest_count ?? null,
        server_name: (o.captain_name as string) ?? '',
        notes: (o.notes as string) ?? '',
        discount_pct: (d.discount_pct as number) ?? (subtotal > 0 ? Math.round((Number(o.discount) / subtotal) * 10000) / 100 : 0),
        tax_pct: Number(o.gst_pct),
        bill_no: (d.bill_no as number) ?? null,
        payment_method: (d.payment_method as string) ?? (o.payment_method as string) ?? null,
        settled_at: iso(o.paid_at),
        customer_name: (o.customer_name as string) ?? '',
        // The order's number as the panel shows it (server-owned).
        display_no: (o.display_no as string) ?? key,
      });
      page.versions[key] = o.updated_at as string;
    }
    return page;
  }
}

/// Re-derives each touched order's totals (from order_items) and, while
/// the order is still with the kitchen, its status (from kot_tickets).
/// Returns the orders' new versions.
export async function recomputeOrders(ctx: RequestContext, orderIds: Iterable<string>): Promise<Map<string, string>> {
  const versions = new Map<string, string>();
  const ids = [...orderIds];
  if (!ids.length) return versions;
  const extras = await loadExtras(ctx, ORDER, ids);
  for (const id of ids) {
    const [order] = await ctx.db.select<Row>('orders', { filters: [eq('organization_id', ctx.m.organization_id), eq('id', id)] });
    if (!order) continue;
    const [lines, kots] = await Promise.all([
      ctx.db.select<Row>('order_items', { columns: ['qty', 'unit_price', 'status'], filters: [eq('order_id', id)] }),
      ctx.db.select<Row>('kot_tickets', { columns: ['status'], filters: [eq('order_id', id)] }),
    ]);
    const discountPct = Number(extras.get(id)?.data.discount_pct ?? 0);
    const totals = orderTotals(
      lines.filter((l) => l.status !== 'cancelled').map((l) => ({ qty: Number(l.qty), unit_price: Number(l.unit_price) })),
      discountPct,
      Number(order.gst_pct),
    );
    let status = order.status as string;
    if (['new', 'sent_to_kitchen', 'ready'].includes(status)) {
      if (!kots.length) status = 'new';
      else status = kots.every((k) => k.status === 'ready' || k.status === 'delivered') ? 'ready' : 'sent_to_kitchen';
    }
    const [updated] = await ctx.db.update('orders', { ...totals, status }, [eq('organization_id', ctx.m.organization_id), eq('id', id)]);
    if (updated) versions.set(id, updated.updated_at as string);
  }
  return versions;
}

// ── order lines ───────────────────────────────────────────────────────────

/// order_lines ↔ public.order_items (name and price are snapshots, so a
/// line survives its menu item; menu_item_id links it while it exists).
export class OrderLinesAdapter implements SyncAdapter {
  readonly resource = 'order-lines';
  readonly module = 'operations' as const;
  private readonly t = contractTable(this.resource);

  private ids(ctx: RequestContext, row: Row) {
    const orderKey = String(row.client_order_id);
    return {
      lineKey: `${orderKey}|${String(row.item_id)}`,
      lineId: centralId(ctx, 'location', LINE, `${orderKey}|${String(row.item_id)}`),
      orderId: centralId(ctx, 'location', ORDER, orderKey),
    };
  }

  async upsert(ctx: RequestContext, s: SyncSession, input: DeviceRow): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const { lineKey, lineId, orderId } = this.ids(ctx, row);
    await s.ownOrder(orderId);
    if (Number(row.quantity) <= 0) {
      await ctx.db.delete('order_items', [eq('id', lineId), eq('order_id', orderId)]);
      s.touchedOrders.add(orderId);
      return { server_id: lineId, version: null };
    }
    const menuItemId = centralId(ctx, 'org', 'menu_item', String(row.item_id));
    const [prior] = await ctx.db.select<{ order_id: string }>('order_items', { columns: ['order_id'], filters: [eq('id', lineId)] });
    if (prior && prior.order_id !== orderId) throw new ApiError(403, 'forbidden', 'That order line belongs to another order.');
    await ctx.db.upsert(
      'order_items',
      [
        {
          id: lineId,
          order_id: orderId,
          menu_item_id: (await s.menuItemExists(menuItemId)) ? menuItemId : null,
          name: String(row.name),
          qty: Number(row.quantity),
          unit_price: toRupees(Number(row.unit_minor)),
          status: row.kitchen_done ? 'ready' : 'pending',
          station: String(row.station || 'main'),
        },
      ],
      ['id'],
    );
    await saveExtra(ctx, LINE, lineId, lineKey, {
      client_order_id: row.client_order_id,
      item_id: row.item_id,
      station: row.station,
      is_veg: row.is_veg,
      kitchen_done: row.kitchen_done,
    });
    s.touchedOrders.add(orderId);
    return { server_id: lineId, version: null };
  }

  async remove(ctx: RequestContext, s: SyncSession, key: DeviceRow): Promise<WriteOutcome | null> {
    const { lineId, orderId } = this.ids(ctx, coerceDeviceRow(this.t, key, true));
    await s.ownOrder(orderId);
    const rows = await ctx.db.delete('order_items', [eq('id', lineId), eq('order_id', orderId)]);
    s.touchedOrders.add(orderId);
    return rows.length ? { server_id: lineId, version: null } : null;
  }

  async pull(ctx: RequestContext, cursor: string | null): Promise<PullPage> {
    const w = await orderWindow(ctx, cursor);
    const lines = await childrenOf(ctx, 'order_items', w.orders.map((o) => o.id as string));
    const extras = await loadExtras(ctx, LINE, lines.map((l) => l.id as string));
    const page: PullPage = { rows: [], deleted: [], snapshot: false, cursor: w.cursor, versions: {}, more: w.more };
    for (const l of lines) {
      const d = extras.get(l.id as string)?.data ?? {};
      page.rows.push({
        client_order_id: orderKey(w, l.order_id as string),
        item_id: (d.item_id as string) ?? (l.menu_item_id as string) ?? (l.id as string),
        name: l.name,
        unit_minor: toMinor(l.unit_price),
        quantity: Number(l.qty),
        station: (d.station as string) ?? (l.station as string) ?? 'Main Kitchen',
        is_veg: (d.is_veg as boolean) ?? true,
        kitchen_done: (d.kitchen_done as boolean) ?? ['ready', 'delivered'].includes(l.status as string),
      });
    }
    return page;
  }
}

// ── kitchen tickets ───────────────────────────────────────────────────────

/// kitchen_tickets ↔ public.kot_tickets. KOT numbers come from
/// next_org_seq(org, 'kot').
export class KitchenTicketsAdapter implements SyncAdapter {
  readonly resource = 'kitchen-tickets';
  readonly module = 'operations' as const;
  private readonly t = contractTable(this.resource);

  async upsert(ctx: RequestContext, s: SyncSession, input: DeviceRow): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const key = String(row.ticket_id);
    const id = centralId(ctx, 'location', KOT, key);
    const orderId = centralId(ctx, 'location', ORDER, String(row.client_order_id));
    const org = eq('organization_id', ctx.m.organization_id);
    await s.ownOrder(orderId);
    const [existing] = await ctx.db.select<Row>('kot_tickets', { columns: ['id'], filters: [org, eq('id', id)] });
    const fields = { status: kotStatus(row.status), priority: row.urgent ? 'urgent' : 'normal' };
    let saved: Row | undefined;
    if (existing) {
      [saved] = await ctx.db.update('kot_tickets', fields, [org, eq('id', id)]);
    } else {
      const kotNo = await ctx.db.rpc<number>('next_org_seq', { org: ctx.m.organization_id, counter_kind: 'kot' });
      [saved] = await ctx.db.insert('kot_tickets', [
        { ...fields, id, organization_id: ctx.m.organization_id, order_id: orderId, kot_no: kotNo, station: 'main', created_at: row.created_at },
      ]);
    }
    await saveExtra(ctx, KOT, id, key, { status: row.status, notes: row.notes, completed_at: row.completed_at });
    s.touchedOrders.add(orderId);
    return { server_id: id, version: (saved?.updated_at as string) ?? null };
  }

  async remove(ctx: RequestContext, s: SyncSession, key: DeviceRow): Promise<WriteOutcome | null> {
    const id = centralId(ctx, 'location', KOT, String(key.ticket_id));
    const rows = await ctx.db.delete('kot_tickets', [eq('organization_id', ctx.m.organization_id), eq('id', id)]);
    for (const r of rows) s.touchedOrders.add(r.order_id as string);
    return rows.length ? { server_id: id, version: null } : null;
  }

  async pull(ctx: RequestContext, cursor: string | null): Promise<PullPage> {
    const w = await orderWindow(ctx, cursor);
    const kots = await childrenOf(ctx, 'kot_tickets', w.orders.map((o) => o.id as string));
    const extras = await loadExtras(ctx, KOT, kots.map((k) => k.id as string));
    const page: PullPage = { rows: [], deleted: [], snapshot: false, cursor: w.cursor, versions: {}, more: w.more };
    for (const k of kots) {
      const x = extras.get(k.id as string);
      const d = x?.data ?? {};
      const key = x?.client_key ?? (k.id as string);
      page.rows.push({
        ticket_id: key,
        client_order_id: orderKey(w, k.order_id as string),
        status: (d.status as string) ?? deviceKotStatus(k.status),
        created_at: iso(k.created_at),
        notes: (d.notes as string) ?? '',
        urgent: k.priority === 'urgent',
        completed_at: (d.completed_at as string) ?? (k.status === 'delivered' ? iso(k.updated_at) : null),
        // KOT number from next_org_seq (server-owned).
        kot_no: k.kot_no === null || k.kot_no === undefined ? null : Number(k.kot_no),
      });
      page.versions[key] = k.updated_at as string;
    }
    return page;
  }
}

// ── payments ──────────────────────────────────────────────────────────────

/// payments ↔ public.payments. Payment evidence is immutable (PRD §9:
/// corrections are reversals, never edits), so re-sending the same payment
/// is idempotent and a changed one is a conflict for review.
export class PaymentsAdapter implements SyncAdapter {
  readonly resource = 'payments';
  readonly module = 'operations' as const;
  private readonly t = contractTable(this.resource);

  async upsert(ctx: RequestContext, s: SyncSession, input: DeviceRow): Promise<WriteOutcome> {
    const row = coerceDeviceRow(this.t, input);
    const key = String(row.payment_id);
    const id = centralId(ctx, 'location', PAYMENT, key);
    const orderId = centralId(ctx, 'location', ORDER, String(row.client_order_id));
    const amount = toRupees(Number(row.amount_minor));
    const method = tenderMethod(row.method);
    if (!canTakePayments(ctx.m.role)) throw new ApiError(403, 'forbidden', `Your role (${ctx.m.role_name}) cannot take payments.`);
    await s.ownOrder(orderId);
    const [existing] = await ctx.db.select<Row>('payments', { filters: [eq('organization_id', ctx.m.organization_id), eq('id', id)] });
    if (existing) {
      if (Number(existing.amount) !== amount || existing.method !== method) {
        throw new SyncConflict(`Payment ${key} is already recorded with a different amount or method; payments cannot be edited.`, existing);
      }
      return { server_id: id, version: iso(existing.created_at) };
    }
    if (amount <= 0) throw unprocessable('A payment must be for more than ₹0.');
    const [saved] = await ctx.db.insert('payments', [
      {
        id,
        organization_id: ctx.m.organization_id,
        order_id: orderId,
        method,
        amount,
        reference: key,
        created_at: row.recorded_at,
      },
    ]);
    await saveExtra(ctx, PAYMENT, id, key, { method: row.method, received_minor: row.received_minor, recorded_by: ctx.user.id });
    s.touchedOrders.add(orderId);
    return { server_id: id, version: iso(saved?.created_at) };
  }

  async remove(): Promise<WriteOutcome | null> {
    throw unprocessable('Payments are never deleted; record a refund or reversal instead.');
  }

  async pull(ctx: RequestContext, cursor: string | null): Promise<PullPage> {
    const w = await orderWindow(ctx, cursor);
    const payments = await childrenOf(ctx, 'payments', w.orders.map((o) => o.id as string));
    const extras = await loadExtras(ctx, PAYMENT, payments.map((p) => p.id as string));
    const page: PullPage = { rows: [], deleted: [], snapshot: false, cursor: w.cursor, versions: {}, more: w.more };
    for (const p of payments) {
      const x = extras.get(p.id as string);
      const amountMinor = toMinor(p.amount);
      page.rows.push({
        payment_id: x?.client_key ?? (p.id as string),
        client_order_id: orderKey(w, p.order_id as string),
        method: (x?.data.method as string) ?? (p.method as string),
        amount_minor: amountMinor,
        received_minor: (x?.data.received_minor as number) ?? amountMinor,
        recorded_at: iso(p.created_at),
      });
    }
    return page;
  }
}
